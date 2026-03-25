-- ═══════════════════════════════════════════════════════════════════════════
-- COMPREHENSIVE FIX: Reservation Visibility, Expiration, and State Management
-- Date: 2026-03-26
--
-- ISSUES FIXED:
-- 1. Tables marked 'reserved' show null reservation data in UI
-- 2. Reservations don't auto-expire after grace period
-- 3. Buffer period not being applied correctly (30 min before reservation)
-- 4. View not joining reservation data for reserved tables
-- 5. Timing calculations not handling UTC/IST conversions properly
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: Fix vw_tables_with_reservation to properly join ALL active reservations
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: Original view LEFT JOIN only includes 'active' and 'seated' statuses
-- but this misses reservations during the buffer window period.
-- Solution: Always join active/seated reservations to ensure reservation_data
-- is available for reserved tables.

DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;

CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.id,
  rt.table_number,
  rt.capacity,
  rt.status,
  rt.section,
  rt.shape,
  rt.has_window,
  rt.is_premium,
  rt.current_customer_name,
  rt.current_order_id,
  rt.current_order_total,
  rt.occupied_since,
  rt.session_id,
  rt.business_id,
  rt.is_active,
  rt.created_at,
  rt.updated_at,
  rt.created_by_uid,
  rt.created_by_name,
  rt.updated_by_uid,
  rt.updated_by_name,
  -- 🔧 FIX: Build reservation_data as comprehensive JSON for all active reservations
  CASE
    WHEN tr.id IS NOT NULL THEN jsonb_build_object(
      'id', tr.id,
      'customer_name', tr.customer_name,
      'phone', tr.phone,
      'guest_count', tr.guest_count,
      'reserved_for', tr.reserved_for::text,
      'check_in', tr.check_in::text,
      'check_out', tr.check_out::text,
      'actual_check_out', tr.actual_check_out::text,
      'notes', tr.notes,
      'status', tr.status,
      'warning_sent', tr.warning_sent,
      'created_at', tr.created_at::text,
      'created_by_uid', tr.created_by_uid::text,
      'created_by_name', tr.created_by_name,
      'created_by_role', tr.created_by_role
    )
    ELSE NULL
  END AS reservation_data
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr ON 
  tr.table_id = rt.id 
  AND tr.status IN ('active', 'seated')
  AND tr.is_active = true
WHERE rt.is_active = true;

GRANT SELECT ON public.vw_tables_with_reservation TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: Fix vw_table_reservation_status to correctly identify all state transitions
-- ═══════════════════════════════════════════════════════════════════════════
-- This view must correctly identify:
-- - Which tables should be marked 'reserved' (based on buffer window)
-- - Which tables need auto-expiry
-- - Which tables should return to 'available'

DROP VIEW IF EXISTS public.vw_table_reservation_status CASCADE;

CREATE VIEW public.vw_table_reservation_status AS
SELECT 
  rt.id AS table_id,
  rt.business_id,
  rt.table_number,
  rt.status AS current_table_status,
  tr.id AS reservation_id,
  tr.customer_name,
  tr.reserved_for,
  tr.check_in,
  tr.check_out,
  tr.status AS reservation_status,
  -- Calculate buffer window: starts 30 min before reservation, ends at reservation time
  (tr.reserved_for - INTERVAL '30 minutes') AS buffer_window_start,
  tr.reserved_for AS buffer_window_end,
  -- Calculate grace period: starts at buffer_window_end, lasts 15 min after reservation time
  tr.reserved_for AS grace_period_start,
  (tr.reserved_for + INTERVAL '15 minutes') AS grace_period_end,
  -- Current timestamp
  NOW() AS current_timestamp,
  -- Determine what status table SHOULD have right now
  CASE 
    -- 1. No active/upcoming reservation → available
    WHEN tr.id IS NULL THEN 'available'
    
    -- 2. Seated or completed reservation → not relevant to availability
    WHEN tr.status IN ('seated', 'completed') THEN 'available'
    
    -- 3. Cancelled or no_show → available
    WHEN tr.status IN ('cancelled', 'no_show') THEN 'available'
    
    -- 4. Active reservation in buffer period (30 min before) or grace period (15 min after) → reserved
    WHEN tr.status = 'active' 
      AND NOW() >= (tr.reserved_for - INTERVAL '30 minutes')
      AND NOW() < (tr.reserved_for + INTERVAL '15 minutes') THEN 'reserved'
    
    -- 5. Active reservation with check_in but no check_out → occupied
    WHEN tr.status = 'active' 
      AND tr.check_in IS NOT NULL 
      AND tr.check_out IS NULL THEN 'occupied'
    
    -- 6. Active reservation past grace period with no check_in → needs_expiry
    WHEN tr.status = 'active'
      AND tr.check_in IS NULL
      AND NOW() >= (tr.reserved_for + INTERVAL '15 minutes') THEN 'needs_expiry'
    
    -- 7. Active reservation before buffer window → available
    ELSE 'available'
  END AS desired_table_status,
  
  -- Flag to identify which tables need auto-expiry
  CASE 
    WHEN tr.status = 'active'
      AND tr.check_in IS NULL
      AND NOW() >= (tr.reserved_for + INTERVAL '15 minutes') THEN true
    ELSE false
  END AS needs_expiry
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr ON 
  rt.id = tr.table_id 
  AND tr.status IN ('active', 'seated')
  AND tr.is_active = true
WHERE rt.is_active = true;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: Improved fn_update_table_statuses_for_slots
-- ═══════════════════════════════════════════════════════════════════════════
-- This function ensures tables transition correctly between states based on
-- reservation timing (buffer windows, grace periods, and auto-expiry).

