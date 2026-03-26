-- ═════════════════════════════════════════════════════════════════════════════
-- RESERVATION AUTO-EXPIRY SYSTEM - COMPLETE IMPLEMENTATION
-- Date: March 26, 2026 (Updated)
-- Version: 2.0
--
-- STATUS LIFECYCLE:
--   Reserved/Upcoming → Active (when slot starts) → Seated (check-in) → Completed (checkout)
--   Active → EXPIRED (no check-in + grace period passed + auto-freed from DB) ✅
--
-- FEATURES:
--   ✅ Atomic expiry: Status + Table + Seat updates in single transaction
--   ✅ 'expired' status for auto-expired (not marked as 'completed' - no service occurred)
--   ✅ Table & seats immediately released on expiry
--   ✅ Grace period: 15 minutes after reserved_for time
--   ✅ Comprehensive audit trail with expiry metadata
--   ✅ Fallback mechanisms for robustness
--
-- FUNCTIONS:
--   ✅ fn_expire_single_reservation() - Atomically expire one reservation
--   ✅ fn_expire_stale_reservations() - Batch expire all stale for business
--   ✅ fn_get_expiry_candidates() - Get candidates within next hour
--
-- TABLES EXTENDED:
--   ✅ table_reservations: auto_expired_at, expiry_reason
--   ✅ restaurant_tables: freed_at, freed_by_system
-- ═════════════════════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 0: UPDATE STATUS CHECK CONSTRAINT - ADD 'expired'
-- ═════════════════════════════════════════════════════════════════════════════
-- Before: CHECK (status IN ('active', 'seated', 'no_show', 'completed', 'cancelled'))
-- After:  CHECK (status IN ('active', 'seated', 'expired', 'no_show', 'completed', 'cancelled'))
--
-- We keep 'no_show' for manual staff decisions (guest called to cancel, etc.)
-- We use 'expired' for automatic grace period expiry (no service provided)
-- ═════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.table_reservations
DROP CONSTRAINT IF EXISTS table_reservations_status_check;

ALTER TABLE public.table_reservations
ADD CONSTRAINT table_reservations_status_check
CHECK (status IN ('active', 'seated', 'expired', 'no_show', 'completed', 'cancelled'));

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 1: SCHEMA EXTENSIONS
-- ═════════════════════════════════════════════════════════════════════════════

-- Extended: table_reservations
ALTER TABLE public.table_reservations
ADD COLUMN IF NOT EXISTS auto_expired_at TIMESTAMPTZ;

ALTER TABLE public.table_reservations
ADD COLUMN IF NOT EXISTS expiry_reason TEXT;

-- Extended: restaurant_tables
ALTER TABLE public.restaurant_tables
ADD COLUMN IF NOT EXISTS freed_at TIMESTAMPTZ;

ALTER TABLE public.restaurant_tables
ADD COLUMN IF NOT EXISTS freed_by_system VARCHAR(50) DEFAULT NULL;

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 2: ATOMIC EXPIRY FUNCTION - Expire Single Reservation
-- ═════════════════════════════════════════════════════════════════════════════
-- Purpose:
--   Atomically transitions reservation to 'expired' status
--   Immediately frees the associated table and all seats
--   Records comprehensive expiry metadata for audit trail
--
-- Key Feature: Single transaction ensures atomicity - all succeed or all fail
--   ✅ Reservation status → 'expired'
--   ✅ Table status → 'available'
--   ✅ All seats → 'available'
--   ✅ Metadata: auto_expired_at, expiry_reason, freed_at
--
-- Parameters:
--   p_reservation_id: UUID of reservation to expire
--   p_reason: Reason for expiry (for audit trail)
--
-- Returns: { success, reservation_id, table_id, seats_freed, expired_at, reason }
--
-- Example:
--   SELECT fn_expire_single_reservation('res-123', 'auto_expired_grace_period');
-- ═════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_expire_single_reservation(TEXT, TEXT) CASCADE;

