-- ═════════════════════════════════════════════════════════════════════════════
-- FIX: Reservation Visibility, Buffer Period, and Automatic Expiration (2026-03-26)
--
-- ISSUE:
--   1. Tables appear as "available" even with upcoming reservations
--   2. No buffer period enforcement (e.g., 30 min before reservation)
--   3. Reservations not automatically expiring after grace period
--   4. Invalid reservations showing as "available" (no_show/expired not visible)
--
-- SOLUTION:
--   ✅ Create fn_update_table_statuses_for_slots - Updates table status based on
--      reservation timing (buffer window: 30 min before, grace period: 15 min after)
--   ✅ Create vw_table_reservation_status - View to identify reservation state of each table
--   ✅ Update table_reservations table with grace period tracking
--   ✅ Ensure proper constraint on valid statuses
-- ═════════════════════════════════════════════════════════════════════════════

-- Step 1: Ensure table_reservations has all required columns
-- ═════════════════════════════════════════════════════════════════════════════
ALTER TABLE public.table_reservations
ADD COLUMN IF NOT EXISTS grace_period_start TIMESTAMPTZ COMMENT 'Time when grace period starts (reservation time + default 2h duration)';

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 2: Add CHECK constraint for valid statuses
-- ═════════════════════════════════════════════════════════════════════════════
ALTER TABLE public.table_reservations
DROP CONSTRAINT IF EXISTS table_reservations_status_check;

ALTER TABLE public.table_reservations
ADD CONSTRAINT table_reservations_status_check
CHECK (status IN ('active', 'seated', 'no_show', 'completed', 'cancelled'));

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 3: Create view to show table reservation status at each moment
-- ═════════════════════════════════════════════════════════════════════════════
-- This view determines if a table should be "reserved" based on:
--   - Buffer period: 30 minutes before reservation time
--   - Grace period: 15 minutes after (to allow late arrivals)
--   - Only active/seated reservations count
-- ═════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_table_reservation_status CASCADE;

CREATE VIEW public.vw_table_reservation_status AS
SELECT 
  rt.id AS table_id,
  rt.business_id,
  tr.id AS reservation_id,
  tr.customer_name,
  tr.reserved_for,
  tr.check_in,
  tr.check_out,
  tr.status AS reservation_status,
  -- Calculate buffer window: starts 30 min before reservation, ends at reservation time
  tr.reserved_for - INTERVAL '30 minutes' AS buffer_window_start,
  tr.reserved_for AS buffer_window_end,
  -- Calculate grace period: starts at buffer_window_end, lasts 15 min
  tr.reserved_for AS grace_period_start,
  tr.reserved_for + INTERVAL '15 minutes' AS grace_period_end,
  -- Determine if table should be "reserved" right now
  CASE 
    -- 1. No active/upcoming reservation → available
    WHEN tr.id IS NULL THEN 'available'
    
    -- 2. Seated or completed reservation → not relevant to availability
    WHEN tr.status IN ('seated', 'completed') THEN 'available'
    
    -- 3. Cancelled or no_show → available
    WHEN tr.status IN ('cancelled', 'no_show') THEN 'available'
    
    -- 4. Active reservation in buffer period or grace period → reserved
    WHEN tr.status = 'active' 
      AND NOW() >= (tr.reserved_for - INTERVAL '30 minutes')
      AND NOW() < (tr.reserved_for + INTERVAL '15 minutes') THEN 'reserved'
    
    -- 5. Active reservation past grace period → expired (auto-expire)
    WHEN tr.status = 'active'
      AND tr.check_in IS NULL
      AND NOW() >= (tr.reserved_for + INTERVAL '15 minutes') THEN 'should_expire'
    
    -- 6. Active reservation before buffer window → available
    ELSE 'available'
  END AS current_table_status,
  
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
  AND tr.status IN ('active', 'seated');

