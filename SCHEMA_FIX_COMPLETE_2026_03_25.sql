-- ═════════════════════════════════════════════════════════════
-- 🔥 FINAL CLEAN PRODUCTION SCHEMA (POSTGREST SAFE)
-- ═════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═════════════════════════════════════════════════════════════
-- 1. DROP DEPENDENCIES (SAFE)
-- ═════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;
DROP VIEW IF EXISTS public.vw_table_live_dashboard CASCADE;

-- Drop ALL old versions of functions
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS func
    FROM pg_proc
    WHERE proname IN (
      'fn_clear_seat',
      'fn_checkout_v2',
      'fn_seat_guest_v2',
      'fn_table_orders_v2',
      'fn_get_seat_bill',
      'fn_get_seat_duration',
      'fn_expire_stale_reservations'
    )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func || ' CASCADE';
  END LOOP;
END $$;

-- ═════════════════════════════════════════════════════════════
-- 2. FIX COLUMN TYPES (CONSISTENT TEXT FK)
-- ═════════════════════════════════════════════════════════════

ALTER TABLE public.restaurant_tables
ALTER COLUMN id TYPE TEXT USING id::TEXT;

ALTER TABLE public.table_seats
ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

ALTER TABLE public.table_reservations
ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

ALTER TABLE public.orders
ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

-- ═════════════════════════════════════════════════════════════
-- 3. CLEAN INVALID DATA
-- ═════════════════════════════════════════════════════════════

DELETE FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1 FROM public.restaurant_tables rt WHERE rt.id = o.table_id
);

DELETE FROM public.table_reservations tr
WHERE NOT EXISTS (
  SELECT 1 FROM public.restaurant_tables rt WHERE rt.id = tr.table_id
);

DELETE FROM public.table_seats ts
WHERE NOT EXISTS (
  SELECT 1 FROM public.restaurant_tables rt WHERE rt.id = ts.table_id
);

-- ═════════════════════════════════════════════════════════════
-- 4. RECREATE FK
-- ═════════════════════════════════════════════════════════════

-- ═════════════════════════════════════════════════════════════
-- 4. RECREATE FK (SAFE - NO DUPLICATES EVER)
-- ═════════════════════════════════════════════════════════════

DO $$
BEGIN
  -- table_seats FK
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'table_seats_table_id_fkey'
  ) THEN
    ALTER TABLE public.table_seats
    DROP CONSTRAINT table_seats_table_id_fkey;
  END IF;

  ALTER TABLE public.table_seats
  ADD CONSTRAINT table_seats_table_id_fkey
  FOREIGN KEY (table_id)
  REFERENCES public.restaurant_tables(id)
  ON DELETE CASCADE;

  -- table_reservations FK
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'table_reservations_table_id_fkey'
  ) THEN
    ALTER TABLE public.table_reservations
    DROP CONSTRAINT table_reservations_table_id_fkey;
  END IF;

  ALTER TABLE public.table_reservations
  ADD CONSTRAINT table_reservations_table_id_fkey
  FOREIGN KEY (table_id)
  REFERENCES public.restaurant_tables(id)
  ON DELETE CASCADE;

  -- orders FK
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'orders_table_id_fkey'
  ) THEN
    ALTER TABLE public.orders
    DROP CONSTRAINT orders_table_id_fkey;
  END IF;

  ALTER TABLE public.orders
  ADD CONSTRAINT orders_table_id_fkey
  FOREIGN KEY (table_id)
  REFERENCES public.restaurant_tables(id)
  ON DELETE CASCADE;

END $$;
-- ═════════════════════════════════════════════════════════════
-- 5. PATCH TABLES
-- ═════════════════════════════════════════════════════════════

ALTER TABLE public.restaurant_tables
ADD COLUMN IF NOT EXISTS current_customer_name TEXT,
ADD COLUMN IF NOT EXISTS session_id UUID,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.table_reservations
ADD COLUMN IF NOT EXISTS actual_check_out TIMESTAMPTZ;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS table_seat_id UUID,
ADD COLUMN IF NOT EXISTS total_amount NUMERIC,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC;

