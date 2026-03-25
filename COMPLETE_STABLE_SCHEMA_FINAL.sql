-- ============================================================
-- 🔥 COMPLETE STABLE SCHEMA (PRODUCTION READY)
-- ============================================================
-- This schema includes ALL required functions, views, tables,
-- and fixes to eliminate PGRST202 and PGRST204 errors.
-- ============================================================

-- ============================================================
-- 0. EXTENSION
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 1. TABLE: restaurant_tables
-- ============================================================
CREATE TABLE IF NOT EXISTS restaurant_tables (
  id TEXT PRIMARY KEY DEFAULT ('tbl_' || extract(epoch from now())::text),  -- Changed to TEXT to match app's ID format
  business_id TEXT NOT NULL,
  table_number INTEGER NOT NULL,
  capacity INTEGER DEFAULT 4,
  status TEXT DEFAULT 'available'
    CHECK (status IN ('available','occupied','reserved','cleaning','inactive')),
  current_session_id UUID,
  session_id TEXT,
  current_customer_name TEXT,
  customer_name TEXT GENERATED ALWAYS AS (current_customer_name) STORED,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (business_id, table_number)
);

CREATE INDEX IF NOT EXISTS idx_tables_business 
ON restaurant_tables(business_id);


-- ============================================================
-- 2. TABLE: table_session_history (GUEST VISIT TRACKING)
-- ============================================================
CREATE TABLE IF NOT EXISTS seat_session_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  table_id TEXT NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  table_number INTEGER,
  section TEXT,
  seat_label TEXT NOT NULL,
  session_id UUID NOT NULL,
  customer_name TEXT,
  guest_count INTEGER DEFAULT 1,
  check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  check_out_time TIMESTAMPTZ,
  duration_seconds INTEGER,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'checked-out', 'abandoned')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE (session_id, table_id)
);

CREATE INDEX IF NOT EXISTS idx_history_business ON seat_session_history(business_id);
CREATE INDEX IF NOT EXISTS idx_history_table ON seat_session_history(table_id);
CREATE INDEX IF NOT EXISTS idx_history_session ON seat_session_history(session_id);

-- ============================================================
-- 3. TABLE: table_reservations (MATCHES YOUR DB)
-- ============================================================
CREATE TABLE IF NOT EXISTS table_reservations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  table_id TEXT REFERENCES restaurant_tables(id) ON DELETE CASCADE,  -- Changed to TEXT

  customer_name TEXT,
  phone TEXT,

  guest_count INTEGER DEFAULT 1,

  -- ✅ YOUR ACTUAL STRUCTURE
  reserved_for TIMESTAMPTZ,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,

  -- ✅ REQUIRED FIX
  actual_check_out TIMESTAMPTZ,

  status TEXT DEFAULT 'active'
    CHECK (status IN ('active','confirmed','seated','completed','cancelled','no_show')),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reservations_table 
ON table_reservations(table_id);


-- ============================================================
-- 4. TABLE: table_seats (WITH BUSINESS_ID)
-- ============================================================
CREATE TABLE IF NOT EXISTS table_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id TEXT REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  business_id TEXT,
  seat_label TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','occupied')),
  session_id UUID,
  customer_name TEXT,
  occupied_since TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(table_id, seat_label)
);

CREATE INDEX IF NOT EXISTS idx_seats_business ON table_seats(business_id);

CREATE INDEX IF NOT EXISTS idx_seats_table 
ON table_seats(table_id);


