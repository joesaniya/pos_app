-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Add seat_label to orders table
-- Run this in your Supabase SQL Editor before deploying the app update.
-- ══════════════════════════════════════════════════════════════════════════════

-- Step 1: Add seat_label column to orders table
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS seat_label TEXT;

-- Step 2: Backfill seat_label for existing orders that have a table_seat_id
-- This joins to table_seats to pull the label for historical orders.
UPDATE public.orders o
SET seat_label = ts.seat_label
FROM public.table_seats ts
WHERE o.table_seat_id = ts.id
  AND o.seat_label IS NULL;

-- Step 3: Recreate the vw_orders_with_items view to expose seat_label.
-- IMPORTANT: Replace the view body below with your actual view definition
-- if it differs from this template. The key change is that seat_label is
-- now a real column on orders, so it will be included automatically via o.*.
--
-- If your view uses SELECT o.*, ... this change is automatic.
-- If your view lists columns explicitly, add seat_label to the list.

-- To check your current view definition, run:
--   SELECT definition FROM pg_views WHERE viewname = 'vw_orders_with_items';

-- This is the standard recreate template – adjust if your view is different:
/*
CREATE OR REPLACE VIEW public.vw_orders_with_items AS
SELECT
  o.*,
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
GROUP BY o.id;
*/

-- Verification: Check the new column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'orders'
  AND column_name  = 'seat_label';
-- Expected result: 1 row with column_name = 'seat_label', data_type = 'text'
