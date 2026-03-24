-- ════════════════════════════════════════════════════════════════════════════
-- FINAL MIGRATION: Fix Missing Functions & Schema Issues
-- Production-ready, conflict-free
-- ════════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────────────────
-- 0. CLEANUP & SCHEMA SYNC
-- ────────────────────────────────────────────────────────────────────────────

-- Refresh schema cache by dropping and recreating affected views
DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;
DROP FUNCTION IF EXISTS public.fn_table_orders_v2(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_seat_guest_v2 CASCADE;
DROP FUNCTION IF EXISTS public.fn_checkout_v2 CASCADE;


-- ────────────────────────────────────────────────────────────────────────────
-- 1. ENSURE TABLE STRUCTURE
-- ────────────────────────────────────────────────────────────────────────────

-- Add missing columns to table_reservations if needed
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public'
    AND table_name = 'table_reservations'
    AND column_name = 'actual_check_out'
  ) THEN
    ALTER TABLE public.table_reservations 
    ADD COLUMN actual_check_out TIMESTAMPTZ;
  END IF;
END $$;

-- Create table_seats if it doesn't exist
CREATE TABLE IF NOT EXISTS public.table_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id UUID REFERENCES public.restaurant_tables(id) ON DELETE CASCADE,
  seat_label TEXT NOT NULL,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','occupied')),
  session_id UUID,
  customer_name TEXT,
  occupied_since TIMESTAMPTZ,
  business_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(table_id, seat_label)
);

CREATE INDEX IF NOT EXISTS idx_seats_table ON public.table_seats(table_id);
CREATE INDEX IF NOT EXISTS idx_seats_session ON public.table_seats(session_id);

-- Add table_seat_id to orders if missing
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS table_seat_id UUID REFERENCES public.table_seats(id);

