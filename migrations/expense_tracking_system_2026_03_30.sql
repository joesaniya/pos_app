-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPENSE TRACKING SYSTEM — Complete Migration
-- Date: 2026-03-30
--
-- Core Features:
--   ✓ Business-based expense tracking (Business ID isolation)
--   ✓ Global expense categories (shared across all businesses)
--   ✓ Payment transaction tracking
--   ✓ Bill upload & auto-expense creation
--   ✓ Complete audit trail
--   ✓ RLS disabled for app-level security
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 0: DROP EXISTING OBJECTS (clean slate)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_expense_dashboard    CASCADE;
DROP VIEW IF EXISTS public.vw_expenses_by_category CASCADE;
DROP VIEW IF EXISTS public.vw_expense_summary      CASCADE;

DROP TABLE IF EXISTS public.expense_bills      CASCADE;
DROP TABLE IF EXISTS public.expense_payments   CASCADE;
DROP TABLE IF EXISTS public.expenses           CASCADE;
DROP TABLE IF EXISTS public.expense_categories CASCADE;

DROP FUNCTION IF EXISTS fn_create_default_expense_categories()                                                     CASCADE;
DROP FUNCTION IF EXISTS fn_create_default_expense_categories(TEXT)                                                 CASCADE;
DROP FUNCTION IF EXISTS fn_create_expense_from_bill(TEXT,UUID,TEXT,NUMERIC,TEXT,DATE,TEXT,TEXT,TEXT,TEXT,TEXT,INT) CASCADE;
DROP FUNCTION IF EXISTS fn_record_expense_payment(UUID,NUMERIC,DATE,TEXT,TEXT,TEXT,TEXT,TEXT)                      CASCADE;
DROP FUNCTION IF EXISTS fn_get_expense_stats(TEXT)                                                                 CASCADE;
DROP FUNCTION IF EXISTS fn_get_monthly_expense_summary(TEXT)                                                       CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: EXPENSE CATEGORIES TABLE (Global — shared across all businesses)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE public.expense_categories (
  id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT          NOT NULL UNIQUE,
  icon            TEXT          DEFAULT 'receipt',
  color           TEXT          DEFAULT '#6366F1',
  description     TEXT,
  monthly_budget  NUMERIC(12,2),
  is_active       BOOLEAN       DEFAULT true,
  sort_order      INT           DEFAULT 0,
  created_at      TIMESTAMPTZ   DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX idx_expense_categories_active
  ON public.expense_categories(is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: EXPENSES TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE public.expenses (
  id                    UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id           TEXT          NOT NULL,
  expense_number        BIGSERIAL,
  title                 TEXT          NOT NULL,
  description           TEXT,

  expense_category_id   UUID          REFERENCES public.expense_categories(id) ON DELETE RESTRICT,
  category_name         TEXT          NOT NULL,

  vendor_name           TEXT          NOT NULL,
  vendor_id             UUID          REFERENCES public.suppliers(id) ON DELETE SET NULL,

  amount                NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  due_date              DATE,
  payment_date          DATE,
  expense_date          DATE          NOT NULL DEFAULT CURRENT_DATE,

  status                TEXT          NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','paid','rejected','cancelled')),

  payment_status        TEXT          NOT NULL DEFAULT 'unpaid'
    CHECK (payment_status IN ('unpaid','partial','paid')),

  paid_amount           NUMERIC(12,2) DEFAULT 0 CHECK (paid_amount >= 0),
  remaining_amount      NUMERIC(12,2) DEFAULT 0 CHECK (remaining_amount >= 0),

  invoice_number        TEXT,
  invoice_date          DATE,
  gst_amount            NUMERIC(12,2) DEFAULT 0,
  gst_number            TEXT,

  bill_file_path        TEXT,
  bill_file_name        TEXT,
  bill_file_size        INT,
  bill_uploaded_at      TIMESTAMPTZ,

  approval_status       TEXT          DEFAULT 'pending'
    CHECK (approval_status IN ('pending','approved','rejected')),
  approved_by_uid       TEXT,
  approved_by_name      TEXT,
  approved_at           TIMESTAMPTZ,
  approval_notes        TEXT,

  expense_type          TEXT          DEFAULT 'general'
    CHECK (expense_type IN ('maintenance','event','interior_work','festival','operational','utility','general')),

  notes                 TEXT,
  tags                  TEXT[],

  created_by_uid        TEXT          NOT NULL,
  created_by_name       TEXT          NOT NULL,
  created_by_role       TEXT,
  updated_by_uid        TEXT,
  updated_by_name       TEXT,
  updated_by_role       TEXT,

  created_at            TIMESTAMPTZ   DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   DEFAULT NOW(),
  is_active             BOOLEAN       DEFAULT true
);

CREATE INDEX idx_expenses_business        ON public.expenses(business_id);
CREATE INDEX idx_expenses_business_active ON public.expenses(business_id, is_active);
CREATE INDEX idx_expenses_business_date   ON public.expenses(business_id, expense_date DESC);
CREATE INDEX idx_expenses_category        ON public.expenses(expense_category_id);
CREATE INDEX idx_expenses_vendor          ON public.expenses(vendor_id);
CREATE INDEX idx_expenses_status          ON public.expenses(status);
CREATE INDEX idx_expenses_payment_status  ON public.expenses(payment_status);
CREATE INDEX idx_expenses_created_at      ON public.expenses(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: EXPENSE PAYMENTS TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE public.expense_payments (
  id                  UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id         TEXT          NOT NULL,
  expense_id          UUID          NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,

  payment_amount      NUMERIC(12,2) NOT NULL CHECK (payment_amount > 0),
  payment_date        DATE          NOT NULL DEFAULT CURRENT_DATE,

  payment_method      TEXT          NOT NULL
    CHECK (payment_method IN ('cash','bank_transfer','cheque','upi','card','credit')),

  transaction_id      TEXT,
  cheque_number       TEXT,
  bank_name           TEXT,

  payment_status      TEXT          NOT NULL DEFAULT 'completed'
    CHECK (payment_status IN ('pending','completed','failed','cancelled')),

  notes               TEXT,

  recorded_by_uid     TEXT          NOT NULL,
  recorded_by_name    TEXT          NOT NULL,
  recorded_by_role    TEXT,

  created_at          TIMESTAMPTZ   DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX idx_expense_payments_business ON public.expense_payments(business_id);
CREATE INDEX idx_expense_payments_expense  ON public.expense_payments(expense_id);
CREATE INDEX idx_expense_payments_date     ON public.expense_payments(payment_date DESC);
CREATE INDEX idx_expense_payments_method   ON public.expense_payments(payment_method);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 4: EXPENSE BILLS TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE public.expense_bills (
  id                      UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id             TEXT          NOT NULL,

  file_path               TEXT          NOT NULL,
  file_name               TEXT          NOT NULL,
  file_size               INT           NOT NULL,
  file_type               TEXT,

  extracted_data          JSONB,

  expense_id              UUID          REFERENCES public.expenses(id) ON DELETE SET NULL,

  processing_status       TEXT          DEFAULT 'pending'
    CHECK (processing_status IN ('pending','processing','completed','failed')),

  processing_error        TEXT,
  requires_manual_review  BOOLEAN       DEFAULT false,
  reviewed_by_uid         TEXT,
  reviewed_by_name        TEXT,
  reviewed_at             TIMESTAMPTZ,

  notes                   TEXT,

  uploaded_by_uid         TEXT          NOT NULL,
  uploaded_by_name        TEXT          NOT NULL,
  uploaded_by_role        TEXT,

  created_at              TIMESTAMPTZ   DEFAULT NOW(),
  updated_at              TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX idx_expense_bills_business ON public.expense_bills(business_id);
CREATE INDEX idx_expense_bills_expense  ON public.expense_bills(expense_id);
CREATE INDEX idx_expense_bills_status   ON public.expense_bills(processing_status);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 5: EXPENSE SUMMARY VIEW
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE VIEW public.vw_expense_summary AS
SELECT
  e.business_id,
  DATE_TRUNC('month', e.expense_date)                                                  AS month,
  COALESCE(SUM(e.amount), 0)                                                           AS total_amount,
  COUNT(DISTINCT e.id)                                                                 AS expense_count,
  COUNT(CASE WHEN e.status = 'pending' THEN 1 END)                                    AS pending_count,
  COUNT(CASE WHEN e.payment_status = 'unpaid' THEN 1 END)                             AS unpaid_count,
  COALESCE(SUM(CASE WHEN e.payment_status = 'paid' THEN e.paid_amount ELSE 0 END), 0) AS total_paid,
  COALESCE(SUM(e.remaining_amount), 0)                                                 AS total_remaining
FROM public.expenses e
WHERE e.is_active = true
GROUP BY e.business_id, DATE_TRUNC('month', e.expense_date);

GRANT SELECT ON public.vw_expense_summary TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 6: CATEGORY-WISE EXPENSES VIEW
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE VIEW public.vw_expenses_by_category AS
SELECT
  e.business_id,
  e.expense_category_id,
  e.category_name,
  COALESCE(SUM(e.amount), 0)                        AS total_amount,
  COUNT(DISTINCT e.id)                              AS expense_count,
  COALESCE(AVG(e.amount), 0)                        AS avg_amount,
  COUNT(CASE WHEN e.status = 'paid' THEN 1 END)    AS paid_count,
  COUNT(CASE WHEN e.status = 'pending' THEN 1 END) AS pending_count
FROM public.expenses e
WHERE e.is_active = true
GROUP BY e.business_id, e.expense_category_id, e.category_name;

GRANT SELECT ON public.vw_expenses_by_category TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 7: EXPENSE DASHBOARD VIEW
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE VIEW public.vw_expense_dashboard AS
SELECT
  e.id,
  e.business_id,
  e.expense_number,
  e.title,
  e.category_name,
  e.vendor_name,
  e.amount,
  e.paid_amount,
  e.remaining_amount,
  e.status,
  e.payment_status,
  e.expense_date,
  e.payment_date,
  e.invoice_number,
  e.gst_amount,
  e.created_by_name,
  e.created_at,
  COUNT(DISTINCT ep.id) AS payment_count,
  MAX(ep.payment_date)  AS last_payment_date
FROM public.expenses e
LEFT JOIN public.expense_payments ep ON e.id = ep.expense_id
WHERE e.is_active = true
GROUP BY e.id;

GRANT SELECT ON public.vw_expense_dashboard TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 8: FUNCTION — SEED DEFAULT EXPENSE CATEGORIES (Global, runs once)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_create_default_expense_categories()
RETURNS TABLE (
  success             BOOLEAN,
  categories_created  INT,
  error_message       TEXT
) AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.expense_categories;

  IF v_count > 0 THEN
    RETURN QUERY SELECT true, 0, NULL::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.expense_categories (name, icon, color, description, sort_order)
  VALUES
    ('Maintenance',       'build',         '#FF6B6B', 'Equipment and facility maintenance', 1),
    ('Event Costs',       'celebration',   '#FFA500', 'Event organization and setup',       2),
    ('Interior Work',     'home',          '#4ECDC4', 'Interior renovation and decoration', 3),
    ('Festival Expenses', 'gift',          '#95E1D3', 'Festival-related expenses',          4),
    ('Utilities',         'bolt',          '#FFD93D', 'Electricity, water, gas',            5),
    ('Staff',             'people',        '#6BCB77', 'Salaries and benefits',              6),
    ('Marketing',         'megaphone',     '#4D96FF', 'Marketing and advertising',          7),
    ('Supplies',          'shopping_cart', '#FF6B9D', 'Office and operational supplies',    8),
    ('Other',             'help',          '#9B9B9B', 'Other miscellaneous expenses',       9)
  ON CONFLICT (name) DO NOTHING;

  SELECT COUNT(*) INTO v_count FROM public.expense_categories;

  RETURN QUERY SELECT true, v_count, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, 0, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 9: FUNCTION — CREATE EXPENSE FROM BILL
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_create_expense_from_bill(
  p_business_id       TEXT,
  p_category_id       UUID,
  p_vendor_name       TEXT,
  p_amount            NUMERIC,
  p_invoice_number    TEXT,
  p_expense_date      DATE,
  p_created_by_uid    TEXT,
  p_created_by_name   TEXT,
  p_created_by_role   TEXT,
  p_bill_file_path    TEXT,
  p_bill_file_name    TEXT,
  p_bill_file_size    INT
)
RETURNS TABLE (
  success       BOOLEAN,
  expense_id    UUID,
  error_message TEXT
) AS $$
DECLARE
  v_expense_id    UUID;
  v_category_name TEXT;
BEGIN
  SELECT name INTO v_category_name
  FROM public.expense_categories
  WHERE id = p_category_id;

  IF v_category_name IS NULL THEN
    RETURN QUERY SELECT false, NULL::UUID, 'Category not found'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.expenses (
    business_id, title, description,
    expense_category_id, category_name, vendor_name, amount,
    invoice_number, expense_date,
    bill_file_path, bill_file_name, bill_file_size, bill_uploaded_at,
    created_by_uid, created_by_name, created_by_role
  ) VALUES (
    p_business_id,
    CONCAT('Bill - ', p_vendor_name),
    'Auto-created from bill upload',
    p_category_id,
    v_category_name,
    p_vendor_name,
    p_amount,
    p_invoice_number,
    p_expense_date,
    p_bill_file_path,
    p_bill_file_name,
    p_bill_file_size,
    NOW(),
    p_created_by_uid,
    p_created_by_name,
    p_created_by_role
  ) RETURNING expenses.id INTO v_expense_id;

  RETURN QUERY SELECT true, v_expense_id, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, NULL::UUID, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 10: FUNCTION — RECORD EXPENSE PAYMENT
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_record_expense_payment(
  p_expense_id        UUID,
  p_payment_amount    NUMERIC,
  p_payment_date      DATE,
  p_payment_method    TEXT,
  p_transaction_id    TEXT,
  p_recorded_by_uid   TEXT,
  p_recorded_by_name  TEXT,
  p_recorded_by_role  TEXT
)
RETURNS TABLE (
  success            BOOLEAN,
  payment_id         UUID,
  new_payment_status TEXT,
  error_message      TEXT
) AS $$
DECLARE
  v_payment_id      UUID;
  v_total_paid      NUMERIC;
  v_expense_amount  NUMERIC;
  v_new_status      TEXT;
  v_business_id     TEXT;
BEGIN
  SELECT business_id, amount INTO v_business_id, v_expense_amount
  FROM public.expenses WHERE id = p_expense_id;

  IF v_expense_amount IS NULL THEN
    RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, 'Expense not found'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.expense_payments (
    business_id, expense_id,
    payment_amount, payment_date, payment_method, transaction_id,
    recorded_by_uid, recorded_by_name, recorded_by_role
  ) VALUES (
    v_business_id,
    p_expense_id,
    p_payment_amount,
    p_payment_date,
    p_payment_method,
    p_transaction_id,
    p_recorded_by_uid,
    p_recorded_by_name,
    p_recorded_by_role
  ) RETURNING expense_payments.id INTO v_payment_id;

  SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
  FROM public.expense_payments
  WHERE expense_id = p_expense_id AND payment_status = 'completed';

  IF v_total_paid >= v_expense_amount THEN
    v_new_status := 'paid';
  ELSIF v_total_paid > 0 THEN
    v_new_status := 'partial';
  ELSE
    v_new_status := 'unpaid';
  END IF;

  UPDATE public.expenses
  SET
    paid_amount      = v_total_paid,
    remaining_amount = v_expense_amount - v_total_paid,
    payment_status   = v_new_status,
    payment_date     = CASE WHEN v_total_paid > 0 THEN CURRENT_DATE ELSE payment_date END,
    updated_at       = NOW()
  WHERE id = p_expense_id;

  RETURN QUERY SELECT true, v_payment_id, v_new_status, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 11: FUNCTION — GET EXPENSE STATS
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_get_expense_stats(p_business_id TEXT)
RETURNS TABLE (
  total_expenses   NUMERIC,
  total_amount     NUMERIC,
  pending_amount   NUMERIC,
  paid_amount      NUMERIC,
  unpaid_count     INT,
  pending_approval INT,
  categories_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    CAST(COUNT(*) AS NUMERIC),
    COALESCE(SUM(CASE WHEN e.is_active THEN e.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.is_active AND e.status = 'pending' THEN e.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.is_active AND e.payment_status = 'paid' THEN e.paid_amount ELSE 0 END), 0),
    COUNT(CASE WHEN e.payment_status = 'unpaid' THEN 1 END)::INT,
    COUNT(CASE WHEN e.approval_status = 'pending' THEN 1 END)::INT,
    COUNT(DISTINCT e.expense_category_id)::INT
  FROM public.expenses e
  WHERE e.business_id = p_business_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 12: FUNCTION — GET MONTHLY EXPENSE SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_get_monthly_expense_summary(p_business_id TEXT)
RETURNS TABLE (
  month           TEXT,
  total_amount    NUMERIC,
  expense_count   INT,
  pending_count   INT,
  unpaid_count    INT,
  total_paid      NUMERIC,
  total_remaining NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    DATE_TRUNC('month', e.expense_date)::date::TEXT,
    COALESCE(SUM(e.amount), 0),
    COUNT(DISTINCT e.id)::INT,
    COUNT(CASE WHEN e.status = 'pending' THEN 1 END)::INT,
    COUNT(CASE WHEN e.payment_status = 'unpaid' THEN 1 END)::INT,
    COALESCE(SUM(CASE WHEN e.payment_status = 'paid' THEN e.paid_amount ELSE 0 END), 0),
    COALESCE(SUM(e.remaining_amount), 0)
  FROM public.expenses e
  WHERE e.business_id = p_business_id AND e.is_active = true
  GROUP BY DATE_TRUNC('month', e.expense_date)
  ORDER BY DATE_TRUNC('month', e.expense_date) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 13: DISABLE RLS & GRANT PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.expenses           DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_payments   DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_bills      DISABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.expenses           TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_payments   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_categories TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expense_bills      TO anon, authenticated;

GRANT EXECUTE ON FUNCTION fn_create_default_expense_categories()                                                     TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_create_expense_from_bill(TEXT,UUID,TEXT,NUMERIC,TEXT,DATE,TEXT,TEXT,TEXT,TEXT,TEXT,INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_record_expense_payment(UUID,NUMERIC,DATE,TEXT,TEXT,TEXT,TEXT,TEXT)                      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_get_expense_stats(TEXT)                                                                 TO anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_get_monthly_expense_summary(TEXT)                                                       TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 14: REALTIME PUBLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'expenses'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE expenses;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'expense_payments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE expense_payments;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'expense_categories'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE expense_categories;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 15: SEED DEFAULT CATEGORIES
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT * FROM fn_create_default_expense_categories();

-- ═══════════════════════════════════════════════════════════════════════════════
-- END OF MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════════