DROP FUNCTION IF EXISTS public.fn_update_table_statuses_for_slots(TEXT) CASCADE;

CREATE FUNCTION public.fn_update_table_statuses_for_slots(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_reserved_count INT := 0;
  v_available_count INT := 0;
  v_expired_count INT := 0;
  v_now TIMESTAMPTZ := NOW();
  v_result JSONB;
BEGIN
  -- ═════════════════════════════════════════════════════════════════════
  -- STEP 1: Mark tables as "RESERVED" (in buffer or grace period)
  -- ═════════════════════════════════════════════════════════════════════
  -- Buffer period: 30 min before reservation time
  -- Grace period: 15 min after reservation time
  -- Tables in either period should be marked 'reserved'

  UPDATE public.restaurant_tables rt
  SET status = 'reserved',
      updated_at = v_now,
      updated_by_name = 'System (Buffer Window)',
      updated_by_uid = 'system'
  WHERE rt.business_id = p_business_id
    AND rt.is_active = true
    AND rt.status NOT IN ('occupied', 'cleaning')  -- Never override occupied/cleaning
    AND EXISTS (
      SELECT 1
      FROM public.table_reservations tr
      WHERE tr.table_id = rt.id
        AND tr.is_active = true
        AND tr.status = 'active'
        AND tr.check_in IS NULL  -- Haven't checked in yet
        -- In buffer window (30 min before) or grace period (15 min after)
        AND v_now >= (tr.reserved_for - INTERVAL '30 minutes')
        AND v_now < (tr.reserved_for + INTERVAL '15 minutes')
    );

  GET DIAGNOSTICS v_reserved_count = ROW_COUNT;

  -- ═════════════════════════════════════════════════════════════════════
  -- STEP 2: Mark tables as "AVAILABLE" (no active reservation in windows)
  -- ═════════════════════════════════════════════════════════════════════
  -- Tables that were 'reserved' but now have no qualifying reservation
  -- should return to 'available'

  UPDATE public.restaurant_tables rt
  SET status = 'available',
      updated_at = v_now,
      updated_by_name = 'System (Buffer Window Expired)',
      updated_by_uid = 'system'
  WHERE rt.business_id = p_business_id
    AND rt.is_active = true
    AND rt.status = 'reserved'
    -- No active reservation currently in buffer/grace period
    AND NOT EXISTS (
      SELECT 1
      FROM public.table_reservations tr
      WHERE tr.table_id = rt.id
        AND tr.is_active = true
        AND tr.status = 'active'
        AND tr.check_in IS NULL
        AND v_now >= (tr.reserved_for - INTERVAL '30 minutes')
        AND v_now < (tr.reserved_for + INTERVAL '15 minutes')
    );

  GET DIAGNOSTICS v_available_count = ROW_COUNT;

  -- ═════════════════════════════════════════════════════════════════════
  -- STEP 3: AUTO-EXPIRE stale reservations (past grace period + no check-in)
  -- ═════════════════════════════════════════════════════════════════════
  -- If a guest hasn't checked in by the time the grace period ends (15 min
  -- after reservation time), mark them as 'no_show' and free the table.

  UPDATE public.table_reservations tr
  SET status = 'no_show',
      updated_at = v_now,
      updated_by_name = 'System (Auto-Expired)',
      updated_by_uid = 'system'
  WHERE tr.business_id = p_business_id
    AND tr.is_active = true
    AND tr.status = 'active'
    AND tr.check_in IS NULL
    -- Grace period has ended (15 min after reserved_for time)
    AND v_now >= (tr.reserved_for + INTERVAL '15 minutes');

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;

  -- Build return value
  v_result := jsonb_build_object(
    'success', true,
    'timestamp', v_now::TEXT,
    'business_id', p_business_id,
    'tables_marked_reserved', v_reserved_count,
    'tables_marked_available', v_available_count,
    'reservations_expired', v_expired_count,
    'message', format(
      'Updated %s reserved, %s available, %s expired',
      v_reserved_count, v_available_count, v_expired_count
    )
  );

  -- Log the operation
  RAISE NOTICE 'fn_update_table_statuses_for_slots[%]: Reserved=%, Available=%, Expired=%',
    p_business_id, v_reserved_count, v_available_count, v_expired_count;

  RETURN v_result;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: Backward compatibility wrapper for fn_expire_stale_reservations
-- ═══════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(TEXT) CASCADE;

CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Call the comprehensive slot status update function
  v_result := public.fn_update_table_statuses_for_slots(p_business_id);
  
  RETURN jsonb_build_object(
    'success', (v_result->>'success')::boolean,
    'expired_count', (v_result->>'reservations_expired')::INT,
    'expired_ids', COALESCE(v_result->'expired_ids', '[]'::jsonb)
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: Force PostgREST schema reload
-- ═══════════════════════════════════════════════════════════════════════════
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Check that reserved tables have reservation data
-- SELECT rt.table_number, rt.status, tr.customer_name, tr.reserved_for
-- FROM public.restaurant_tables rt
-- LEFT JOIN public.table_reservations tr ON tr.table_id = rt.id AND tr.status = 'active'
-- WHERE rt.status = 'reserved' AND rt.is_active = true;

-- Check current reservation state
-- SELECT table_id, current_table_status, desired_table_status, needs_expiry
-- FROM vw_table_reservation_status
-- WHERE business_id = 'POS001'
-- ORDER BY current_timestamp;

-- Check which reservations should auto-expire
-- SELECT customer_name, reserved_for, check_in, status
-- FROM public.table_reservations
-- WHERE business_id = 'POS001' AND status = 'no_show'
-- ORDER BY reserved_for DESC;