CREATE INDEX IF NOT EXISTS idx_orders_seat ON public.orders(table_seat_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 2. CREATE VIEWS
-- ────────────────────────────────────────────────────────────────────────────

-- View: Tables with Reservation Data
CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.id,
  rt.business_id,
  rt.table_number,
  rt.section,
  rt.capacity,
  rt.status,
  rt.current_customer_name,
  rt.current_order_id,
  rt.current_order_total,
  rt.occupied_since,
  rt.session_id,
  rt.is_active,
  rt.shape,
  rt.floor,
  rt.created_by_uid,
  rt.created_by_name,
  rt.updated_by_uid,
  rt.updated_by_name,
  rt.created_at,
  rt.updated_at,
  CASE WHEN tr.id IS NOT NULL THEN jsonb_build_object(
    'id', tr.id,
    'customer_name', tr.customer_name,
    'phone', tr.phone,
    'guest_count', tr.guest_count,
    'reserved_for', tr.reserved_for,
    'check_in', tr.check_in,
    'check_out', tr.check_out,
    'actual_check_out', tr.actual_check_out,
    'notes', tr.notes,
    'status', tr.status,
    'created_by_name', tr.created_by_name
  ) ELSE NULL END AS reservation_data
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr ON 
  tr.table_id = rt.id 
  AND tr.status IN ('active', 'seated')
  AND DATE(tr.reserved_for AT TIME ZONE 'Asia/Kolkata') = DATE(NOW() AT TIME ZONE 'Asia/Kolkata');

GRANT SELECT ON public.vw_tables_with_reservation TO anon, authenticated;


-- View: Orders with Items
CREATE VIEW public.vw_orders_with_items AS
SELECT
  o.id,
  o.business_id,
  o.table_id,
  o.table_seat_id,
  o.order_number,
  o.status,
  o.payment_status,
  o.subtotal,
  o.tax,
  o.discount,
  o.discount_code,
  o.total,
  o.session_id,
  o.created_at,
  o.updated_at,
  o.created_by_uid,
  o.created_by_name,
  o.payment_method,
  o.notes,
  o.reference_id,
  o.is_active,
  COALESCE(
    json_agg(
      json_build_object(
        'id', oi.id,
        'item_name', oi.item_name,
        'quantity', oi.quantity,
        'subtotal', oi.subtotal
      ) ORDER BY oi.created_at
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'::json
  ) AS items
FROM public.orders o
LEFT JOIN public.order_items oi ON oi.order_id = o.id
GROUP BY o.id;

GRANT SELECT ON public.vw_orders_with_items TO anon, authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 3. CREATE FUNCTIONS
-- ────────────────────────────────────────────────────────────────────────────

-- Function: Get table orders (session-aware)
CREATE OR REPLACE FUNCTION public.fn_table_orders_v2(p_table_id UUID)
RETURNS TABLE (
  id UUID,
  business_id TEXT,
  table_id UUID,
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
  items JSON
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
    o.id,
    o.business_id,
    o.table_id,
    o.table_seat_id,
    o.order_number,
    o.status,
    o.payment_status,
    o.subtotal,
    o.tax,
    o.discount,
    o.discount_code,
    o.total,
    o.session_id,
    o.created_at,
    o.updated_at,
    o.created_by_uid,
    o.created_by_name,
    o.payment_method,
    o.notes,
    o.reference_id,
    o.is_active,
    vow.items
  FROM public.vw_orders_with_items vow
  JOIN public.orders o ON o.id = vow.id
  WHERE o.table_id = p_table_id
    AND o.status IN ('pending', 'preparing', 'ready')
    AND (
      v_session_id IS NULL 
      OR o.session_id IS NULL 
      OR o.session_id = v_session_id
    )
  ORDER BY o.created_at ASC;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.fn_table_orders_v2(UUID) TO anon, authenticated;


-- Function: Seat guest with optional per-seat selection
CREATE OR REPLACE FUNCTION public.fn_seat_guest_v2(
  p_table_id UUID,
  p_customer_name TEXT,
  p_staff_uid TEXT DEFAULT NULL,
  p_staff_name TEXT DEFAULT NULL,
  p_seat_ids UUID[] DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_session_id UUID := uuid_generate_v4();
  v_seat_time TIMESTAMPTZ := NOW();
  seat_id UUID;
BEGIN

  IF p_seat_ids IS NOT NULL AND array_length(p_seat_ids, 1) > 0 THEN
    -- Seat specific seats
    FOREACH seat_id IN ARRAY p_seat_ids LOOP
      UPDATE public.table_seats SET
        status='occupied',
        session_id=v_session_id,
        customer_name=p_customer_name,
        occupied_since=v_seat_time
      WHERE id=seat_id AND status='available';
    END LOOP;

    -- Mark table as occupied if all seats are now occupied
    IF NOT EXISTS (
      SELECT 1 FROM public.table_seats
      WHERE table_id=p_table_id AND status='available'
    ) THEN
      UPDATE public.restaurant_tables
      SET status='occupied', session_id=v_session_id
      WHERE id=p_table_id;
    END IF;

  ELSE
    -- Seat entire table
    UPDATE public.restaurant_tables
    SET status='occupied', session_id=v_session_id
    WHERE id=p_table_id;

    UPDATE public.table_seats
    SET status='occupied',
        session_id=v_session_id,
        customer_name=p_customer_name,
        occupied_since=v_seat_time
    WHERE table_id=p_table_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.fn_seat_guest_v2 TO anon, authenticated;


-- Function: Checkout (per-seat or full table) with staff tracking
CREATE OR REPLACE FUNCTION public.fn_checkout_v2(
  p_table_id    UUID,
  p_staff_uid   TEXT DEFAULT NULL,
  p_staff_name  TEXT DEFAULT NULL,
  p_checkout_at TIMESTAMPTZ DEFAULT NOW(),
  p_seat_id     UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_orders_closed  INTEGER := 0;
  v_new_status     TEXT;
  v_reservation_id UUID;
  v_next_res       TIMESTAMPTZ;
  remaining_seats  INT;
BEGIN

  IF p_seat_id IS NOT NULL THEN
    -- PARTIAL CHECKOUT (Single Seat)
    -- Complete this seat's orders
    UPDATE public.orders SET 
      status='completed', 
      completed_at=NOW(), 
      updated_at=NOW()
    WHERE table_seat_id=p_seat_id
      AND status IN ('pending','preparing','ready');
    GET DIAGNOSTICS v_orders_closed = ROW_COUNT;

    -- Free the seat, recording staff info
    UPDATE public.table_seats SET
      status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
    WHERE id=p_seat_id;

    -- Check if table has any seats left occupied
    SELECT COUNT(*) INTO remaining_seats
    FROM public.table_seats
    WHERE table_id=p_table_id AND status='occupied';

    IF remaining_seats=0 THEN
      -- Table is fully empty now
      UPDATE public.restaurant_tables SET
        status='available',
        current_customer_name=NULL,
        current_order_id=NULL,
        current_order_total=0,
        occupied_since=NULL,
        session_id=NULL,
        updated_at=NOW()
      WHERE id=p_table_id;
      v_new_status := 'available';
    ELSE
      -- Still partially occupied
      v_new_status := 'occupied';
    END IF;

    RETURN jsonb_build_object(
      'success', TRUE,
      'orders_closed', v_orders_closed,
      'table_status', v_new_status,
      'checkout_at', p_checkout_at
    );

  ELSE
    -- FULL TABLE CHECKOUT with reservation handling
    SELECT id INTO v_reservation_id
    FROM public.table_reservations
    WHERE table_id=p_table_id AND status IN ('active','seated')
    ORDER BY reserved_for ASC LIMIT 1;

    -- Mark reservation as completed
    IF v_reservation_id IS NOT NULL THEN
      UPDATE public.table_reservations SET
        status='completed',
        actual_check_out=p_checkout_at,
        updated_at=NOW()
      WHERE id=v_reservation_id;
    END IF;

    -- Complete all orders for the table
    UPDATE public.orders SET status='completed', completed_at=NOW(), updated_at=NOW()
    WHERE table_id=p_table_id
      AND status IN ('pending','preparing','ready');
    GET DIAGNOSTICS v_orders_closed = ROW_COUNT;

    -- Check for next upcoming reservation for status determination
    SELECT reserved_for INTO v_next_res
    FROM public.table_reservations
    WHERE table_id=p_table_id 
      AND status='active'
      AND reserved_for BETWEEN NOW() AND NOW() + INTERVAL '30 minutes'
    ORDER BY reserved_for ASC LIMIT 1;

    v_new_status := CASE WHEN v_next_res IS NOT NULL THEN 'reserved' ELSE 'cleaning' END;

    -- Clear entire table
    UPDATE public.restaurant_tables SET
      status=v_new_status,
      current_customer_name=NULL,
      current_order_id=NULL,
      current_order_total=0,
      occupied_since=NULL,
      session_id=NULL,
      updated_at=NOW()
    WHERE id=p_table_id;

    -- Clear all seats
    UPDATE public.table_seats SET
      status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL,
      updated_at=NOW()
    WHERE table_id=p_table_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'reservation_id', v_reservation_id,
      'orders_closed', v_orders_closed,
      'table_status', v_new_status,
      'checkout_at', p_checkout_at
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.fn_checkout_v2 TO anon, authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. AUTO-SEAT GENERATION TRIGGER
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_generate_table_seats()
RETURNS TRIGGER AS $$
DECLARE 
  i INT;
BEGIN
  FOR i IN 1..NEW.capacity LOOP
    INSERT INTO public.table_seats(table_id, seat_label, business_id)
    VALUES (NEW.id, chr(64+i), NEW.business_id)
    ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_seats ON public.restaurant_tables;
CREATE TRIGGER trg_generate_seats
AFTER INSERT OR UPDATE OF capacity ON public.restaurant_tables
FOR EACH ROW EXECUTE FUNCTION public.fn_generate_table_seats();


-- ────────────────────────────────────────────────────────────────────────────
-- 5. UNIQUE CONSTRAINT (prevent duplicate active orders per seat)
-- ────────────────────────────────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_seat_order
ON public.orders (business_id, table_id, table_seat_id)
WHERE status IN ('pending','preparing','ready')
  AND table_seat_id IS NOT NULL;


-- ════════════════════════════════════════════════════════════════════════════
-- ✅ MIGRATION COMPLETE
-- ════════════════════════════════════════════════════════════════════════════