-- ============================================================
-- 5. ORDERS TABLE PATCH (SAFE)
-- ============================================================
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_id TEXT;  -- Changed to TEXT
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_seat_id UUID REFERENCES table_seats(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS session_id UUID;

CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_orders_seat ON orders(table_seat_id);
CREATE INDEX IF NOT EXISTS idx_orders_session ON orders(session_id);


-- ============================================================
-- 6. AUTO-SEAT GENERATION TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION fn_generate_table_seats()
RETURNS TRIGGER AS $$
DECLARE 
  i INT;
  v_seat_label TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.capacity != OLD.capacity THEN
    DELETE FROM table_seats WHERE table_id = NEW.id;
  END IF;

  FOR i IN 1..NEW.capacity LOOP
    v_seat_label := chr(64 + i);
    
    INSERT INTO table_seats(
      id, table_id, business_id, seat_label, status, created_at
    ) VALUES (
      uuid_generate_v4(), NEW.id, NEW.business_id,
      v_seat_label, 'available', NOW()
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
-- 7. VIEW: vw_orders_with_items (REQUIRED FOR fn_table_orders_v2)
-- ============================================================
DROP VIEW IF EXISTS vw_orders_with_items CASCADE;

CREATE VIEW vw_orders_with_items AS
SELECT
  o.id,
  o.business_id,
  o.table_id,
  o.table_seat_id,
  o.order_number,
  o.status,
  o.payment_status,
  o.subtotal,
  o.tax_amount as tax,
  o.discount,
  o.discount_code,
  o.total_amount as total,
  o.session_id,
  o.created_at,
  o.updated_at,
  o.created_by_uid,
  o.created_by_name,
  o.payment_method,
  o.notes,
  o.reference_id,
  CASE 
    WHEN o.status IN ('pending', 'preparing', 'ready') THEN true
    ELSE false
  END as is_active,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', oi.id,
        'item_name', oi.item_name,
        'quantity', oi.quantity,
        'item_price', oi.item_price,
        'subtotal', oi.subtotal,
        'notes', oi.notes
      )
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'::jsonb
  ) as items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id;

GRANT SELECT ON vw_orders_with_items TO anon, authenticated;


