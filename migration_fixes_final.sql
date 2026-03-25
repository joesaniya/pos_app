-- ════════════════════════════════════════════════════════════════════════════
-- FINAL MIGRATION: Fix Missing Functions & Schema Issues
-- Production-ready, conflict-free
-- ════════════════════════════════════════════════════════════════════════════

-- AFTER RUNNING THIS MIGRATION:
-- 1. Refresh PostgREST schema cache by running: SELECT 1;
-- 2. Or restart your Supabase project
-- 3. Verify functions are available: SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'fn_%';

-- ────────────────────────────────────────────────────────────────────────────
-- 0. CLEANUP & SCHEMA SYNC
-- ────────────────────────────────────────────────────────────────────────────

-- Refresh schema cache by dropping and recreating affected views
DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;
DROP FUNCTION IF EXISTS public.fn_table_orders_v2(TEXT) CASCADE;
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

-- Create seat_session_history table for analytics
CREATE TABLE IF NOT EXISTS public.seat_session_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT,
  table_id TEXT,
  table_number TEXT,
  section TEXT,
  seat_label TEXT,
  session_id UUID,
  customer_name TEXT,
  guest_count INT DEFAULT 1,
  check_in_time TIMESTAMPTZ DEFAULT NOW(),
  check_out_time TIMESTAMPTZ,
  duration_seconds INT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','checked-out','expired')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_history_business ON public.seat_session_history(business_id);
CREATE INDEX IF NOT EXISTS idx_history_table ON public.seat_session_history(table_id);
CREATE INDEX IF NOT EXISTS idx_history_session ON public.seat_session_history(session_id);

-- Add table_seat_id to orders if missing
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS table_seat_id UUID REFERENCES public.table_seats(id);

CREATE INDEX IF NOT EXISTS idx_orders_seat ON public.orders(table_seat_id);

-- Add compatibility fields to restaurant_tables (legacy customer_name alias + current_customer_name)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'restaurant_tables'
      AND column_name = 'current_customer_name'
  ) THEN
    ALTER TABLE public.restaurant_tables
      ADD COLUMN current_customer_name TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'restaurant_tables'
      AND column_name = 'customer_name'
  ) THEN
    ALTER TABLE public.restaurant_tables
      ADD COLUMN customer_name TEXT;
  END IF;

  UPDATE public.restaurant_tables
  SET customer_name = current_customer_name
  WHERE current_customer_name IS NOT NULL;
END $$;

-- Keep both fields in sync via trigger
CREATE OR REPLACE FUNCTION public.trg_sync_restaurant_tables_customer_name()
RETURNS trigger AS $$
BEGIN
  NEW.customer_name := NEW.current_customer_name;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_restaurant_tables_customer_name ON public.restaurant_tables;
CREATE TRIGGER trg_sync_restaurant_tables_customer_name
BEFORE INSERT OR UPDATE ON public.restaurant_tables
FOR EACH ROW
EXECUTE PROCEDURE public.trg_sync_restaurant_tables_customer_name();


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
  rt.current_customer_name AS customer_name,
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
  COALESCE(o.tax, o.tax_amount, 0) AS tax,
  COALESCE(o.discount, o.discount_amount, 0) AS discount,
  o.discount_code,
  COALESCE(o.total, o.total_amount, 0) AS total,
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
CREATE OR REPLACE FUNCTION public.fn_table_orders_v2(p_table_id TEXT)
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
  WHERE o.table_id::text = p_table_id
    AND o.status IN ('pending', 'preparing', 'ready')
    AND (
      v_session_id IS NULL 
      OR o.session_id IS NULL 
      OR o.session_id::text = v_session_id
    )
  ORDER BY o.created_at ASC;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.fn_table_orders_v2(TEXT) TO anon, authenticated;


