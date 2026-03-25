-- ================================================================
-- PAYMENT & BILL SYSTEM MIGRATION
-- Adds payment_status to orders, bill_number, payment details
-- Order completion is GATED on payment confirmation
-- Run in Supabase SQL Editor
-- ================================================================

-- ── 1. Add payment columns to orders table ──────────────────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS payment_status    TEXT NOT NULL DEFAULT 'unpaid'
    CHECK (payment_status IN ('unpaid','paid','partial','refunded')),
  ADD COLUMN IF NOT EXISTS payment_mode      TEXT
    CHECK (payment_mode IN ('cash','upi','card','bank','complimentary')),
  ADD COLUMN IF NOT EXISTS payment_ref       TEXT,        -- UPI txn ID / card last 4
  ADD COLUMN IF NOT EXISTS paid_at           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_by_uid       TEXT,
  ADD COLUMN IF NOT EXISTS paid_by_name      TEXT,
  ADD COLUMN IF NOT EXISTS bill_number       TEXT UNIQUE, -- e.g. BILL-2024-00042
  ADD COLUMN IF NOT EXISTS bill_generated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS tip_amount        NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS round_off         NUMERIC(10,2) NOT NULL DEFAULT 0;

-- ── 2. Bill number sequence ──────────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS bill_number_seq START 1000;