-- ============================================================
-- 8. FUNCTION: fn_table_orders_v2 (FIXES PGRST202 ERROR)
-- ============================================================
DROP FUNCTION IF EXISTS fn_table_orders_v2(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION fn_table_orders_v2(p_table_id TEXT)
RETURNS TABLE (
  id UUID,
  business_id TEXT,
  table_id TEXT,
  table_seat_id UUID,
  order_number INT,
  status TEXT,
  payment_status TEXT,
  subtotal DECIMAL,
  tax DECIMAL,
  discount DECIMAL,
  discount_code TEXT,
  total DECIMAL,
  session_id TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by_uid TEXT,
  created_by_name TEXT,
  payment_method TEXT,
  notes TEXT,
  reference_id TEXT,
  is_active BOOLEAN,
  items JSONB
) AS $$
DECLARE
  v_session_id TEXT;
BEGIN
  -- Get current session from table
  SELECT rt.session_id INTO v_session_id
  FROM public.restaurant_tables rt
  WHERE rt.id = p_table_id;

  -- Return orders for this table, optionally filtered by session
  RETURN QUERY
  SELECT
    vow.id,
    vow.business_id,
    vow.table_id,
    vow.table_seat_id,
    vow.order_number,
    vow.status,
    vow.payment_status,
    vow.subtotal,
    vow.tax,
    vow.discount,
    vow.discount_code,
    vow.total,
    vow.session_id::TEXT,  -- Cast to TEXT for consistency
    vow.created_at,
    vow.updated_at,
    vow.created_by_uid,
    vow.created_by_name,
    vow.payment_method,
    vow.notes,
    vow.reference_id,
    vow.is_active,
    vow.items
  FROM public.vw_orders_with_items vow
  WHERE vow.table_id::text = p_table_id
    AND vow.status IN ('pending', 'preparing', 'ready')
    AND (
      v_session_id IS NULL 
      OR vow.session_id IS NULL 
      OR vow.session_id::TEXT = v_session_id  -- Cast for comparison
    )
  ORDER BY vow.created_at ASC;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION fn_table_orders_v2(TEXT) TO anon, authenticated;


-- ============================================================
-- 9. FUNCTION: fn_seat_guest_v2 (ENHANCED)
-- ============================================================
DROP FUNCTION IF EXISTS fn_seat_guest_v2 CASCADE;

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
  UPDATE restaurant_tables
  SET status='occupied', current_session_id=v_session_id
  WHERE id=p_table_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Table not found: %', p_table_id;
  END IF;

  IF p_seat_ids IS NOT NULL AND array_length(p_seat_ids, 1) > 0 THEN
    FOREACH v_seat_id IN ARRAY p_seat_ids LOOP
      UPDATE table_seats
      SET status='occupied',
          session_id=v_session_id,
          customer_name=p_customer_name,
          occupied_since=NOW(),
          updated_at=NOW()
      WHERE id=v_seat_id AND table_id = p_table_id AND status='available';
      
      GET DIAGNOSTICS v_seated_count = ROW_COUNT;
      
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
    UPDATE table_seats
    SET status='occupied',
        session_id=v_session_id,
        customer_name=p_customer_name,
        occupied_since=NOW(),
        updated_at=NOW()
    WHERE table_id=p_table_id AND status='available';

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

GRANT EXECUTE ON FUNCTION fn_seat_guest_v2 TO anon, authenticated;


-- ============================================================
-- 10. FUNCTION: fn_clear_seat (INDIVIDUAL SEAT CLEARING)
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
  SELECT session_id INTO v_session_id
  FROM table_seats
  WHERE id=p_seat_id AND table_id=p_table_id;

  UPDATE orders
  SET status='completed',
      payment_status='paid',
      completed_at=NOW(),
      updated_at=NOW()
  WHERE table_seat_id=p_seat_id
    AND status IN ('pending','preparing','ready');
  
  GET DIAGNOSTICS v_completed_orders = ROW_COUNT;

  UPDATE table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
  WHERE id=p_seat_id AND table_id=p_table_id;

  UPDATE seat_session_history
  SET status='checked-out',
      check_out_time=NOW(),
      duration_seconds=EXTRACT(EPOCH FROM (NOW() - check_in_time))::INT,
      updated_at=NOW()
  WHERE session_id=v_session_id AND status='active';

  SELECT COUNT(*) INTO v_remaining_occupied
  FROM table_seats
  WHERE table_id=p_table_id AND status='occupied';

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
-- 11. FUNCTION: fn_checkout_v2 (MAIN - UPDATED)
-- ============================================================
DROP FUNCTION IF EXISTS fn_checkout_v2(TEXT, UUID) CASCADE;

CREATE OR REPLACE FUNCTION fn_checkout_v2(
  p_table_id TEXT,
  p_seat_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  IF p_seat_id IS NOT NULL THEN
    RETURN fn_clear_seat(p_table_id, p_seat_id);
  ELSE
    DECLARE
      v_completed_orders INT := 0;
      v_seats_cleared INT;
    BEGIN
      UPDATE orders
      SET status='completed',
          payment_status='paid',
          completed_at=NOW(),
          updated_at=NOW()
      WHERE table_id=p_table_id
        AND status IN ('pending','preparing','ready');
      
      GET DIAGNOSTICS v_completed_orders = ROW_COUNT;

      UPDATE table_seats
      SET status='available',
          session_id=NULL,
          customer_name=NULL,
          occupied_since=NULL,
          updated_at=NOW()
      WHERE table_id=p_table_id;
      
      GET DIAGNOSTICS v_seats_cleared = ROW_COUNT;

      UPDATE seat_session_history
      SET status='checked-out',
          check_out_time=NOW(),
          duration_seconds=EXTRACT(EPOCH FROM (NOW() - check_in_time))::INT,
          updated_at=NOW()
      WHERE table_id=p_table_id AND status='active';

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

GRANT EXECUTE ON FUNCTION fn_checkout_v2 TO anon, authenticated;


-- ============================================================
-- 12. FUNCTION: fn_get_seat_bill
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
                 THEN o.total_amount ELSE 0 END), 0)::DECIMAL,
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN o.subtotal ELSE 0 END), 0)::DECIMAL,
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN COALESCE(o.tax_amount,0) ELSE 0 END), 0)::DECIMAL,
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN COALESCE(o.discount,0) ELSE 0 END), 0)::DECIMAL,
    COUNT(CASE WHEN o.status IN ('pending','preparing','ready') THEN 1 END)::INT,
    COUNT(CASE WHEN o.status='completed' THEN 1 END)::INT
  FROM orders o
  WHERE o.table_seat_id=p_seat_id;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION fn_get_seat_bill(UUID) TO anon, authenticated;