CREATE FUNCTION public.fn_expire_single_reservation(
  p_reservation_id TEXT,
  p_reason TEXT DEFAULT 'auto_expired'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_result JSONB;
  v_table_id TEXT;
  v_business_id TEXT;
  v_seat_count INT := 0;
  v_expiry_time TIMESTAMPTZ := NOW();
BEGIN
  -- STEP 1: Fetch reservation details (fail if not found)
  SELECT table_id, business_id INTO v_table_id, v_business_id
  FROM public.table_reservations
  WHERE id = p_reservation_id;

  IF v_table_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Reservation not found',
      'reservation_id', p_reservation_id
    );
  END IF;

  -- STEP 2: Mark reservation as EXPIRED (only if currently active)
  --         This prevents accidental re-expiry of already-completed/cancelled reservations
  UPDATE public.table_reservations
  SET status = 'expired',
      auto_expired_at = v_expiry_time,
      expiry_reason = p_reason,
      updated_at = v_expiry_time,
      updated_by_name = 'System (Auto-Expiry)',
      updated_by_uid = 'system'
  WHERE id = p_reservation_id
    AND status = 'active'
    AND check_in IS NULL;

  -- STEP 3: Free the table (only if currently reserved)
  UPDATE public.restaurant_tables
  SET status = 'available',
      freed_at = v_expiry_time,
      freed_by_system = 'reservation_expiry',
      updated_at = v_expiry_time,
      updated_by_name = 'System (Auto-Expiry)',
      updated_by_uid = 'system'
  WHERE id = v_table_id
    AND (status = 'reserved' OR status = 'occupied');

  -- STEP 4: Free all seats associated with this table
  UPDATE public.table_seats
  SET status = 'available',
      session_id = NULL,
      customer_name = NULL,
      occupied_since = NULL,
      updated_at = v_expiry_time
  WHERE table_id = v_table_id
    AND status != 'available';

  GET DIAGNOSTICS v_seat_count = ROW_COUNT;

  -- STEP 5: Build result JSON
  v_result := jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'table_id', v_table_id,
    'business_id', v_business_id,
    'seats_freed', v_seat_count,
    'status', 'expired',
    'expired_at', v_expiry_time::TEXT,
    'reason', p_reason
  );

  -- Log for debugging
  RAISE NOTICE '[fn_expire_single_reservation] ✅ Expired res=% table=% freed_seats=% reason=%',
    p_reservation_id, v_table_id, v_seat_count, p_reason;

  RETURN v_result;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '[fn_expire_single_reservation] ❌ ERROR: % %', SQLSTATE, SQLERRM;
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'reservation_id', p_reservation_id
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 3: BATCH EXPIRY FUNCTION - Expire Stale Reservations
-- ═════════════════════════════════════════════════════════════════════════════
-- Purpose:
--   Batch-processes all stale ('active') reservations for a business
--   Finds reservations: status='active' AND check_in IS NULL AND past grace period
--   Calls fn_expire_single_reservation() for each, ensuring atomicity
--   Returns audit summary: count, IDs, and business context
--
-- Grace Period Logic:
--   Reserved_for = 2:00 PM
--   Grace Period End = 2:15 PM (15 minutes after reserved_for)
--   Expiry Trigger = When current time > grace period end
--   Result: Status changed to 'expired' + table + seats freed
--
-- Parameters:
--   p_business_id: Business ID to expire reservations for
--   p_grace_period_minutes: Minutes to wait after reserved_for (default: 15)
--
-- Returns: { success, expired_count, expired_ids[], business_id, grace_period_minutes, checked_at }
--
-- Example:
--   SELECT fn_expire_stale_reservations('biz-456', 15);
-- ═════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations_batch(TEXT, INT) CASCADE;

