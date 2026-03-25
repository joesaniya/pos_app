-- ============================================================
-- SEAT & TABLE CLEARING FUNCTIONS
-- Production-ready flexible clearing at seat and table level
-- ============================================================

-- ============================================================
-- 1. FUNCTION: fn_clear_seat (SINGLE SEAT CLEARING)
-- ============================================================
-- Purpose: Clear a specific seat without affecting other seats
-- Returns: JSON with success status and updated session info
-- ============================================================

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc WHERE proname='fn_clear_seat'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure || ' CASCADE';
  END LOOP;
END $$;

CREATE FUNCTION fn_clear_seat(
  p_table_id TEXT,
  p_seat_id UUID
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_seat_record RECORD;
  v_seat_session UUID;
  v_remaining_occupied INTEGER;
BEGIN

  -- Step 1: Get the seat record
  SELECT id, session_id, customer_name 
  INTO v_seat_record
  FROM table_seats
  WHERE id = p_seat_id AND table_id = p_table_id;

  IF v_seat_record IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Seat not found'
    );
  END IF;

  v_seat_session := v_seat_record.session_id;

  -- Step 2: Mark seat as available
  UPDATE table_seats
  SET 
    status = 'available',
    session_id = NULL,
    customer_name = NULL,
    occupied_since = NULL
  WHERE id = p_seat_id;

  -- Step 3: Mark orders for this seat as completed
  UPDATE orders
  SET status = 'completed'
  WHERE table_seat_id = p_seat_id
    AND status IN ('pending', 'preparing', 'ready');

  -- Step 4: Check if any seats are still occupied
  SELECT COUNT(*)
  INTO v_remaining_occupied
  FROM table_seats
  WHERE table_id = p_table_id AND status = 'occupied';

  -- Step 5: If no seats are occupied, reset table status
  IF v_remaining_occupied = 0 THEN
    UPDATE restaurant_tables
    SET 
      status = 'available',
      session_id = NULL,
      current_session_id = NULL
    WHERE id = p_table_id;
  END IF;

  -- Step 6: Return success
  RETURN jsonb_build_object(
    'success', true,
    'seat_id', p_seat_id,
    'cleared_orders', 1,
    'remaining_occupied_seats', v_remaining_occupied,
    'table_fully_cleared', v_remaining_occupied = 0
  );

END;
$$;

GRANT EXECUTE ON FUNCTION fn_clear_seat(TEXT, UUID)
TO anon, authenticated;


-- ============================================================
-- 2. FUNCTION: fn_clear_table_complete (ENTIRE TABLE CLEARING)
-- ============================================================
-- Purpose: Clear entire table - all seats, all orders
-- Returns: JSON with success status and count of cleared items
-- ============================================================

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc WHERE proname='fn_clear_table_complete'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure || ' CASCADE';
  END LOOP;
END $$;

