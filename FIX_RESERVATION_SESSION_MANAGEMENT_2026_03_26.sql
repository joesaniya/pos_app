-- ═════════════════════════════════════════════════════════════════════════════
-- FIX: Reservation Status & Session Management (2026-03-26)
--
-- ISSUE:
--   1. When a guest is seated, reservation status should change from 'active' to 'seated'
--      and check_in time should be recorded
--   2. When a table is cleared, reservation status should change to 'completed'
--      and check_out time should be recorded
--   3. Each new session must start fresh with zero duration - no previous data carryover
--   4. Table must become immediately 'available' after clearing
--
-- SOLUTION:
--   ✅ Update fn_seat_guest_v2 to update reservation check_in + status
--   ✅ Update fn_checkout_v2 to reset all session data completely  
--   ✅ Create fn_clear_table_complete for proper table lifecycle
--   ✅ Ensure occupied_since is set to NOW() only at seating time (fresh start)
-- ═════════════════════════════════════════════════════════════════════════════

-- Step 1: DROP old functions
DROP FUNCTION IF EXISTS public.fn_seat_guest_v2(TEXT, UUID[], TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.fn_checkout_v2(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.fn_clear_seat(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_clear_table_complete(TEXT) CASCADE;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 2: RECREATE fn_seat_guest_v2 WITH RESERVATION STATUS UPDATE
-- ═════════════════════════════════════════════════════════════════════════════
-- When a guest is seated at a reserved table:
--   1. Set check_in = NOW() on the reservation
--   2. Change reservation status from 'active' to 'seated'
--   3. Update table with occupied status and fresh session_id
--   4. Set occupied_since = NOW() for fresh duration tracking
-- ═════════════════════════════════════════════════════════════════════════════

CREATE FUNCTION public.fn_seat_guest_v2(
  p_customer_name TEXT,
  p_seat_ids UUID[],
  p_staff_name TEXT,
  p_staff_uid TEXT,
  p_table_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE 
  v_session_id UUID := uuid_generate_v4();
  v_reservation_id TEXT;
BEGIN
  -- 1. Update seat records (mark occupied with fresh session)
  UPDATE public.table_seats
  SET status='occupied',
      customer_name=p_customer_name,
      session_id=v_session_id,
      occupied_since=NOW()  -- ✅ FRESH: Zero duration starts here
  WHERE table_id=p_table_id 
    AND id = ANY(p_seat_ids);

  -- 2. Update table (mark occupied with fresh session and current timestamp)
  UPDATE public.restaurant_tables
  SET status='occupied',
      current_customer_name=p_customer_name,
      session_id=v_session_id,
      occupied_since=NOW()  -- ✅ FRESH: Zero duration starts here
  WHERE id=p_table_id;

  -- 3. ✅ CRITICAL FIX: Update any active reservation for this table
  --    Set check_in = NOW() and change status from 'active' to 'seated'
  UPDATE public.table_reservations
  SET check_in=NOW(),
      status='seated',
      updated_at=NOW()
  WHERE table_id=p_table_id
    AND status='active'
  RETURNING id INTO v_reservation_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'reservation_id', v_reservation_id
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 3: RECREATE fn_checkout_v2 WITH COMPLETE SESSION RESET
-- ═════════════════════════════════════════════════════════════════════════════
-- When guests leave (checkout):
--   1. Complete all orders for the table
--   2. Mark all table seats as 'available' (CRITICAL: reset ALL fields)
--   3. Reset table to 'available' with all session data nulled
--   4. Update reservation status to 'completed' and set check_out time
--   5. ZERO carryover: Next customer gets completely fresh session
-- ═════════════════════════════════════════════════════════════════════════════

CREATE FUNCTION public.fn_checkout_v2(p_table_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  -- 1. Mark all active orders as completed
  UPDATE public.orders 
  SET status='completed',
      payment_status='paid',
      updated_at=NOW()
  WHERE table_id=p_table_id 
    AND status IN ('pending', 'preparing', 'ready');

  -- 2. ✅ CRITICAL FIX: COMPLETELY RESET all seat session data
  --    This ensures the seat is truly 'available' and ready for a new guest
  --    occupied_since = NULL means duration timer is not running
  --    session_id = NULL means no active session
  --    customer_name = NULL means seat is unassigned
  UPDATE public.table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,  -- ✅ NO DURATION INHERITANCE
      updated_at=NOW()
  WHERE table_id=p_table_id;

  -- 3. ✅ CRITICAL FIX: COMPLETELY RESET all table session data
  --    This transitions the table from 'occupied' → 'available'
  --    occupied_since = NULL means duration counter is stopped
  --    session_id = NULL means no active session
  --    current_customer_name = NULL means no one is at the table
  --    current_order_id = NULL means no pending orders reference this table
  UPDATE public.restaurant_tables
  SET status='available',
      session_id=NULL,
      current_customer_name=NULL,
      occupied_since=NULL,  -- ✅ RESET DURATION TIMER
      current_order_id=NULL,
      current_order_total=0,
      updated_at=NOW()
  WHERE id=p_table_id;

  -- 4. ✅ UPDATE RESERVATION: Mark as 'completed' and set check_out time
  --    This closes out the reservation with actual checkout time
  UPDATE public.table_reservations
  SET status='completed',
      actual_check_out=NOW(),
      updated_at=NOW()
  WHERE table_id=p_table_id
    AND status IN ('active', 'seated');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 4: CREATE fn_clear_seat (For individual seat clearance)
-- ═════════════════════════════════════════════════════════════════════════════
-- When a single guest leaves from a multi-seat table:
--   1. Mark only that seat as available
--   2. Complete that seat's orders
--   3. Check if all seats are now free - if so, mark table as available
-- ═════════════════════════════════════════════════════════════════════════════

CREATE FUNCTION public.fn_clear_seat(p_table_id TEXT, p_seat_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_remaining_occupied INT;
BEGIN
  -- 1. Mark the specific seat as available (complete reset)
  UPDATE public.table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
  WHERE id=p_seat_id;

  -- 2. Complete orders for this seat only
  UPDATE public.orders
  SET status='completed',
      payment_status='paid',
      updated_at=NOW()
  WHERE table_seat_id=p_seat_id
    AND status IN ('pending', 'preparing', 'ready');

  -- 3. Check if any seats are still occupied
  SELECT COUNT(*)
  INTO v_remaining_occupied
  FROM public.table_seats
  WHERE table_id=p_table_id
    AND status='occupied';

  -- 4. If all seats are free, reset table completely
  IF v_remaining_occupied = 0 THEN
    UPDATE public.restaurant_tables
    SET status='available',
        session_id=NULL,
        current_customer_name=NULL,
        occupied_since=NULL,
        current_order_id=NULL,
        current_order_total=0,
        updated_at=NOW()
    WHERE id=p_table_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'remaining_occupied_seats', v_remaining_occupied,
    'table_fully_cleared', v_remaining_occupied = 0
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 5: CREATE fn_clear_table_complete (For complete table clearance)
-- ═════════════════════════════════════════════════════════════════════════════
-- When an entire table is cleared (all seats):
--   1. Complete ALL table orders
--   2. Reset ALL seats completely
--   3. Reset table completely
--   4. Mark reservation as completed
-- ═════════════════════════════════════════════════════════════════════════════

CREATE FUNCTION public.fn_clear_table_complete(p_table_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_orders_cleared INT;
  v_seats_cleared INT;
BEGIN
  -- 1. Complete all orders (track count)
  UPDATE public.orders
  SET status='completed',
      payment_status='paid',
      updated_at=NOW()
  WHERE table_id=p_table_id
    AND status IN ('pending', 'preparing', 'ready');

  GET DIAGNOSTICS v_orders_cleared = ROW_COUNT;

  -- 2. Clear all seats (track count)
  UPDATE public.table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
  WHERE table_id=p_table_id;

  GET DIAGNOSTICS v_seats_cleared = ROW_COUNT;

  -- 3. Reset entire table
  UPDATE public.restaurant_tables
  SET status='available',
      session_id=NULL,
      current_customer_name=NULL,
      occupied_since=NULL,
      current_order_id=NULL,
      current_order_total=0,
      updated_at=NOW()
  WHERE id=p_table_id;

  -- 4. Mark reservations as completed
  UPDATE public.table_reservations
  SET status='completed',
      actual_check_out=NOW(),
      updated_at=NOW()
  WHERE table_id=p_table_id
    AND status IN ('active', 'seated');

  RETURN jsonb_build_object(
    'success', true,
    'orders_completed', v_orders_cleared,
    'seats_cleared', v_seats_cleared
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 6: Verify session management behavior
-- ═════════════════════════════════════════════════════════════════════════════

-- Example flow that should now work correctly:
--
-- Customer A checks in at 2:43 PM:
--   → fn_seat_guest_v2() sets occupied_since = NOW() (2:43 PM)
--   → reservation status = 'seated'
--   → Duration shown: 0 minutes
--
-- At 2:55 PM (12 min later):
--   → Duration shown: 12 minutes
--   → Everything tracked correctly
--
-- Customer A checks out at 3:15 PM:
--   → fn_checkout_v2() resets occupied_since = NULL
--   → reservation status = 'completed'
--   → Table marked as 'available'
--
-- Customer B checks in at 3:20 PM:
--   → fn_seat_guest_v2() sets occupied_since = NOW() (3:20 PM)
--   → Session ID is completely fresh (new UUID)
--   → Duration shown: 0 minutes (NOT 37 minutes from Customer A!)
--   → No data carryover from Customer A's session

-- ═════════════════════════════════════════════════════════════════════════════
-- Step 7: Force PostgREST schema reload
-- ═════════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';