CREATE FUNCTION public.fn_expire_stale_reservations(
  p_business_id TEXT,
  p_grace_period_minutes INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_grace_end TIMESTAMPTZ;
  v_expired_ids TEXT[] := ARRAY[]::TEXT[];
  v_record RECORD;
  v_count INT := 0;
  v_result JSONB;
  v_expire_result JSONB;
BEGIN
  -- STEP 1: Find all stale reservations
  -- Criteria: active status, no check-in, grace period completely passed
  FOR v_record IN
    SELECT id, customer_name, table_id, reserved_for
    FROM public.table_reservations
    WHERE business_id = p_business_id
      AND status = 'active'
      AND check_in IS NULL
      AND reserved_for + (p_grace_period_minutes || ' minutes')::INTERVAL < v_now
    ORDER BY reserved_for ASC
  LOOP
    -- STEP 2: Expire each reservation atomically
    v_expire_result := fn_expire_single_reservation(
      v_record.id,
      'grace_period_expired'
    );
    
    -- STEP 3: Track results
    IF (v_expire_result->>'success')::BOOLEAN THEN
      v_expired_ids := array_append(v_expired_ids, v_record.id);
      v_count := v_count + 1;
      RAISE NOTICE '[fn_expire_stale_reservations] ✅ Expired: % (%)',
        v_record.customer_name, v_record.id;
    ELSE
      RAISE WARNING '[fn_expire_stale_reservations] ⚠️ Failed to expire %: %',
        v_record.id, v_expire_result->>'error';
    END IF;
  END LOOP;

  -- STEP 4: Build result with summary
  v_result := jsonb_build_object(
    'success', true,
    'expired_count', v_count,
    'expired_ids', v_expired_ids,
    'business_id', p_business_id,
    'grace_period_minutes', p_grace_period_minutes,
    'checked_at', v_now::TEXT
  );

  IF v_count > 0 THEN
    RAISE NOTICE '[fn_expire_stale_reservations] ✅ Batch complete: % reservations expired for business %',
      v_count, p_business_id;
  END IF;

  RETURN v_result;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '[fn_expire_stale_reservations] ❌ ERROR: % %', SQLSTATE, SQLERRM;
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'expired_count', v_count,
    'expired_ids', v_expired_ids,
    'business_id', p_business_id
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- PART 4: FUNCTION - Get Expiry Candidates
-- ═════════════════════════════════════════════════════════════════════════════
-- Purpose:
--   Returns list of reservations that are close to expiry or already expired
--   Useful for UI notifications and monitoring
--
-- Parameters:
--   p_business_id: Business to check
--
-- Returns Table with columns:
--   id, table_id, customer_name, reserved_for, check_in,
--   grace_period_end, status, expires_in_minutes, is_expired, room_minutes
-- ═════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_get_expiry_candidates(TEXT) CASCADE;

CREATE FUNCTION public.fn_get_expiry_candidates(p_business_id TEXT)
RETURNS TABLE (
  id TEXT,
  table_id TEXT,
  customer_name TEXT,
  reserved_for TIMESTAMPTZ,
  check_in TIMESTAMPTZ,
  grace_period_end TIMESTAMPTZ,
  status TEXT,
  expires_in_minutes INT,
  is_expired BOOLEAN,
  room_minutes INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    tr.id::TEXT,
    tr.table_id::TEXT,
    tr.customer_name,
    tr.reserved_for,
    tr.check_in,
    tr.reserved_for + INTERVAL '15 minutes' as grace_end,
    tr.status,
    EXTRACT(EPOCH FROM (tr.reserved_for + INTERVAL '15 minutes' - NOW()))::INT / 60 as expiry_mins,
    NOW() > (tr.reserved_for + INTERVAL '15 minutes') as expired,
    EXTRACT(EPOCH FROM (NOW() - (tr.reserved_for + INTERVAL '15 minutes')))::INT / 60 as room_mins
  FROM public.table_reservations tr
  WHERE tr.business_id = p_business_id
    AND tr.status = 'active'
    AND tr.check_in IS NULL
    AND tr.reserved_for + INTERVAL '15 minutes' < NOW() + INTERVAL '1 hour'
  ORDER BY grace_end ASC;
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 5: AUDIT VIEW - Reservation Expiry Lifecycle
-- ═════════════════════════════════════════════════════════════════════════════
-- Purpose:
--   Comprehensive audit trail showing full lifecycle of every reservation
--   Clearly distinguishes between different end states:
--     EXPIRED: Auto-expired (grace period, no check-in) → status='expired'
--     NO_SHOW: Manually marked no-show by staff → status='no_show'
--     CHECKED_IN: Guest arrived and was seated → check_in IS NOT NULL
--     COMPLETED: Full service + checkout → status='completed'
--     CANCELLED: Staff manually cancelled → status='cancelled'
--
-- Usage:
--   SELECT * FROM vw_reservation_expiry_audit WHERE lifecycle_status='EXPIRED' ORDER BY auto_expired_at DESC;
-- ═════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_reservation_expiry_audit CASCADE;

CREATE VIEW public.vw_reservation_expiry_audit AS
SELECT
  tr.id,
  tr.table_id,
  tr.business_id,
  tr.customer_name,
  rt.table_number,
  tr.guest_count,
  tr.reserved_for,
  tr.check_in,
  tr.check_out,
  tr.status as reservation_status,
  tr.auto_expired_at,
  tr.expiry_reason,
  rt.freed_at,
  rt.freed_by_system,
  -- Time from reserved slot to expiry
  CASE
    WHEN tr.status = 'expired' AND tr.auto_expired_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (tr.auto_expired_at - tr.reserved_for))::INT / 60
    ELSE NULL
  END as minutes_past_reservation,
  -- Comprehensive lifecycle status
  CASE
    WHEN tr.status = 'expired' THEN 'EXPIRED_AUTO'
    WHEN tr.status = 'no_show' AND tr.auto_expired_at IS NOT NULL THEN 'EXPIRED_AUTO'
    WHEN tr.status = 'no_show' THEN 'NO_SHOW_MANUAL'
    WHEN tr.status = 'cancelled' THEN 'CANCELLED'
    WHEN tr.status = 'completed' THEN 'COMPLETED'
    WHEN tr.check_in IS NOT NULL AND tr.status = 'seated' THEN 'CHECKED_IN'
    WHEN tr.status = 'active' THEN 'PENDING_ACTIVE'
    ELSE 'UNKNOWN'
  END as lifecycle_status,
  -- Duration of stay (if checked in and checked out)
  CASE
    WHEN tr.check_in IS NOT NULL AND tr.check_out IS NOT NULL
      THEN EXTRACT(EPOCH FROM (tr.check_out - tr.check_in))::INT / 60
    ELSE NULL
  END as stay_duration_minutes,
  tr.created_at,
  tr.updated_at,
  tr.notes
FROM public.table_reservations tr
LEFT JOIN public.restaurant_tables rt ON rt.id = tr.table_id
WHERE tr.business_id IS NOT NULL
ORDER BY tr.created_at DESC;

GRANT SELECT ON public.vw_reservation_expiry_audit TO anon, authenticated;

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 6: SCHEMA RELOAD TRIGGER
-- ═════════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';

-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 7: VERIFICATION & TESTING QUERIES
-- ═════════════════════════════════════════════════════════════════════════════
-- Run these after deployment to verify the system is working correctly
-- ═════════════════════════════════════════════════════════════════════════════

-- TEST 1: Verify all functions exist and have correct signatures
-- Expected: 2 rows (fn_expire_single_reservation, fn_expire_stale_reservations)
-- SELECT proname, pronargs FROM pg_proc
-- WHERE proname IN ('fn_expire_single_reservation', 'fn_expire_stale_reservations')
-- ORDER BY proname;

-- TEST 2: Check CHECK constraint includes 'expired'
-- Expected: Should show 'active', 'seated', 'expired', 'no_show', 'completed', 'cancelled'
-- SELECT (regexp_matches(pg_get_constraintdef(oid), 
--   $$'(active|seated|expired|no_show|completed|cancelled)'$$, 'g'))[1] as status_value
-- FROM pg_constraint
-- WHERE conname = 'table_reservations_status_check' AND contype = 'c';

-- TEST 3: Verify audit trail columns exist
-- Expected: Should show all columns including lifecycle_status, minutes_past_reservation
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'vw_reservation_expiry_audit'
-- ORDER BY column_name;

-- TEST 4: Get recently expired reservations
-- Expected: Show all reservations with EXPIRED_AUTO lifecycle status
-- SELECT id, customer_name, reservation_status, lifecycle_status, auto_expired_at, minutes_past_reservation
-- FROM vw_reservation_expiry_audit
-- WHERE lifecycle_status LIKE 'EXPIRED%'
-- ORDER BY auto_expired_at DESC
-- LIMIT 10;

-- TEST 5: Check freed tables
-- Expected: Show tables that were freed by the expiry system
-- SELECT table_number, freed_at, freed_by_system, (NOW() - freed_at) as freed_ago
-- FROM restaurant_tables
-- WHERE freed_by_system = 'reservation_expiry'
-- ORDER BY freed_at DESC
-- LIMIT 10;

-- TEST 6: Check reservation status distribution
-- Expected: Breakdown of active vs expired vs completed vs no_show (replace YOUR_BUSINESS_ID)
-- SELECT status, COUNT(*) as count, 
--        COUNT(*) FILTER (WHERE auto_expired_at IS NOT NULL) as auto_expired_count
-- FROM table_reservations
-- WHERE business_id = 'YOUR_BUSINESS_ID'
-- GROUP BY status
-- ORDER BY count DESC;

-- TEST 7: Manual test - expire a specific reservation
-- Command format: SELECT fn_expire_single_reservation('RESERVATION_ID', 'manual_test');
-- Expected result: { "success": true, "status": "expired", ... }

-- ═════════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT GUIDE
-- ═════════════════════════════════════════════════════════════════════════════
--
-- STEP 1: Backup
--   - Take backup of Supabase database before deploying
--
-- STEP 2: Deploy SQL
--   - Run this entire file in Supabase SQL Editor
--   - Monitor for any errors
--
-- STEP 3: Verify Database
--   - Run TEST 1-6 queries above to verify deployment
--   - Check that no errors appear
--
-- STEP 4: Deploy Flutter
--   - Update lib/providers/tables_provider.dart to use new function name
--   - Check that 'expired' status is handled in UI
--   - Test on simulator with a reservation that will expire
--
-- STEP 5: Production Verification
--   - Monitor logs for '[fn_expire_stale_reservations] ✅' messages
--   - Verify expired reservations show correct status in app
--   - Verify tables are released after expiry
--
-- ═════════════════════════════════════════════════════════════════════════════
-- TROUBLESHOOTING
-- ═════════════════════════════════════════════════════════════════════════════
--
-- Issue: "NEW: relation "table_reservations" does not exist"
--   Cause: SQL executed on wrong database or wrong schema
--   Fix: Verify you're executing on correct Supabase project
--
-- Issue: "Check constraint 'table_reservations_status_check' violation"
--   Cause: Old code still trying to set status='expired' before constraint update
--   Fix: Run this file completely from top to bottom
--
-- Issue: Reservations not auto-expiring
--   Cause: Flutter _expireStaleReservations() not being called
--   Fix: Verify background service is running and calling provider method
--
-- Issue: Tables not being freed
--   Cause: fn_expire_single_reservation not updating restaurant_tables
--   Fix: Check freed_at column exists, verify function has write permissions
--
-- ═════════════════════════════════════════════════════════════════════════════
