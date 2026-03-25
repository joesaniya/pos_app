-- ═════════════════════════════════════════════════════════════
-- 🔥 FINAL PRODUCTION SCHEMA (ZERO ERRORS + POSTGREST SAFE)
-- ═════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═════════════════════════════════════════════════════════════
-- 1. DROP VIEWS
-- ═════════════════════════════════════════════════════════════
DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;
DROP VIEW IF EXISTS public.vw_table_live_dashboard CASCADE;

-- ═════════════════════════════════════════════════════════════
-- 2. DROP ALL FUNCTIONS SAFELY
-- ═════════════════════════════════════════════════════════════
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS func
    FROM pg_proc
    WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public')
      AND proname LIKE 'fn_%'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func || ' CASCADE';
  END LOOP;
END $$;

-- ═════════════════════════════════════════════════════════════
-- 3. SAFE COLUMN TYPE FIX
-- ═════════════════════════════════════════════════════════════

DO $$ BEGIN
IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='restaurant_tables' AND column_name='id' AND data_type <> 'text') THEN
  ALTER TABLE public.restaurant_tables ALTER COLUMN id TYPE TEXT USING id::TEXT;
END IF;
END $$;

DO $$ BEGIN
IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='table_seats' AND column_name='table_id' AND data_type <> 'text') THEN
  ALTER TABLE public.table_seats ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;
END IF;
END $$;

DO $$ BEGIN
IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='table_id' AND data_type <> 'text') THEN
  ALTER TABLE public.orders ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;
END IF;
END $$;

DO $$ BEGIN
IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='table_reservations' AND column_name='table_id' AND data_type <> 'text') THEN
  ALTER TABLE public.table_reservations ALTER COLUMN table_id TYPE TEXT USING table_id::TEXT;
END IF;
END $$;

-- ═════════════════════════════════════════════════════════════
-- 4. CLEAN INVALID DATA
-- ═════════════════════════════════════════════════════════════

DELETE FROM public.orders o
WHERE NOT EXISTS (SELECT 1 FROM public.restaurant_tables rt WHERE rt.id=o.table_id);

DELETE FROM public.table_seats ts
WHERE NOT EXISTS (SELECT 1 FROM public.restaurant_tables rt WHERE rt.id=ts.table_id);

DELETE FROM public.table_reservations tr
WHERE NOT EXISTS (SELECT 1 FROM public.restaurant_tables rt WHERE rt.id=tr.table_id);

-- ═════════════════════════════════════════════════════════════
-- 5. SAFE FK CREATION
-- ═════════════════════════════════════════════════════════════

DO $$
BEGIN
  -- table_seats
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='table_seats_table_id_fkey' AND table_schema='public'
  ) THEN
    ALTER TABLE public.table_seats DROP CONSTRAINT table_seats_table_id_fkey;
  END IF;

  ALTER TABLE public.table_seats
  ADD CONSTRAINT table_seats_table_id_fkey
  FOREIGN KEY (table_id) REFERENCES public.restaurant_tables(id) ON DELETE CASCADE;

  -- reservations
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='table_reservations_table_id_fkey' AND table_schema='public'
  ) THEN
    ALTER TABLE public.table_reservations DROP CONSTRAINT table_reservations_table_id_fkey;
  END IF;

  ALTER TABLE public.table_reservations
  ADD CONSTRAINT table_reservations_table_id_fkey
  FOREIGN KEY (table_id) REFERENCES public.restaurant_tables(id) ON DELETE CASCADE;

  -- orders
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name='orders_table_id_fkey' AND table_schema='public'
  ) THEN
    ALTER TABLE public.orders DROP CONSTRAINT orders_table_id_fkey;
  END IF;

  ALTER TABLE public.orders
  ADD CONSTRAINT orders_table_id_fkey
  FOREIGN KEY (table_id) REFERENCES public.restaurant_tables(id) ON DELETE CASCADE;

END $$;

-- ═════════════════════════════════════════════════════════════
-- 6. PATCH TABLES
-- ═════════════════════════════════════════════════════════════

ALTER TABLE public.restaurant_tables
ADD COLUMN IF NOT EXISTS current_customer_name TEXT,
ADD COLUMN IF NOT EXISTS session_id UUID,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS table_seat_id UUID,
ADD COLUMN IF NOT EXISTS total_amount NUMERIC,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC;

ALTER TABLE public.table_reservations
ADD COLUMN IF NOT EXISTS actual_check_out TIMESTAMPTZ;

-- ═════════════════════════════════════════════════════════════
-- 7. TABLE: table_seats
-- ═════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.table_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id TEXT,
  seat_label TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','occupied')),
  session_id UUID,
  customer_name TEXT,
  occupied_since TIMESTAMPTZ,
  business_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(table_id, seat_label)
);