-- Function: Seat guest with optional per-seat selection
CREATE OR REPLACE FUNCTION public.fn_seat_guest_v2(
  p_table_id TEXT,
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
  p_table_id    TEXT,
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
-- 6. REVENUE SUMMARY FUNCTION
-- ────────────────────────────────────────────────────────────────────────────

-- Function: Revenue analytics for dashboard
CREATE OR REPLACE FUNCTION public.fn_revenue_summary(
  p_business_id TEXT,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_staff_uid TEXT DEFAULT NULL
)
RETURNS TABLE (
  total_revenue DECIMAL,
  total_orders BIGINT,
  avg_order DECIMAL,
  completed BIGINT,
  cancelled BIGINT
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_total_revenue DECIMAL := 0;
  v_total_orders BIGINT := 0;
  v_avg_order DECIMAL := 0;
  v_completed BIGINT := 0;
  v_cancelled BIGINT := 0;
BEGIN
  -- Calculate metrics from completed orders only
  SELECT
    COALESCE(SUM(total_amount), 0)::DECIMAL,
    COUNT(*)::BIGINT,
    CASE WHEN COUNT(*) > 0 THEN COALESCE(AVG(total_amount), 0)::DECIMAL ELSE 0 END,
    COUNT(*)::BIGINT,
    0::BIGINT
  INTO v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled
  FROM public.orders
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND payment_status = 'paid'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  RETURN QUERY SELECT v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 7. EXPIRE STALE RESERVATIONS FUNCTION
-- ────────────────────────────────────────────────────────────────────────────

-- Function: Auto-expire stale reservations (no-show after check-in time + buffer)
CREATE OR REPLACE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB AS $$
DECLARE
  expired_ids UUID[];
  expired_count INT := 0;
BEGIN
  -- Find reservations that should be expired:
  -- - Status is 'active' or 'seated'
  -- - Current time is past check_out time + 30 minutes buffer
  -- - OR past reserved_for time + 2 hours (no-show)
  WITH expired_reservations AS (
    UPDATE public.table_reservations
    SET status = 'no_show', updated_at = NOW()
    WHERE business_id = p_business_id
      AND status IN ('active', 'seated')
      AND (
        -- Past check-out time + 30 min buffer
        (check_out IS NOT NULL AND NOW() > check_out + INTERVAL '30 minutes')
        OR
        -- No check-in and past reserved time + 2 hours (no-show)
        (check_in IS NULL AND NOW() > reserved_for + INTERVAL '2 hours')
      )
    RETURNING id
  )
  SELECT array_agg(id) INTO expired_ids FROM expired_reservations;

  expired_count := COALESCE(array_length(expired_ids, 1), 0);

  -- Free up tables for expired reservations
  UPDATE public.restaurant_tables
  SET status = 'available',
      current_customer_name = NULL,
      current_order_id = NULL,
      current_order_total = 0,
      occupied_since = NULL,
      session_id = NULL,
      updated_at = NOW()
  WHERE business_id = p_business_id
    AND id IN (
      SELECT table_id FROM public.table_reservations
      WHERE id = ANY(expired_ids)
    );

  -- Clear seats for expired reservations
  UPDATE public.table_seats
  SET status = 'available',
      session_id = NULL,
      customer_name = NULL,
      occupied_since = NULL,
      updated_at = NOW()
  WHERE business_id = p_business_id
    AND table_id IN (
      SELECT table_id FROM public.table_reservations
      WHERE id = ANY(expired_ids)
    );

  RETURN jsonb_build_object(
    'expired_count', expired_count,
    'expired_ids', expired_ids
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.fn_expire_stale_reservations(TEXT)
TO anon, authenticated;


-- Function: Update table statuses based on reservation slots and time windows
CREATE OR REPLACE FUNCTION public.fn_update_table_statuses_for_slots(p_business_id TEXT)
RETURNS VOID AS $$
BEGIN
  -- Mark tables as 'reserved' if they have upcoming reservations within 30 minutes
  UPDATE public.restaurant_tables
  SET status = 'reserved', updated_at = NOW()
  WHERE business_id = p_business_id
    AND status = 'available'
    AND id IN (
      SELECT DISTINCT table_id
      FROM public.table_reservations
      WHERE business_id = p_business_id
        AND status = 'active'
        AND reserved_for BETWEEN NOW() AND NOW() + INTERVAL '30 minutes'
    );

  -- Mark tables as 'available' if their reservation window has passed and no active reservation
  UPDATE public.restaurant_tables
  SET status = 'available', updated_at = NOW()
  WHERE business_id = p_business_id
    AND status = 'reserved'
    AND id NOT IN (
      SELECT DISTINCT table_id
      FROM public.table_reservations
      WHERE business_id = p_business_id
        AND status = 'active'
        AND reserved_for BETWEEN NOW() AND NOW() + INTERVAL '30 minutes'
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.fn_update_table_statuses_for_slots(TEXT)
TO anon, authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- MISSING FUNCTIONS FOR SEAT MANAGEMENT
-- ────────────────────────────────────────────────────────────────────────────

-- Function: Clear individual seat
CREATE OR REPLACE FUNCTION public.fn_clear_seat(
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
  FROM public.table_seats
  WHERE id = p_seat_id;

  -- Complete all pending orders for this seat
  UPDATE public.orders
  SET status = 'completed',
      payment_status = 'paid',
      completed_at = NOW(),
      updated_at = NOW()
  WHERE table_seat_id = p_seat_id
    AND status IN ('pending','preparing','ready');

  GET DIAGNOSTICS v_completed_orders = ROW_COUNT;

  -- Mark seat as available
  UPDATE public.table_seats
  SET status = 'available',
      session_id = NULL,
      customer_name = NULL,
      occupied_since = NULL,
      updated_at = NOW()
  WHERE id = p_seat_id;

  -- Update session history to checked-out if exists
  UPDATE public.seat_session_history
  SET status = 'checked-out',
      check_out_time = NOW(),
      duration_seconds = EXTRACT(EPOCH FROM (NOW() - check_in_time))::INT,
      updated_at = NOW()
  WHERE session_id = v_session_id AND status = 'active';

  -- Check remaining occupied seats
  SELECT COUNT(*) INTO v_remaining_occupied
  FROM public.table_seats
  WHERE table_id = p_table_id AND status = 'occupied';

  -- Update table status based on remaining seats
  IF v_remaining_occupied = 0 THEN
    UPDATE public.restaurant_tables
    SET status = 'available',
        current_customer_name = NULL,
        current_order_id = NULL,
        current_order_total = 0,
        occupied_since = NULL,
        session_id = NULL,
        updated_at = NOW()
    WHERE id = p_table_id;

    v_new_table_status := 'available';
  ELSE
    UPDATE public.restaurant_tables
    SET updated_at = NOW()
    WHERE id = p_table_id;

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

GRANT EXECUTE ON FUNCTION public.fn_clear_seat(TEXT, UUID) TO anon, authenticated;


-- Function: Get total bill for a seat
CREATE OR REPLACE FUNCTION public.fn_get_seat_bill(p_seat_id UUID)
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
                 THEN COALESCE(o.tax_amount, 0) ELSE 0 END), 0)::DECIMAL,
    COALESCE(SUM(CASE WHEN o.status IN ('pending','preparing','ready','completed')
                 THEN COALESCE(o.discount, 0) ELSE 0 END), 0)::DECIMAL,
    COUNT(CASE WHEN o.status IN ('pending','preparing','ready') THEN 1 END)::INT,
    COUNT(CASE WHEN o.status = 'completed' THEN 1 END)::INT
  FROM public.orders o
  WHERE o.table_seat_id = p_seat_id;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.fn_get_seat_bill(UUID) TO anon, authenticated;


-- Function: Get seat duration
CREATE OR REPLACE FUNCTION public.fn_get_seat_duration(p_seat_id UUID)
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
  FROM public.table_seats ts
  WHERE ts.id = p_seat_id;
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.fn_get_seat_duration(UUID) TO anon, authenticated;


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