-- ═════════════════════════════════════════════════════════════
-- 6. TABLE: table_seats
-- ═════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.table_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id TEXT,
  seat_label TEXT,
  status TEXT DEFAULT 'available'
    CHECK (status IN ('available','occupied')),
  session_id UUID,
  customer_name TEXT,
  occupied_since TIMESTAMPTZ,
  business_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(table_id, seat_label)
);

-- ═════════════════════════════════════════════════════════════
-- 7. VIEWS
-- ═════════════════════════════════════════════════════════════

CREATE VIEW public.vw_orders_with_items AS
SELECT
  o.*,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', oi.id,
        'item_name', oi.item_name,
        'quantity', oi.quantity,
        'subtotal', oi.subtotal
      ) ORDER BY oi.created_at
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'::jsonb
  ) AS items
FROM public.orders o
LEFT JOIN public.order_items oi ON oi.order_id = o.id
GROUP BY o.id;

CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.*,
  tr.id AS reservation_id,
  tr.customer_name,
  tr.status AS reservation_status
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr
  ON tr.table_id = rt.id;

CREATE VIEW public.vw_table_live_dashboard AS
SELECT
  rt.id,
  rt.table_number,
  rt.status,
  COUNT(ts.id) AS total_seats,
  COUNT(CASE WHEN ts.status='occupied' THEN 1 END) AS occupied_seats,
  COALESCE(SUM(o.total_amount),0) AS running_bill
FROM public.restaurant_tables rt
LEFT JOIN public.table_seats ts ON ts.table_id = rt.id
LEFT JOIN public.orders o ON o.table_id = rt.id
GROUP BY rt.id;

-- ═════════════════════════════════════════════════════════════
-- 8. FUNCTIONS (POSTGREST SAFE)
-- ═════════════════════════════════════════════════════════════