CREATE FUNCTION fn_clear_table_complete(
  p_table_id TEXT
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_orders_cleared INTEGER := 0;
  v_seats_cleared INTEGER := 0;
BEGIN

  -- Step 1: Count and complete all orders for this table
  UPDATE orders
  SET status = 'completed'
  WHERE table_id::text = p_table_id
    AND status IN ('pending', 'preparing', 'ready');

  GET DIAGNOSTICS v_orders_cleared = ROW_COUNT;

  -- Step 2: Count and reset all seats
  UPDATE table_seats
  SET 
    status = 'available',
    session_id = NULL,
    customer_name = NULL,
    occupied_since = NULL
  WHERE table_id::text = p_table_id;

  GET DIAGNOSTICS v_seats_cleared = ROW_COUNT;

  -- Step 3: Reset table status
  UPDATE restaurant_tables
  SET 
    status = 'available',
    session_id = NULL,
    current_session_id = NULL
  WHERE id::text = p_table_id;

  -- Step 4: Return comprehensive clearing report
  RETURN jsonb_build_object(
    'success', true,
    'table_id', p_table_id,
    'orders_completed', v_orders_cleared,
    'seats_cleared', v_seats_cleared,
    'table_status', 'available'
  );

END;
$$;

GRANT EXECUTE ON FUNCTION fn_clear_table_complete(TEXT)
TO anon, authenticated;


-- ============================================================
-- 3. FUNCTION: fn_get_seat_details (GET SEAT INFO FOR UI)
-- ============================================================
-- Purpose: Fetch full seat details including orders
-- Returns: JSON with seat, customer, and associated orders
-- ============================================================

DROP FUNCTION IF EXISTS fn_get_seat_details(UUID);

CREATE FUNCTION fn_get_seat_details(p_seat_id UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_seat RECORD;
  v_orders JSONB;
BEGIN

  SELECT 
    ts.id,
    ts.table_id,
    ts.seat_label,
    ts.status,
    ts.customer_name,
    ts.session_id,
    ts.occupied_since
  INTO v_seat
  FROM table_seats ts
  WHERE ts.id = p_seat_id;

  IF v_seat IS NULL THEN
    RETURN jsonb_build_object('error', 'Seat not found');
  END IF;

  -- Get associated orders
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'order_number', o.order_number,
        'status', o.status,
        'total_amount', o.total_amount,
        'items_count', (SELECT COUNT(*) FROM order_items WHERE order_id = o.id)
      )
    ) FILTER (WHERE o.id IS NOT NULL),
    '[]'::jsonb
  )
  INTO v_orders
  FROM orders o
  WHERE o.table_seat_id = p_seat_id
    AND o.status IN ('pending', 'preparing', 'ready');

  RETURN jsonb_build_object(
    'seat', jsonb_build_object(
      'id', v_seat.id,
      'table_id', v_seat.table_id,
      'label', v_seat.seat_label,
      'status', v_seat.status,
      'customer_name', v_seat.customer_name,
      'session_id', v_seat.session_id,
      'occupied_since', v_seat.occupied_since
    ),
    'orders', v_orders,
    'total_bill', (
      SELECT COALESCE(SUM(total_amount), 0)
      FROM orders
      WHERE table_seat_id = p_seat_id
        AND status IN ('pending', 'preparing', 'ready')
    )
  );

END;
$$;

GRANT EXECUTE ON FUNCTION fn_get_seat_details(UUID)
TO anon, authenticated;


-- ============================================================
-- 4. FUNCTION: fn_get_table_seat_summaries (TABLE OVERVIEW)
-- ============================================================
-- Purpose: Get all seats and their status for a table (card view)
-- Returns: Array of seats with occupation and bill status
-- ============================================================

DROP FUNCTION IF EXISTS fn_get_table_seat_summaries(TEXT);

CREATE FUNCTION fn_get_table_seat_summaries(p_table_id TEXT)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_result JSONB;
BEGIN

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', ts.id,
        'table_id', ts.table_id,
        'seat_label', ts.seat_label,
        'status', ts.status,
        'customer_name', ts.customer_name,
        'occupied_since', ts.occupied_since,
        'total_bill', COALESCE(
          (SELECT SUM(total_amount) 
           FROM orders 
           WHERE table_seat_id = ts.id 
             AND status IN ('pending', 'preparing', 'ready')),
          0
        ),
        'order_count', (
          SELECT COUNT(*)
          FROM orders
          WHERE table_seat_id = ts.id
            AND status IN ('pending', 'preparing', 'ready')
        )
      )
    ) FILTER (WHERE ts.id IS NOT NULL),
    '[]'::jsonb
  )
  INTO v_result
  FROM table_seats ts
  WHERE ts.table_id = p_table_id
  ORDER BY ts.seat_label ASC;

  RETURN v_result;

END;
$$;

GRANT EXECUTE ON FUNCTION fn_get_table_seat_summaries(TEXT)
TO anon, authenticated;


-- ============================================================
-- REALTIME SUBSCRIPTIONS READY
-- These functions are PostgREST-compatible and trigger
-- realtime updates automatically for subscribed clients
-- ============================================================

NOTIFY pgrst, 'reload schema';
