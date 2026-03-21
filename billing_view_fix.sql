-- ════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Update vw_orders_with_items to include all payment & bill fields
-- Run this in your Supabase SQL Editor.
-- This ensures confirmPayment() and realtime events carry the full order data.
-- ════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;

CREATE VIEW public.vw_orders_with_items AS
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
  o.table_seat_id,
  o.seat_label,
  o.customer_name,
  o.customer_phone,
  o.subtotal,
  o.tax_amount,
  o.tax_rate,
  o.discount_amount,
  o.tip_amount,
  o.round_off,
  o.total_amount,
  o.notes,
  o.business_id,
  o.business_name,
  o.created_by_uid,
  o.created_by_name,
  o.created_by_role,
  o.updated_by_uid,
  o.updated_by_name,
  o.created_at,
  o.started_at,
  o.ready_at,
  o.completed_at,
  o.cancelled_at,
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
FROM public.orders o
LEFT JOIN public.order_items oi ON oi.order_id = o.id
GROUP BY
  o.id, o.order_number, o.bill_number, o.status,
  o.payment_status, o.payment_mode, o.payment_ref,
  o.paid_at, o.paid_by_uid, o.paid_by_name, o.bill_generated_at,
  o.order_type, o.table_id, o.table_number, o.table_seat_id, o.seat_label,
  o.customer_name, o.customer_phone,
  o.subtotal, o.tax_amount, o.tax_rate, o.discount_amount, o.tip_amount,
  o.round_off, o.total_amount,
  o.notes, o.business_id, o.business_name,
  o.created_by_uid, o.created_by_name, o.created_by_role,
  o.updated_by_uid, o.updated_by_name,
  o.created_at, o.started_at, o.ready_at, o.completed_at,
  o.cancelled_at, o.updated_at;

GRANT SELECT ON public.vw_orders_with_items TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- Verification: Count orders with items to confirm view is working
-- ════════════════════════════════════════════════════════════════════════════
-- SELECT id, order_number, json_array_length(items::json) AS item_count
-- FROM vw_orders_with_items
-- ORDER BY created_at DESC
-- LIMIT 10;