-- ✅ Orders (FIXED BIGINT)
CREATE FUNCTION public.fn_table_orders_v2(p_table_id TEXT)
RETURNS TABLE (
  id UUID,
  business_id TEXT,
  table_id TEXT,
  table_seat_id UUID,
  order_number BIGINT,
  status TEXT,
  payment_status TEXT,
  subtotal NUMERIC,
  tax NUMERIC,
  discount NUMERIC,
  discount_code TEXT,
  total NUMERIC,
  session_id TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by_uid TEXT,
  created_by_name TEXT,
  payment_method TEXT,
  notes TEXT,
  reference_id TEXT,
  is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
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
    COALESCE(o.tax_amount,0),
    COALESCE(o.discount,0),
    o.discount_code,
    COALESCE(o.total_amount,0),
    o.session_id::TEXT,
    o.created_at,
    o.updated_at,
    o.created_by_uid,
    o.created_by_name,
    o.payment_method,
    o.notes,
    o.reference_id,
    TRUE
  FROM public.orders o
  WHERE o.table_id = p_table_id;
END;
$$;

-- ✅ Checkout (FIXED SIGNATURE)
CREATE FUNCTION public.fn_checkout_v2(p_table_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.orders SET status='completed' WHERE table_id=p_table_id;

  UPDATE public.table_seats
  SET status='available',
      session_id=NULL,
      customer_name=NULL,
      occupied_since=NULL
  WHERE table_id=p_table_id;

  UPDATE public.restaurant_tables
  SET status='available',
      session_id=NULL,
      current_customer_name=NULL
  WHERE id=p_table_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ✅ Expire reservations (FIXED PARAM NAME)
CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE v_count INT;
BEGIN
  UPDATE public.table_reservations
  SET status='expired',
      updated_at=NOW()
  WHERE business_id=p_business_id
    AND status='active'
    AND check_in IS NULL
    AND reserved_for < (NOW() - INTERVAL '15 minutes');

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('expired_count', v_count, 'success', true);
END;
$$;

-- ═════════════════════════════════════════════════════════════
-- 9. TRIGGER (SEATS AUTO-GENERATION)
-- ═════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS trg_generate_seats ON public.restaurant_tables;
DROP FUNCTION IF EXISTS public.fn_generate_table_seats();

CREATE FUNCTION public.fn_generate_table_seats()
RETURNS TRIGGER AS $$
DECLARE i INT;
BEGIN
  DELETE FROM public.table_seats WHERE table_id=NEW.id;

  FOR i IN 1..NEW.capacity LOOP
    INSERT INTO public.table_seats(table_id, seat_label, business_id)
    VALUES (NEW.id, chr(64+i), NEW.business_id)
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_seats
AFTER INSERT OR UPDATE OF capacity ON public.restaurant_tables
FOR EACH ROW EXECUTE FUNCTION public.fn_generate_table_seats();

-- ═════════════════════════════════════════════════════════════
-- 🔥 FINAL STEP (CRITICAL FOR POSTGREST)
-- ═════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';


-- -- ═════════════════════════════════════════════════════════════
-- -- 🔥 FINAL PRODUCTION SCHEMA (FULLY FIXED + COMPLETE)
-- -- ═════════════════════════════════════════════════════════════

-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -- ═════════════════════════════════════════════════════════════
-- -- 0. DROP VIEWS
-- -- ═════════════════════════════════════════════════════════════
-- DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;
-- DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;
-- DROP VIEW IF EXISTS public.vw_table_live_dashboard CASCADE;

-- -- ═════════════════════════════════════════════════════════════
-- -- 1. DROP FK CONSTRAINTS
-- -- ═════════════════════════════════════════════════════════════
-- ALTER TABLE IF EXISTS public.table_seats DROP CONSTRAINT IF EXISTS table_seats_table_id_fkey;
-- ALTER TABLE IF EXISTS public.table_reservations DROP CONSTRAINT IF EXISTS table_reservations_table_id_fkey;
-- ALTER TABLE IF EXISTS public.orders DROP CONSTRAINT IF EXISTS orders_table_id_fkey;

-- -- ═════════════════════════════════════════════════════════════
-- -- 2. FIX COLUMN TYPES
-- -- ═════════════════════════════════════════════════════════════
-- ALTER TABLE public.restaurant_tables
-- ALTER COLUMN id TYPE TEXT USING id::TEXT;

-- ALTER TABLE public.table_seats
-- ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

-- ALTER TABLE public.table_reservations
-- ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

-- ALTER TABLE public.orders
-- ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;

-- -- ═════════════════════════════════════════════════════════════
-- -- 3. DATA CLEANUP
-- -- ═════════════════════════════════════════════════════════════
-- DELETE FROM public.orders o
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.restaurant_tables rt
--   WHERE rt.id = o.table_id
-- );

-- DELETE FROM public.table_reservations tr
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.restaurant_tables rt
--   WHERE rt.id = tr.table_id
-- );

-- DELETE FROM public.table_seats ts
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.restaurant_tables rt
--   WHERE rt.id = ts.table_id
-- );

-- -- ═════════════════════════════════════════════════════════════
-- -- 4. RECREATE FK
-- -- ═════════════════════════════════════════════════════════════
-- ALTER TABLE public.table_seats
-- ADD CONSTRAINT table_seats_table_id_fkey
-- FOREIGN KEY (table_id)
-- REFERENCES public.restaurant_tables(id)
-- ON DELETE CASCADE;

-- ALTER TABLE public.table_reservations
-- ADD CONSTRAINT table_reservations_table_id_fkey
-- FOREIGN KEY (table_id)
-- REFERENCES public.restaurant_tables(id)
-- ON DELETE CASCADE;

-- ALTER TABLE public.orders
-- ADD CONSTRAINT orders_table_id_fkey
-- FOREIGN KEY (table_id)
-- REFERENCES public.restaurant_tables(id)
-- ON DELETE CASCADE;

