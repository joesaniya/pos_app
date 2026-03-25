-- ============================================================
-- SEAT-BASED TABLE MANAGEMENT WORKFLOW
-- Complete Implementation with Online & Offline Support
-- ============================================================

-- ============================================================
-- 1. ENSURE TABLE_SEATS HAS BUSINESS_ID
-- ============================================================
ALTER TABLE table_seats ADD COLUMN IF NOT EXISTS business_id TEXT;

CREATE INDEX IF NOT EXISTS idx_seats_business 
ON table_seats(business_id);

-- ============================================================
-- 2. AUTO-SEAT GENERATION TRIGGER
-- Automatically creates seats when a table is created
-- ============================================================
CREATE OR REPLACE FUNCTION fn_generate_table_seats()
RETURNS TRIGGER AS $$
DECLARE 
  i INT;
  v_seat_label TEXT;
BEGIN
  -- Delete old seats if capacity changed
  IF TG_OP = 'UPDATE' AND NEW.capacity != OLD.capacity THEN
    DELETE FROM table_seats WHERE table_id = NEW.id;
  END IF;

  -- Generate seats based on capacity (A, B, C, D, etc.)
  FOR i IN 1..NEW.capacity LOOP
    v_seat_label := chr(64 + i);  -- A, B, C, D...
    
    INSERT INTO table_seats(
      id,
      table_id,
      business_id,
      seat_label,
      status,
      created_at
    ) VALUES (
      uuid_generate_v4(),
      NEW.id,
      NEW.business_id,
      v_seat_label,
      'available',
      NOW()
    )
    ON CONFLICT DO NOTHING;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_seats ON restaurant_tables;
CREATE TRIGGER trg_generate_seats
AFTER INSERT OR UPDATE OF capacity ON restaurant_tables
FOR EACH ROW 
WHEN (NEW.capacity > 0)
EXECUTE FUNCTION fn_generate_table_seats();