-- Step 4: Create fn_update_table_statuses_for_slots
-- ═════════════════════════════════════════════════════════════════════════════
-- This function:
--   1. Marks tables as 'reserved' when in buffer period or grace period
--   2. Auto-expires stale 'active' reservations as 'no_show'
--   3. Returns counts of updated tables and expired reservations
-- ═════════════════════════════════════════════════════════════════════════════

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
BEGIN
  -- ═════════════════════════════════════════════════════════════════════════
  -- PART 1: MARK TABLES AS "RESERVED" (buffer period: 30 min before → 15 min grace)
  -- ═════════════════════════════════════════════════════════════════════════

  UPDATE public.restaurant_tables rt
  SET status = 'reserved',
      updated_at = v_now,
      updated_by_name = 'System (Slot-Window)'
  WHERE rt.business_id = p_business_id
    AND rt.status NOT IN ('occupied', 'cleaning')  -- Don't override occupied/cleaning
    AND EXISTS (
      SELECT 1
      FROM public.table_reservations tr
      WHERE tr.table_id = rt.id
        AND tr.status = 'active'
        AND tr.check_in IS NULL
        -- Table is in buffer window (30 min before) or grace period (15 min after)
        AND v_now >= (tr.reserved_for - INTERVAL '30 minutes')
        AND v_now < (tr.reserved_for + INTERVAL '15 minutes')
    );

  GET DIAGNOSTICS v_reserved_count = ROW_COUNT;

  -- ═════════════════════════════════════════════════════════════════════════
  -- PART 2: MARK TABLES AS "AVAILABLE" (no active reservation in period windows)
  -- ═════════════════════════════════════════════════════════════════════════

  UPDATE public.restaurant_tables rt
  SET status = 'available',
      updated_at = v_now,
      updated_by_name = 'System (Slot-Window)'
  WHERE rt.business_id = p_business_id
    AND rt.status = 'reserved'
    -- No active reservation in buffer/grace period
    AND NOT EXISTS (
      SELECT 1
      FROM public.table_reservations tr
      WHERE tr.table_id = rt.id
        AND tr.status = 'active'
        AND tr.check_in IS NULL
        AND v_now >= (tr.reserved_for - INTERVAL '30 minutes')
        AND v_now < (tr.reserved_for + INTERVAL '15 minutes')
    );

  GET DIAGNOSTICS v_available_count = ROW_COUNT;

  -- ═════════════════════════════════════════════════════════════════════════
  -- PART 3: AUTO-EXPIRE STALE RESERVATIONS (past grace period + no check-in)
  -- ═════════════════════════════════════════════════════════════════════════

  UPDATE public.table_reservations tr
  SET status = 'no_show',
      updated_at = v_now,
      updated_by_name = 'System (Auto-Expired)'
  WHERE tr.business_id = p_business_id
    AND tr.status = 'active'
    AND tr.check_in IS NULL
    -- Grace period has ended (reservation time + 15 minutes)
    AND v_now >= (tr.reserved_for + INTERVAL '15 minutes');

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'tables_marked_reserved', v_reserved_count,
    'tables_marked_available', v_available_count,
    'reservations_expired', v_expired_count,
    'timestamp', v_now::TEXT
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 5: Update fn_expire_stale_reservations to use new logic
-- ═════════════════════════════════════════════════════════════════════════════
-- Keep this for backward compatibility but now it calls the combined function
-- ═════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(TEXT) CASCADE;

CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
  v_count INT;
BEGIN
  -- Call the comprehensive slot status update function
  v_result := public.fn_update_table_statuses_for_slots(p_business_id);
  
  -- Extract just the expired count for backward compatibility
  v_count := (v_result->>'reservations_expired')::INT;
  
  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_count
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 6: Verify the system works
-- ═════════════════════════════════════════════════════════════════════════════

-- Example queries to test:
--
-- 1. Show current state of all tables and their reservations:
--    SELECT table_id, current_table_status, customer_name, reservation_status,
--           reserved_for, buffer_window_start, grace_period_end
--    FROM vw_table_reservation_status
--    WHERE business_id = 'YOUR_BUSINESS_ID'
--    ORDER BY reserved_for;
--
-- 2. Run the slot update function:
--    SELECT fn_update_table_statuses_for_slots('YOUR_BUSINESS_ID');
--
-- 3. Check which tables are reserved:
--    SELECT table_number FROM public.restaurant_tables
--    WHERE business_id = 'YOUR_BUSINESS_ID' AND status = 'reserved';
--
-- 4. Check expired reservations:
--    SELECT customer_name, reserved_for, status
--    FROM public.table_reservations
--    WHERE business_id = 'YOUR_BUSINESS_ID' AND status = 'no_show'
--    ORDER BY reserved_for DESC;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 7: Force PostgREST schema reload
-- ═════════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';
