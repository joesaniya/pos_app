-- ================================================================
-- MIGRATION: SEAT-LEVEL SEATING SYSTEM
-- Run this in Supabase SQL Editor
-- Features: Auto-seat generation, seat-level occupancy, seat-level ordering
-- ================================================================

-- ── 1. Create table_seats ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS table_seats (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id        UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  seat_label      TEXT NOT NULL, -- e.g. A, B, C, D
  status          TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied')),
  session_id      UUID,
  customer_name   TEXT,
  occupied_since  TIMESTAMPTZ,
  business_id     TEXT NOT NULL,
  updated_by_uid  TEXT,
  updated_by_name TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(table_id, seat_label)
);

-- RLS policies
ALTER TABLE table_seats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_table_seats" ON table_seats;
CREATE POLICY "allow_all_table_seats" ON table_seats FOR ALL USING (true) WITH CHECK (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_table_seats_table ON table_seats(table_id);
CREATE INDEX IF NOT EXISTS idx_table_seats_session ON table_seats(session_id) WHERE session_id IS NOT NULL;


-- ── 2. Trigger for automatic seat generation ───────────────────────────────
CREATE OR REPLACE FUNCTION fn_generate_table_seats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  letters TEXT[] := ARRAY['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
  i INTEGER;
  lbl TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    FOR i IN 1..NEW.capacity LOOP
      lbl := letters[(i - 1) % 26 + 1] || CASE WHEN i > 26 THEN ((i-1)/26)::TEXT ELSE '' END;
      INSERT INTO table_seats(table_id, seat_label, business_id)
      VALUES (NEW.id, lbl, NEW.business_id);
    END LOOP;
  ELSIF TG_OP = 'UPDATE' AND NEW.capacity <> OLD.capacity THEN
    -- Add missing seats if capacity increased
    FOR i IN 1..NEW.capacity LOOP
      lbl := letters[(i - 1) % 26 + 1] || CASE WHEN i > 26 THEN ((i-1)/26)::TEXT ELSE '' END;
      INSERT INTO table_seats(table_id, seat_label, business_id)
      VALUES (NEW.id, lbl, NEW.business_id)
      ON CONFLICT (table_id, seat_label) DO NOTHING;
    END LOOP;
    
    -- Delete excess seats if capacity decreased (only if they are available)
    DELETE FROM table_seats 
    WHERE table_id = NEW.id 
      AND status = 'available'
      AND seat_label NOT IN (
        SELECT letters[(j - 1) % 26 + 1] || CASE WHEN j > 26 THEN ((j-1)/26)::TEXT ELSE '' END 
        FROM generate_series(1, NEW.capacity) j
      );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_table_seats_generate ON restaurant_tables;
CREATE TRIGGER trg_table_seats_generate
  AFTER INSERT OR UPDATE OF capacity ON restaurant_tables
  FOR EACH ROW EXECUTE FUNCTION fn_generate_table_seats();

-- Backfill existing tables with seats
DO $$
DECLARE
  t RECORD;
  i INTEGER;
  lbl TEXT;
  letters TEXT[] := ARRAY['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
BEGIN
  FOR t IN SELECT id, capacity, business_id FROM restaurant_tables LOOP
    FOR i IN 1..t.capacity LOOP
      lbl := letters[(i - 1) % 26 + 1] || CASE WHEN i > 26 THEN ((i-1)/26)::TEXT ELSE '' END;
      INSERT INTO table_seats(table_id, seat_label, business_id)
      VALUES (t.id, lbl, t.business_id)
      ON CONFLICT (table_id, seat_label) DO NOTHING;
    END LOOP;
  END LOOP;
END;
$$;


-- ── 3. Link orders to seats ─────────────────────────────────────────────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS table_seat_id UUID REFERENCES table_seats(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_orders_seat ON orders(table_seat_id) WHERE table_seat_id IS NOT NULL;


-- ── 4. Rebuild the Order View to include table_seat_id ──────────────────────
DROP VIEW IF EXISTS vw_orders_with_items CASCADE;

CREATE VIEW vw_orders_with_items AS
SELECT
  o.id,
  o.order_number,
  o.status,
  o.order_type,
  o.table_id,
  o.table_number,
  o.table_seat_id, -- NEW FIELD
  o.customer_name,
  o.customer_phone,
  o.subtotal,
  o.tax_amount,
  o.discount_amount,
  o.total_amount,
  o.tax_rate,
  o.notes,
  o.business_id,
  o.business_name,
  o.created_by_uid,
  o.created_by_name,
  o.created_by_role,
  o.updated_by_uid,
  o.updated_by_name,
  o.started_at,
  o.ready_at,
  o.completed_at,
  o.cancelled_at,
  o.created_at,
  o.updated_at,
  COALESCE(
    json_agg(
      json_build_object(
        'id',            oi.id,
        'order_id',      oi.order_id,
        'menu_item_id',  oi.menu_item_id,
        'item_name',     oi.item_name,
        'item_price',    oi.item_price,
        'category_name', oi.category_name,
        'is_veg',        oi.is_veg,
        'quantity',      oi.quantity,
        'subtotal',      oi.subtotal,
        'notes',         oi.notes
      )
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'::json
  ) AS items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY
  o.id, o.order_number, o.status, o.order_type,
  o.table_id, o.table_number, o.table_seat_id, o.customer_name, o.customer_phone,
  o.subtotal, o.tax_amount, o.discount_amount, o.total_amount, o.tax_rate,
  o.notes, o.business_id, o.business_name,
  o.created_by_uid, o.created_by_name, o.created_by_role,
  o.updated_by_uid, o.updated_by_name,
  o.started_at, o.ready_at, o.completed_at, o.cancelled_at,
  o.created_at, o.updated_at;

GRANT SELECT ON vw_orders_with_items TO anon, authenticated;


-- ── 5. Modify seat guest RPC to handle partial table walk-ins ───────────────
-- We introduce an optional seat_ids array parameter.
CREATE OR REPLACE FUNCTION fn_seat_guest_v2(
  p_table_id      UUID,
  p_customer_name TEXT,
  p_staff_uid     TEXT DEFAULT NULL,
  p_staff_name    TEXT DEFAULT NULL,
  p_seat_ids      UUID[] DEFAULT NULL -- NULL means entire table
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_session_id     UUID := uuid_generate_v4();
  v_reservation_id UUID;
  v_seat_time      TIMESTAMPTZ := NOW();
  seat_id          UUID;
BEGIN
  -- 1. Look for today's active reservation for full table checks
  SELECT id INTO v_reservation_id
  FROM table_reservations
  WHERE table_id = p_table_id AND status = 'active'
    AND DATE(reserved_for AT TIME ZONE 'Asia/Kolkata') = DATE(NOW() AT TIME ZONE 'Asia/Kolkata')
  ORDER BY reserved_for ASC LIMIT 1;

  -- 2. Mark reservation seated (if full table or reserved)
  IF v_reservation_id IS NOT NULL THEN
    UPDATE table_reservations SET
      status          = 'seated',
      check_in        = NULL,
      updated_by_uid  = p_staff_uid,
      updated_by_name = p_staff_name,
      updated_at      = NOW()
    WHERE id = v_reservation_id;
  END IF;

  -- 3. If partial seating requested (only for non reservations usually)
  IF p_seat_ids IS NOT NULL AND array_length(p_seat_ids, 1) > 0 THEN
    -- Mark specific seats occupied
    FOREACH seat_id IN ARRAY p_seat_ids
    LOOP
      UPDATE table_seats SET
        status = 'occupied',
        session_id = v_session_id,
        customer_name = p_customer_name,
        occupied_since = v_seat_time,
        updated_by_uid = p_staff_uid,
        updated_by_name = p_staff_name,
        updated_at = NOW()
      WHERE id = seat_id AND status = 'available';
    END LOOP;
    
    -- Check if ALL seats are now occupied after this operation
    IF NOT EXISTS (
      SELECT 1 FROM table_seats
      WHERE table_id = p_table_id AND status = 'available'
    ) THEN
      -- All seats occupied → mark table fully occupied
      UPDATE restaurant_tables SET
        status = 'occupied',
        current_customer_name = p_customer_name, 
        occupied_since = COALESCE(occupied_since, v_seat_time),
        session_id = v_session_id,
        updated_by_uid = p_staff_uid, 
        updated_by_name = p_staff_name,
        updated_at = NOW()
      WHERE id = p_table_id;
    ELSE
      -- Partial: update metadata but DON'T change table status to 'occupied'
      -- Table remains 'available' so other seats can still be booked
      UPDATE restaurant_tables SET
        current_customer_name = COALESCE(current_customer_name, p_customer_name),
        occupied_since = COALESCE(occupied_since, v_seat_time),
        -- Notice: We DON'T set status or table-level session_id for partial
        updated_by_uid = p_staff_uid, 
        updated_by_name = p_staff_name,
        updated_at = NOW()
      WHERE id = p_table_id;
    END IF;
    
  ELSE
    -- FULL table occupancy
    UPDATE restaurant_tables SET
      status = 'occupied', 
      current_customer_name = p_customer_name,
      occupied_since = v_seat_time, 
      session_id = v_session_id, -- Full table session
      updated_by_uid = p_staff_uid, 
      updated_by_name = p_staff_name,
      updated_at = NOW()
    WHERE id = p_table_id;
    
    -- Mark all seats inside the table as occupied by this master session
    UPDATE table_seats SET
      status = 'occupied',
      session_id = v_session_id,
      customer_name = p_customer_name,
      occupied_since = v_seat_time,
      updated_by_uid = p_staff_uid,
      updated_by_name = p_staff_name,
      updated_at = NOW()
    WHERE table_id = p_table_id;
  END IF;

  RETURN jsonb_build_object(
    'success',        TRUE,
    'session_id',     v_session_id,
    'reservation_id', v_reservation_id,
    'seated_at',      v_seat_time
  );
END;
$$;
GRANT EXECUTE ON FUNCTION fn_seat_guest_v2 TO anon, authenticated;


-- ── 6. Modify check-out RPC to handle partial seats ───────────────────────
CREATE OR REPLACE FUNCTION fn_checkout_v2(
  p_table_id    UUID,
  p_staff_uid   TEXT DEFAULT NULL,
  p_staff_name  TEXT DEFAULT NULL,
  p_checkout_at TIMESTAMPTZ DEFAULT NOW(),
  p_seat_id     UUID DEFAULT NULL -- If specified, only clear this seat
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_reservation_id UUID;
  v_orders_closed  INTEGER := 0;
  v_next_res       TIMESTAMPTZ;
  v_new_status     TEXT;
  v_old_session    UUID;
  remaining_seats  INTEGER;
BEGIN

  IF p_seat_id IS NOT NULL THEN
    -- PARTIAL CHECKOUT (Single Seat)
    SELECT session_id INTO v_old_session FROM table_seats WHERE id = p_seat_id;
    
    -- Complete this seat's orders
    IF v_old_session IS NOT NULL THEN
      UPDATE orders SET status = 'completed', completed_at = NOW(), updated_at = NOW()
      WHERE table_seat_id = p_seat_id
        AND status IN ('pending', 'preparing', 'ready');
      GET DIAGNOSTICS v_orders_closed = ROW_COUNT;
    END IF;
    
    -- Free the seat
    UPDATE table_seats SET
      status = 'available', session_id = NULL, customer_name = NULL,
      occupied_since = NULL, updated_by_uid = p_staff_uid, updated_by_name = p_staff_name,
      updated_at = NOW()
    WHERE id = p_seat_id;
    
    -- Check if table has any seats left
    SELECT COUNT(*) INTO remaining_seats FROM table_seats WHERE table_id = p_table_id AND status = 'occupied';
    
    IF remaining_seats = 0 THEN
      -- Table is fully empty now, free the table level
      UPDATE restaurant_tables SET
        status = 'available', current_customer_name = NULL, current_order_id = NULL,
        current_order_total = 0, occupied_since = NULL, session_id = NULL,
        updated_by_uid = p_staff_uid, updated_by_name = p_staff_name, updated_at = NOW()
      WHERE id = p_table_id;
      v_new_status := 'available';
    ELSE
      -- Still partially occupied
      v_new_status := 'occupied';
    END IF;
    
    RETURN jsonb_build_object(
      'success', TRUE, 'orders_closed', v_orders_closed, 'table_status', v_new_status, 'checkout_at', p_checkout_at
    );

  ELSE
    -- FULL TABLE CHECKOUT
    SELECT session_id INTO v_old_session FROM restaurant_tables WHERE id = p_table_id;

    SELECT id INTO v_reservation_id FROM table_reservations WHERE table_id = p_table_id AND status IN ('active', 'seated') ORDER BY reserved_for ASC LIMIT 1;

    IF v_reservation_id IS NOT NULL THEN
      UPDATE table_reservations SET
        status = 'completed', actual_check_out = p_checkout_at,
        updated_by_uid = p_staff_uid, updated_by_name = p_staff_name, updated_at = NOW()
      WHERE id = v_reservation_id;
    END IF;

    -- Complete all active orders for the table OR its seats
    UPDATE orders SET status = 'completed', completed_at = NOW(), updated_at = NOW()
    WHERE table_id = p_table_id AND status IN ('pending', 'preparing', 'ready');
    GET DIAGNOSTICS v_orders_closed = ROW_COUNT;

    SELECT reserved_for INTO v_next_res FROM table_reservations
    WHERE table_id = p_table_id AND status = 'active' AND reserved_for BETWEEN NOW() AND NOW() + INTERVAL '30 minutes' ORDER BY reserved_for ASC LIMIT 1;

    v_new_status := CASE WHEN v_next_res IS NOT NULL THEN 'reserved' ELSE 'cleaning' END;

    UPDATE restaurant_tables SET
      status = v_new_status, current_customer_name = NULL, current_order_id = NULL,
      current_order_total = 0, occupied_since = NULL, session_id = NULL,
      updated_by_uid = p_staff_uid, updated_by_name = p_staff_name, updated_at = NOW()
    WHERE id = p_table_id;
    
    -- Clear all properties of its seats
    UPDATE table_seats SET
      status = 'available', session_id = NULL, customer_name = NULL, occupied_since = NULL,
      updated_by_uid = p_staff_uid, updated_by_name = p_staff_name, updated_at = NOW()
    WHERE table_id = p_table_id;

    RETURN jsonb_build_object(
      'success', TRUE, 'reservation_id', v_reservation_id, 'orders_closed', v_orders_closed, 'table_status', v_new_status, 'checkout_at', p_checkout_at
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION fn_checkout_v2 TO anon, authenticated;

-- ================================================================
-- ✅ DONE. The database schema successfully implements partial seating.
-- ================================================================