-- ============================================================
-- 3. TABLE FOR SEAT SESSION HISTORY (Guest tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS seat_session_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  table_id TEXT NOT NULL,
  table_number INTEGER,
  section TEXT,
  seat_label TEXT NOT NULL,
  session_id UUID NOT NULL,
  customer_name TEXT,
  guest_count INTEGER DEFAULT 1,
  check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  check_out_time TIMESTAMPTZ,
  duration_seconds INTEGER,
  status TEXT DEFAULT 'active' 
    CHECK (status IN ('active', 'checked-out', 'abandoned')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE (session_id, table_id)
);

CREATE INDEX IF NOT EXISTS idx_history_business 
ON seat_session_history(business_id);

CREATE INDEX IF NOT EXISTS idx_history_table 
ON seat_session_history(table_id);

CREATE INDEX IF NOT EXISTS idx_history_session 
ON seat_session_history(session_id);

-- ============================================================
-- 4. ENHANCED fn_seat_guest_v2
-- Supports seating at specific seats with all required params
-- ============================================================
DROP FUNCTION IF EXISTS fn_seat_guest_v2(TEXT, TEXT, TEXT, TEXT, UUID[]) CASCADE;

CREATE OR REPLACE FUNCTION fn_seat_guest_v2(
  p_table_id TEXT,
  p_customer_name TEXT,
  p_staff_uid TEXT DEFAULT NULL,
  p_staff_name TEXT DEFAULT NULL,
  p_seat_ids UUID[] DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_session_id UUID := uuid_generate_v4();
  v_seat_id UUID;
  v_seated_count INT := 0;
BEGIN
  -- Update table status
  UPDATE restaurant_tables
  SET status='occupied', current_session_id=v_session_id
  WHERE id=p_table_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Table not found: %', p_table_id;
  END IF;

  -- Seat specific seats if provided
  IF p_seat_ids IS NOT NULL AND array_length(p_seat_ids, 1) > 0 THEN
    FOREACH v_seat_id IN ARRAY p_seat_ids LOOP
      UPDATE table_seats
      SET status='occupied',
          session_id=v_session_id,
          customer_name=p_customer_name,
          occupied_since=NOW()
      WHERE id=v_seat_id AND status='available';
      
      GET DIAGNOSTICS v_seated_count = ROW_COUNT;
      
      -- Create session history for each seat
      IF v_seated_count > 0 THEN
        INSERT INTO seat_session_history(
          business_id, table_id, table_number, section,
          seat_label, session_id, customer_name,
          guest_count, check_in_time, status
        )
        SELECT 
          rt.business_id, p_table_id, rt.table_number,
          ts.seat_label, v_session_id, p_customer_name,
          1, NOW(), 'active'
        FROM table_seats ts
        LEFT JOIN restaurant_tables rt ON rt.id=p_table_id
        WHERE ts.id=v_seat_id;
      END IF;
    END LOOP;
  ELSE
    -- Seat all available seats
    UPDATE table_seats
    SET status='occupied',
        session_id=v_session_id,
        customer_name=p_customer_name,
        occupied_since=NOW()
    WHERE table_id=p_table_id AND status='available';

    -- Create session history for all seated guests
    INSERT INTO seat_session_history(
      business_id, table_id, table_number, section,
      seat_label, session_id, customer_name,
      guest_count, check_in_time, status
    )
    SELECT
      rt.business_id, ts.table_id, rt.table_number,
      ts.seat_label, v_session_id, p_customer_name,
      1, NOW(), 'active'
    FROM table_seats ts
    LEFT JOIN restaurant_tables rt ON rt.id=p_table_id
    WHERE ts.table_id=p_table_id AND ts.status='occupied' 
      AND ts.session_id=v_session_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'seated_at', NOW()
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION fn_seat_guest_v2(TEXT, TEXT, TEXT, TEXT, UUID[]) 
TO anon, authenticated;

-- ============================================================
-- 5. FUNCTION: Get seat-level order summary
-- ============================================================
DROP FUNCTION IF EXISTS fn_get_seat_orders(UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_get_seat_orders(p_seat_id UUID)
RETURNS TABLE (
  order_id UUID,
  seat_label TEXT,
  customer_name TEXT,
  order_number INT,
  subtotal DECIMAL,
  tax DECIMAL,
  discount DECIMAL,
  total DECIMAL,
  status TEXT,
  payment_status TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    o.id,
    ts.seat_label,
    ts.customer_name,
    o.order_number,
    o.subtotal,
    o.tax_amount,
    o.discount,
    o.total_amount,
    o.status,
    o.payment_status,
    o.created_at
  FROM orders o
  LEFT JOIN table_seats ts ON ts.id=o.table_seat_id
  WHERE o.table_seat_id=p_seat_id
    AND o.status IN ('pending','preparing','ready','completed')
  ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION fn_get_seat_orders(UUID) TO anon, authenticated;

-- ============================================================
-- 6. FUNCTION: Get total bill for a seat
-- ============================================================
DROP FUNCTION IF EXISTS fn_get_seat_bill(UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_get_seat_bill(p_seat_id UUID)
RETURNS TABLE (
  total_bill DECIMAL,
  subtotal DECIMAL,
  tax_total DECIMAL,
  discount_total DECIMAL,
  active_orders INT,
  completed_orders INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed') 
                 THEN o.total_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN o.subtotal ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN o.tax_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN o.discount ELSE 0 END), 0),
    COUNT(CASE WHEN o.status IN ('pending','preparing','ready') THEN 1 END),
    COUNT(CASE WHEN o.status='completed' THEN 1 END)
  FROM orders o
  WHERE o.table_seat_id=p_seat_id;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION fn_get_seat_bill(UUID) TO anon, authenticated;

-- ============================================================
-- 7. ENHANCED fn_clear_seat (Individual Seat Clearing)
-- ============================================================
DROP FUNCTION IF EXISTS fn_clear_seat(TEXT, UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_clear_seat(
  p_table_id TEXT,
  p_seat_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_completed_orders INT := 0;
  v_session_id UUID;
  v_remaining_occupied INT;
  v_new_table_status TEXT;
BEGIN
  -- Get the session ID before clearing
  SELECT session_id INTO v_session_id
  FROM table_seats
  WHERE id=p_seat_id;

  -- Complete all pending orders for this seat
  UPDATE orders
  SET status='completed',
      payment_status='paid',
      completed_at=NOW(),
      updated_at=NOW()
  WHERE table_seat_id=p_seat_id
    AND status IN ('pending','preparing','ready');
  
  GET DIAGNOSTICS v_completed_orders = ROW_COUNT;

  -- Mark seat as available
  UPDATE table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
  WHERE id=p_seat_id;

  -- Update session history to checked-out
  UPDATE seat_session_history
  SET status='checked-out',
      check_out_time=NOW(),
      duration_seconds=EXTRACT(EPOCH FROM (NOW() - check_in_time))::INT,
      updated_at=NOW()
  WHERE session_id=v_session_id AND status='active';

  -- Check remaining occupied seats
  SELECT COUNT(*) INTO v_remaining_occupied
  FROM table_seats
  WHERE table_id=p_table_id AND status='occupied';

  -- Update table status based on remaining seats
  IF v_remaining_occupied = 0 THEN
    UPDATE restaurant_tables
    SET status='available',
        current_session_id=NULL,
        current_customer_name=NULL,
        current_order_id=NULL,
        current_order_total=NULL,
        occupied_since=NULL,
        updated_at=NOW()
    WHERE id=p_table_id;
    
    v_new_table_status := 'available';
  ELSE
    UPDATE restaurant_tables
    SET updated_at=NOW()
    WHERE id=p_table_id;
    
    v_new_table_status := 'occupied';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'cleared_orders', v_completed_orders,
    'remaining_occupied_seats', v_remaining_occupied,
    'table_status', v_new_table_status,
    'cleared_at', NOW()
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION fn_clear_seat(TEXT, UUID) TO anon, authenticated;

-- ============================================================
-- 8. FUNCTION: fn_checkout_v2 (Updated for seat support)
-- ============================================================
DROP FUNCTION IF EXISTS fn_checkout_v2(TEXT, UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_checkout_v2(
  p_table_id TEXT,
  p_seat_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  IF p_seat_id IS NOT NULL THEN
    -- Clear specific seat
    RETURN fn_clear_seat(p_table_id, p_seat_id);
  ELSE
    -- Clear entire table
    DECLARE
      v_completed_orders INT := 0;
      v_seats_cleared INT;
    BEGIN
      -- Complete all orders for table
      UPDATE orders
      SET status='completed',
          payment_status='paid',
          completed_at=NOW(),
          updated_at=NOW()
      WHERE table_id=p_table_id
        AND status IN ('pending','preparing','ready');
      
      GET DIAGNOSTICS v_completed_orders = ROW_COUNT;

      -- Clear all seats
      UPDATE table_seats
      SET status='available',
          session_id=NULL,
          customer_name=NULL,
          occupied_since=NULL,
          updated_at=NOW()
      WHERE table_id=p_table_id;
      
      GET DIAGNOSTICS v_seats_cleared = ROW_COUNT;

      -- Update session history
      UPDATE seat_session_history
      SET status='checked-out',
          check_out_time=NOW(),
          duration_seconds=EXTRACT(EPOCH FROM (NOW() - check_in_time))::INT,
          updated_at=NOW()
      WHERE table_id=p_table_id AND status='active';

      -- Clear table
      UPDATE restaurant_tables
      SET status='available',
          current_session_id=NULL,
          current_customer_name=NULL,
          current_order_id=NULL,
          current_order_total=NULL,
          occupied_since=NULL,
          updated_at=NOW()
      WHERE id=p_table_id;

      RETURN jsonb_build_object(
        'success', true,
        'completed_orders', v_completed_orders,
        'cleared_seats', v_seats_cleared,
        'cleared_at', NOW()
      );
    END;
  END IF;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION fn_checkout_v2(TEXT, UUID) TO anon, authenticated;

-- ============================================================
-- 9. FUNCTION: Get seat duration
-- ============================================================
DROP FUNCTION IF EXISTS fn_get_seat_duration(UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_get_seat_duration(p_seat_id UUID)
RETURNS TABLE (
  duration_minutes INT,
  duration_display TEXT,
  customer_name TEXT,
  seat_label TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(EPOCH FROM (NOW() - COALESCE(ts.occupied_since, NOW())))::INT / 60,
    CASE 
      WHEN ts.occupied_since IS NULL THEN '—'
      ELSE 
        CASE 
          WHEN EXTRACT(HOUR FROM (NOW() - ts.occupied_since))::INT > 0 
            THEN EXTRACT(HOUR FROM (NOW() - ts.occupied_since))::INT || 'h ' || 
                 EXTRACT(MINUTE FROM (NOW() - ts.occupied_since))::INT || 'm'
          ELSE EXTRACT(MINUTE FROM (NOW() - ts.occupied_since))::INT || 'm'
        END
    END,
    ts.customer_name,
    ts.seat_label
  FROM table_seats ts
  WHERE ts.id=p_seat_id;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION fn_get_seat_duration(UUID) TO anon, authenticated;

-- ============================================================
-- 10. VIEW: Seat Occupancy Summary
-- ============================================================
DROP VIEW IF EXISTS vw_seat_occupancy_summary CASCADE;

CREATE VIEW vw_seat_occupancy_summary AS
SELECT
  rt.id as table_id,
  rt.table_number,
  rt.business_id,
  COUNT(ts.id) as total_seats,
  COUNT(CASE WHEN ts.status='occupied' THEN 1 END) as occupied_seats,
  COUNT(CASE WHEN ts.status='available' THEN 1 END) as available_seats,
  COUNT(CASE WHEN ts.status='occupied' AND EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.table_seat_id=ts.id 
    AND o.status IN ('pending','preparing','ready')
  ) THEN 1 END) as seats_with_active_orders,
  COALESCE(
    JSONB_AGG(
      CASE WHEN ts.status='occupied' THEN
        jsonb_build_object(
          'seat_id', ts.id,
          'seat_label', ts.seat_label,
          'customer_name', ts.customer_name,
          'occupied_since', ts.occupied_since,
          'duration_minutes', EXTRACT(EPOCH FROM (NOW() - ts.occupied_since))::INT / 60
        )
      END
    ) FILTER (WHERE ts.status='occupied'),
    '[]'::jsonb
  ) as occupied_seat_details
FROM restaurant_tables rt
LEFT JOIN table_seats ts ON ts.table_id=rt.id
GROUP BY rt.id, rt.table_number, rt.business_id;

GRANT SELECT ON vw_seat_occupancy_summary TO anon, authenticated;

-- ============================================================
-- 11. ENSURE UNIQUE ACTIVE ORDER PROTECTION
-- ============================================================
DROP INDEX IF EXISTS uq_active_seat_order;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_seat_order
ON orders (business_id, table_seat_id)
WHERE status IN ('pending','preparing','ready')
  AND table_seat_id IS NOT NULL;

-- ============================================================
-- ✅ VERIFICATION QUERIES
-- ============================================================

/*
-- Verify trigger was created:
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trg_generate_seats';

-- Verify functions exist:
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'fn_seat_guest_v2',
    'fn_clear_seat',
    'fn_checkout_v2',
    'fn_get_seat_bill',
    'fn_get_seat_duration',
    'fn_generate_table_seats'
  );

-- Verify tables have correct columns:
SELECT column_name FROM information_schema.columns
WHERE table_name IN ('restaurant_tables','table_seats','seat_session_history')
ORDER BY table_name, ordinal_position;

-- Test seat auto-generation:
INSERT INTO restaurant_tables(id, business_id, table_number, capacity, status)
VALUES ('test_table', 'test_biz', 1, 4, 'available');

SELECT seat_label, status FROM table_seats WHERE table_id='test_table';
*/

-- ============================================================
-- ✅ COMPLETE - SEAT-BASED WORKFLOW READY
-- ============================================================