-- -- ═════════════════════════════════════════════════════════════
-- -- 5. PATCH TABLES
-- -- ═════════════════════════════════════════════════════════════
-- ALTER TABLE public.restaurant_tables
-- ADD COLUMN IF NOT EXISTS current_customer_name TEXT,
-- ADD COLUMN IF NOT EXISTS session_id UUID,
-- ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ALTER TABLE public.table_reservations
-- ADD COLUMN IF NOT EXISTS actual_check_out TIMESTAMPTZ;

-- ALTER TABLE public.orders
-- ADD COLUMN IF NOT EXISTS table_seat_id UUID,
-- ADD COLUMN IF NOT EXISTS total_amount NUMERIC,
-- ADD COLUMN IF NOT EXISTS tax_amount NUMERIC;

-- -- ═════════════════════════════════════════════════════════════
-- -- 6. TABLE: table_seats
-- -- ═════════════════════════════════════════════════════════════
-- CREATE TABLE IF NOT EXISTS public.table_seats (
--   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   table_id TEXT,
--   seat_label TEXT,
--   status TEXT DEFAULT 'available'
--     CHECK (status IN ('available','occupied')),
--   session_id UUID,
--   customer_name TEXT,
--   occupied_since TIMESTAMPTZ,
--   business_id TEXT,
--   created_at TIMESTAMPTZ DEFAULT NOW(),
--   updated_at TIMESTAMPTZ DEFAULT NOW(),
--   UNIQUE(table_id, seat_label)
-- );

-- -- ═════════════════════════════════════════════════════════════
-- -- 7. VIEWS
-- -- ═════════════════════════════════════════════════════════════

-- -- Orders + items
-- CREATE VIEW public.vw_orders_with_items AS
-- SELECT
--   o.id,
--   o.business_id,
--   o.table_id,
--   o.table_seat_id,
--   o.order_number,
--   o.status,
--   o.payment_status,
--   COALESCE(o.subtotal, 0) AS subtotal,
--   COALESCE(o.tax_amount, 0) AS tax,
--   COALESCE(o.discount, 0) AS discount,
--   COALESCE(o.total_amount, 0) AS total,
--   o.session_id,
--   o.created_at,
--   o.updated_at,
--   o.created_by_uid,
--   o.created_by_name,
--   o.payment_method,
--   o.notes,
--   o.reference_id,
--   TRUE AS is_active,
--   COALESCE(
--     jsonb_agg(
--       jsonb_build_object(
--         'id', oi.id,
--         'item_name', oi.item_name,
--         'quantity', oi.quantity,
--         'subtotal', oi.subtotal
--       ) ORDER BY oi.created_at
--     ) FILTER (WHERE oi.id IS NOT NULL),
--     '[]'::jsonb
--   ) AS items
-- FROM public.orders o
-- LEFT JOIN public.order_items oi ON oi.order_id = o.id
-- GROUP BY 
--   o.id, o.business_id, o.table_id, o.table_seat_id,
--   o.order_number, o.status, o.payment_status,
--   o.subtotal, o.tax_amount, o.discount, o.total_amount,
--   o.session_id, o.created_at, o.updated_at,
--   o.created_by_uid, o.created_by_name,
--   o.payment_method, o.notes, o.reference_id;

-- -- Tables + reservation
-- CREATE VIEW public.vw_tables_with_reservation AS
-- SELECT
--   rt.*,
--   CASE WHEN tr.id IS NOT NULL THEN jsonb_build_object(
--     'id', tr.id,
--     'customer_name', tr.customer_name,
--     'phone', tr.phone,
--     'guest_count', tr.guest_count,
--     'reserved_for', tr.reserved_for,
--     'check_in', tr.check_in,
--     'check_out', tr.check_out,
--     'actual_check_out', tr.actual_check_out,
--     'status', tr.status
--   ) ELSE NULL END AS reservation_data
-- FROM public.restaurant_tables rt
-- LEFT JOIN public.table_reservations tr 
--   ON tr.table_id = rt.id;