-- ── 3. Auto-generate bill_number on INSERT ───────────────────────
CREATE OR REPLACE FUNCTION fn_assign_bill_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.bill_number IS NULL THEN
    NEW.bill_number := 'BILL-' ||
      TO_CHAR(NOW(), 'YYYY') || '-' ||
      LPAD(nextval('bill_number_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_bill_number ON orders;
CREATE TRIGGER trg_assign_bill_number
  BEFORE INSERT ON orders
  FOR EACH ROW EXECUTE FUNCTION fn_assign_bill_number();

-- ── 4. Backfill bill_number for existing orders ──────────────────
UPDATE orders
SET bill_number = 'BILL-' ||
  TO_CHAR(created_at, 'YYYY') || '-' ||
  LPAD(nextval('bill_number_seq')::TEXT, 5, '0')
WHERE bill_number IS NULL;

-- ── 5. CRITICAL: Prevent completing unpaid orders ────────────────
-- Orders can only move to 'completed' if payment_status = 'paid'
CREATE OR REPLACE FUNCTION fn_guard_order_completion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- If trying to set status = 'completed' and payment is not paid
  IF NEW.status = 'completed' AND NEW.payment_status != 'paid' THEN
    RAISE EXCEPTION
      'Cannot complete order: payment status is %. Mark as paid first.',
      NEW.payment_status
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_completion ON orders;
CREATE TRIGGER trg_guard_order_completion
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION fn_guard_order_completion();

-- ── 6. Auto-complete order when payment is confirmed ─────────────
-- When payment_status flips to 'paid' AND order is 'ready', auto-complete
CREATE OR REPLACE FUNCTION fn_auto_complete_on_payment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Payment just became 'paid'
  IF OLD.payment_status != 'paid' AND NEW.payment_status = 'paid' THEN
    -- Set paid_at if not set
    IF NEW.paid_at IS NULL THEN
      NEW.paid_at := NOW();
    END IF;
    -- Generate bill timestamp
    NEW.bill_generated_at := NOW();
    -- Auto-complete if order is in a completable state
    IF NEW.status IN ('ready', 'preparing', 'pending') THEN
      NEW.status := 'completed';
      NEW.completed_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_complete_on_payment ON orders;
CREATE TRIGGER trg_auto_complete_on_payment
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION fn_auto_complete_on_payment();

-- ── 7. Payment notification trigger ─────────────────────────────
CREATE OR REPLACE FUNCTION fn_notify_payment_received()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.payment_status != 'paid' AND NEW.payment_status = 'paid' THEN
    INSERT INTO order_notifications(order_id, business_id, title, body, type)
    VALUES (
      NEW.id,
      NEW.business_id,
      '💰 Payment Received — Order #' || NEW.order_number,
      'Bill ' || NEW.bill_number || ' · ' ||
        COALESCE(NEW.payment_mode, 'Cash') ||
        ' · ₹' || NEW.total_amount,
      'status_change'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_payment ON orders;
CREATE TRIGGER trg_notify_payment
  AFTER UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION fn_notify_payment_received();

-- ── 8. Updated view with payment fields ─────────────────────────
DROP VIEW IF EXISTS vw_orders_with_items CASCADE;

CREATE VIEW vw_orders_with_items AS
SELECT
  o.id,
  o.order_number,
  o.bill_number,
  o.status,
  o.payment_status,
  o.payment_mode,
  o.payment_ref,
  o.paid_at,
  o.paid_by_uid,
  o.paid_by_name,
  o.bill_generated_at,
  o.order_type,
  o.table_id,
  o.table_number,
  o.customer_name,
  o.customer_phone,
  o.subtotal,
  o.tax_amount,
  o.discount_amount,
  o.tip_amount,
  o.round_off,
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
      ) ORDER BY oi.created_at
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'::json
  ) AS items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY
  o.id, o.order_number, o.bill_number, o.status, o.payment_status,
  o.payment_mode, o.payment_ref, o.paid_at, o.paid_by_uid, o.paid_by_name,
  o.bill_generated_at, o.order_type, o.table_id, o.table_number,
  o.customer_name, o.customer_phone, o.subtotal, o.tax_amount,
  o.discount_amount, o.tip_amount, o.round_off, o.total_amount, o.tax_rate,
  o.notes, o.business_id, o.business_name,
  o.created_by_uid, o.created_by_name, o.created_by_role,
  o.updated_by_uid, o.updated_by_name,
  o.started_at, o.ready_at, o.completed_at, o.cancelled_at,
  o.created_at, o.updated_at;

GRANT SELECT ON vw_orders_with_items TO anon;
GRANT SELECT ON vw_orders_with_items TO authenticated;

-- ── 9. Daily revenue with payment breakdown ──────────────────────
CREATE OR REPLACE VIEW vw_payment_analytics AS
SELECT
  business_id,
  DATE(paid_at)                                       AS pay_date,
  COUNT(*) FILTER (WHERE payment_status = 'paid')     AS paid_orders,
  SUM(total_amount) FILTER (WHERE payment_status = 'paid') AS paid_revenue,
  COUNT(*) FILTER (WHERE payment_mode = 'cash')        AS cash_count,
  COUNT(*) FILTER (WHERE payment_mode = 'upi')         AS upi_count,
  COUNT(*) FILTER (WHERE payment_mode = 'card')        AS card_count,
  SUM(total_amount) FILTER (WHERE payment_mode = 'cash') AS cash_revenue,
  SUM(total_amount) FILTER (WHERE payment_mode = 'upi')  AS upi_revenue,
  SUM(total_amount) FILTER (WHERE payment_mode = 'card') AS card_revenue,
  SUM(tip_amount)   FILTER (WHERE payment_status = 'paid') AS total_tips
FROM orders
WHERE payment_status = 'paid'
GROUP BY business_id, DATE(paid_at);

GRANT SELECT ON vw_payment_analytics TO anon;
GRANT SELECT ON vw_payment_analytics TO authenticated;

-- ── 10. Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_orders_payment_status
  ON orders(business_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_bill_number
  ON orders(bill_number);
CREATE INDEX IF NOT EXISTS idx_orders_paid_at
  ON orders(business_id, paid_at DESC);

-- ── 11. Realtime for payment updates ────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
  END IF;
END $$;

-- ── VERIFY ──────────────────────────────────────────────────────
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name IN (
    'payment_status','payment_mode','payment_ref',
    'paid_at','bill_number','tip_amount','round_off'
  )
ORDER BY ordinal_position;