-- ═════════════════════════════════════════════════════════════
-- 8. FUNCTIONS (FINAL FIXED)
-- ═════════════════════════════════════════════════════════════

-- Orders
CREATE FUNCTION public.fn_table_orders_v2(p_table_id TEXT)
RETURNS TABLE (
  id UUID, business_id TEXT, table_id TEXT, table_seat_id UUID,
  order_number BIGINT, status TEXT, payment_status TEXT,
  subtotal NUMERIC, tax NUMERIC, discount NUMERIC,
  discount_code TEXT, total NUMERIC, session_id TEXT,
  created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  created_by_uid TEXT, created_by_name TEXT,
  payment_method TEXT, notes TEXT, reference_id TEXT,
  is_active BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY SELECT
    o.id,o.business_id,o.table_id,o.table_seat_id,o.order_number,
    o.status,o.payment_status,o.subtotal,
    COALESCE(o.tax_amount,0),COALESCE(o.discount,0),
    o.discount_code,COALESCE(o.total_amount,0),
    o.session_id::TEXT,o.created_at,o.updated_at,
    o.created_by_uid,o.created_by_name,
    o.payment_method,o.notes,o.reference_id,TRUE
  FROM public.orders o
  WHERE o.table_id=p_table_id;
END;
$$;

-- Seat Guest (CRITICAL FIX)
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
DECLARE v_session_id UUID := uuid_generate_v4();
BEGIN
  UPDATE public.table_seats
  SET status='occupied',
      customer_name=p_customer_name,
      session_id=v_session_id,
      occupied_since=NOW()
  WHERE id = ANY(p_seat_ids);

  UPDATE public.restaurant_tables
  SET status='occupied',
      current_customer_name=p_customer_name,
      session_id=v_session_id
  WHERE id=p_table_id;

  RETURN jsonb_build_object('success',true,'session_id',v_session_id);
END;
$$;

-- Checkout
CREATE FUNCTION public.fn_checkout_v2(p_table_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.orders SET status='completed' WHERE table_id=p_table_id;

  UPDATE public.table_seats
  SET status='available',session_id=NULL,customer_name=NULL,occupied_since=NULL
  WHERE table_id=p_table_id;

  UPDATE public.restaurant_tables
  SET status='available',session_id=NULL,current_customer_name=NULL
  WHERE id=p_table_id;

  RETURN jsonb_build_object('success',true);
END;
$$;

-- Expire reservations
CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE v_count INT;
BEGIN
  UPDATE public.table_reservations
  SET status='expired',updated_at=NOW()
  WHERE business_id=p_business_id
    AND status='active'
    AND check_in IS NULL
    AND reserved_for < NOW()-INTERVAL '15 min';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('expired_count',v_count,'success',true);
END;
$$;

-- ═════════════════════════════════════════════════════════════
-- 9. TRIGGER
-- ═════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS trg_generate_seats ON public.restaurant_tables;
DROP FUNCTION IF EXISTS public.fn_generate_table_seats();

CREATE FUNCTION public.fn_generate_table_seats()
RETURNS TRIGGER AS $$
DECLARE i INT;
BEGIN
  DELETE FROM public.table_seats WHERE table_id=NEW.id;

  FOR i IN 1..NEW.capacity LOOP
    INSERT INTO public.table_seats(table_id,seat_label,business_id)
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
-- 🔥 FINAL STEP
-- ═════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';




DROP VIEW IF EXISTS public.vw_tables_with_reservation;

CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.*,
  tr.id AS reservation_id,
  tr.customer_name,
  tr.phone,
  tr.guest_count,
  tr.reserved_for,
  tr.check_in,
  tr.check_out,
  tr.actual_check_out, -- ✅ CORRECT TABLE
  tr.status AS reservation_status
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr
  ON tr.table_id = rt.id; 
  GRANT SELECT ON public.vw_tables_with_reservation TO anon, authenticated;
  NOTIFY pgrst, 'reload schema';
-- ═════════════════════════════════════════════════════════════
-- 🔥 FINAL STEP
-- ═════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';

-- 1. Drop existing function (IMPORTANT)
DROP FUNCTION IF EXISTS public.fn_clear_seat(TEXT, UUID);

-- 2. Recreate with proper parameter names
CREATE FUNCTION public.fn_clear_seat(
  p_table_id TEXT,
  p_seat_id UUID
)
RETURNS JSONB AS $$
BEGIN
  -- Complete all orders for that seat
  UPDATE public.orders
  SET status = 'completed'
  WHERE table_seat_id = p_seat_id;

  -- Clear seat state
  UPDATE public.table_seats
  SET status = 'available',
      session_id = NULL,
      customer_name = NULL,
      occupied_since = NULL,
      updated_at = NOW()
  WHERE id = p_seat_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;

-- 3. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';