-- -- Live dashboard
-- CREATE VIEW public.vw_table_live_dashboard AS
-- SELECT
--   rt.id,
--   rt.table_number,
--   rt.status,
--   COUNT(ts.id) AS total_seats,
--   COUNT(CASE WHEN ts.status='occupied' THEN 1 END) AS occupied_seats,
--   COALESCE(
--     SUM(o.total_amount)
--     FILTER (WHERE o.status IN ('pending','preparing','ready')),
--     0
--   ) AS running_bill
-- FROM public.restaurant_tables rt
-- LEFT JOIN public.table_seats ts ON ts.table_id = rt.id
-- LEFT JOIN public.orders o ON o.table_id = rt.id
-- GROUP BY rt.id, rt.table_number, rt.status;

-- -- ═════════════════════════════════════════════════════════════
-- -- 8. FUNCTIONS
-- -- ═════════════════════════════════════════════════════════════

-- CREATE OR REPLACE FUNCTION public.fn_table_orders_v2(p_table_id TEXT)
-- RETURNS TABLE (
--   id UUID, business_id TEXT, table_id TEXT, table_seat_id UUID,
--   order_number INT, status TEXT, payment_status TEXT,
--   subtotal NUMERIC, tax NUMERIC, discount NUMERIC,
--   discount_code TEXT, total NUMERIC, session_id TEXT,
--   created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
--   created_by_uid TEXT, created_by_name TEXT,
--   payment_method TEXT, notes TEXT, reference_id TEXT,
--   is_active BOOLEAN
-- ) AS $$
-- BEGIN
--   RETURN QUERY
--   SELECT
--     o.id, o.business_id, o.table_id, o.table_seat_id,
--     o.order_number, o.status, o.payment_status,
--     o.subtotal, COALESCE(o.tax_amount, 0),
--     COALESCE(o.discount, 0), o.discount_code,
--     COALESCE(o.total_amount, 0),
--     o.session_id::TEXT,
--     o.created_at, o.updated_at,
--     o.created_by_uid, o.created_by_name,
--     o.payment_method, o.notes, o.reference_id,
--     TRUE
--   FROM public.orders o
--   WHERE o.table_id = p_table_id
--     AND o.status IN ('pending','preparing','ready')
--   ORDER BY o.created_at DESC;
-- END;
-- $$ LANGUAGE plpgsql;


-- -- 🔥 DROP FUNCTIONS (MANDATORY BEFORE RECREATE)

-- DROP FUNCTION IF EXISTS public.fn_clear_seat(TEXT, UUID) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_checkout_v2(TEXT, UUID) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_seat_guest_v2(TEXT, UUID, TEXT, UUID) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_table_orders_v2(TEXT) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_get_seat_bill(UUID) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_get_seat_duration(UUID) CASCADE;
-- DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(TEXT) CASCADE;

-- CREATE OR REPLACE FUNCTION public.fn_clear_seat(TEXT, UUID)
-- RETURNS JSONB AS $$
-- BEGIN
--   UPDATE public.orders SET status='completed' WHERE table_seat_id=$2;

--   UPDATE public.table_seats
--   SET status='available', session_id=NULL,
--       customer_name=NULL, occupied_since=NULL,
--       updated_at=NOW()
--   WHERE id=$2;

--   RETURN jsonb_build_object('success', true);
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION public.fn_checkout_v2(TEXT, UUID DEFAULT NULL)
-- RETURNS JSONB AS $$
-- BEGIN
--   IF $2 IS NOT NULL THEN
--     RETURN fn_clear_seat($1,$2);
--   END IF;

--   UPDATE public.orders SET status='completed' WHERE table_id=$1;

--   UPDATE public.table_seats
--   SET status='available', session_id=NULL,
--       customer_name=NULL, occupied_since=NULL,
--       updated_at=NOW()
--   WHERE table_id=$1;

--   UPDATE public.restaurant_tables
--   SET status='available', session_id=NULL,
--       current_customer_name=NULL, updated_at=NOW()
--   WHERE id=$1;