-- ============================================================
-- 13. FUNCTION: fn_get_seat_duration
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
-- 14. FUNCTION: fn_checkout_v2 (BACKWARD COMPAT FOR YOUR FLUTTER)
-- ============================================================
DROP FUNCTION IF EXISTS fn_checkout_v2(
  TIMESTAMPTZ, TEXT, TEXT, TEXT
) CASCADE;

CREATE OR REPLACE FUNCTION fn_checkout_v2(
  p_checkout_at TIMESTAMPTZ,
  p_staff_name TEXT,
  p_staff_uid TEXT,
  p_table_id TEXT  -- Changed from UUID to TEXT
)
RETURNS JSONB AS $$
BEGIN
  RETURN fn_checkout_v2(p_table_id, NULL);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION fn_checkout_v2(
  TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO anon, authenticated;


-- ============================================================
-- 15. VIEW: vw_seat_occupancy_summary
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
-- 16. VIEW: vw_tables_with_reservation (FIXES PGRST204 ERROR)
-- ============================================================
DROP VIEW IF EXISTS vw_tables_with_reservation CASCADE;

CREATE VIEW vw_tables_with_reservation AS
SELECT
  rt.*,
  CASE 
    WHEN tr.id IS NOT NULL THEN jsonb_build_object(
      'id', tr.id,
      'customer_name', tr.customer_name,
      'phone', tr.phone,
      'guest_count', tr.guest_count,

      -- ✅ SAFE OLD STRUCTURE
      'reserved_date', (tr.reserved_for)::date,
      'start_time', (tr.reserved_for)::time,
      'end_time', (tr.check_out)::time,

      'res_actual_check_out', tr.actual_check_out,
      'status', tr.status
    )
    ELSE NULL
  END AS reservation_data
FROM restaurant_tables rt
LEFT JOIN table_reservations tr 
  ON tr.table_id = rt.id
  AND tr.status IN ('active','confirmed','seated');

GRANT SELECT ON vw_tables_with_reservation TO anon, authenticated;


-- ============================================================
-- 17. UNIQUE ACTIVE ORDER PROTECTION
-- ============================================================
DROP INDEX IF EXISTS uq_active_order;
DROP INDEX IF EXISTS uq_active_seat_order;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_seat_order
ON orders (business_id, table_seat_id)
WHERE status IN ('pending','preparing','ready')
  AND table_seat_id IS NOT NULL;


-- ============================================================
-- ✅ VERIFICATION QUERIES (Run these to confirm fixes)
-- ============================================================

-- Verify trigger created:
-- SELECT * FROM information_schema.triggers 
-- WHERE trigger_name = 'trg_generate_seats';

-- Verify functions exist:
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_schema = 'public'
--   AND routine_name IN ('fn_seat_guest_v2', 'fn_clear_seat', 'fn_get_seat_bill', 'fn_get_seat_duration');

-- Verify session_history table:
-- SELECT COUNT(*) FROM seat_session_history;

-- Verify seat auto-generation (run after inserting test table):
-- INSERT INTO restaurant_tables(id, business_id, table_number, capacity, status)
-- VALUES ('test-tbl-001', 'test-biz', 1, 4, 'available');
-- SELECT seat_label, status FROM table_seats WHERE table_id='test-tbl-001';
-- Expected: 4 rows with labels A, B, C, D all available

-- ============================================================
-- ✅ COMPLETE — SEAT-BASED WORKFLOW READY
-- ============================================================