--   RETURN jsonb_build_object('success', true);
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION public.fn_seat_guest_v2(TEXT,UUID,TEXT,UUID)
-- RETURNS JSONB AS $$
-- BEGIN
--   UPDATE public.table_seats
--   SET status='occupied', customer_name=$3,
--       session_id=$4, occupied_since=NOW(), updated_at=NOW()
--   WHERE id=$2;

--   UPDATE public.restaurant_tables
--   SET status='occupied', current_customer_name=$3,
--       session_id=$4, updated_at=NOW()
--   WHERE id=$1;

--   RETURN jsonb_build_object('success', true);
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION public.fn_get_seat_bill(UUID)
-- RETURNS JSONB AS $$
-- BEGIN
--   RETURN (
--     SELECT jsonb_build_object(
--       'subtotal', COALESCE(SUM(subtotal),0),
--       'tax', COALESCE(SUM(tax_amount),0),
--       'discount', COALESCE(SUM(discount),0),
--       'total', COALESCE(SUM(total_amount),0),
--       'order_count', COUNT(*)
--     )
--     FROM public.orders
--     WHERE table_seat_id=$1
--       AND status IN ('pending','preparing','ready')
--   );
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION public.fn_get_seat_duration(UUID)
-- RETURNS JSONB AS $$
-- DECLARE v TIMESTAMPTZ;
-- BEGIN
--   SELECT occupied_since INTO v
--   FROM public.table_seats
--   WHERE id=$1 AND status='occupied';

--   IF v IS NULL THEN
--     RETURN jsonb_build_object('duration_minutes',0,'is_occupied',false);
--   END IF;

--   RETURN jsonb_build_object(
--     'duration_minutes', FLOOR(EXTRACT(EPOCH FROM (NOW()-v))/60),
--     'is_occupied', true,
--     'occupied_since', v
--   );
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION public.fn_expire_stale_reservations(TEXT)
-- RETURNS JSONB AS $$
-- DECLARE v_now TIMESTAMPTZ:=NOW(); v_count INT:=0; v_row RECORD;
-- BEGIN
--   FOR v_row IN (
--     SELECT id FROM public.table_reservations
--     WHERE business_id=$1 AND status='active'
--       AND check_in IS NULL
--       AND reserved_for < (v_now - INTERVAL '15 minutes')
--     LIMIT 100
--   )
--   LOOP
--     UPDATE public.table_reservations
--     SET status='expired', updated_at=v_now
--     WHERE id=v_row.id;

--     v_count:=v_count+1;
--   END LOOP;

--   RETURN jsonb_build_object('expired_count',v_count,'success',true);
-- END;
-- $$ LANGUAGE plpgsql;

-- -- ═════════════════════════════════════════════════════════════
-- -- 9. TRIGGER
-- -- ═════════════════════════════════════════════════════════════

-- DROP TRIGGER IF EXISTS trg_generate_seats ON public.restaurant_tables;
-- DROP FUNCTION IF EXISTS public.fn_generate_table_seats();

-- CREATE FUNCTION public.fn_generate_table_seats()
-- RETURNS TRIGGER AS $$
-- DECLARE i INT;
-- BEGIN
--   DELETE FROM public.table_seats WHERE table_id=NEW.id;

--   FOR i IN 1..NEW.capacity LOOP
--     INSERT INTO public.table_seats(table_id, seat_label, business_id)
--     VALUES (NEW.id, chr(64+i), NEW.business_id)
--     ON CONFLICT DO NOTHING;
--   END LOOP;

--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER trg_generate_seats
-- AFTER INSERT OR UPDATE OF capacity ON public.restaurant_tables
-- FOR EACH ROW EXECUTE FUNCTION public.fn_generate_table_seats();

-- -- ═════════════════════════════════════════════════════════════
-- -- FINAL
-- -- ═════════════════════════════════════════════════════════════
-- NOTIFY pgrst, 'reload schema';