-- Migration: Create vw_orders_with_items view (fix PGRST205 error)
-- Created: 2026-03-25
-- Purpose: Ensures the orders view with aggregated items exists for realtime callbacks

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.vw_orders_with_items CASCADE;

-- Create the view
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

-- Grant permissions to authenticated users and service role
GRANT SELECT ON public.vw_orders_with_items TO authenticated, service_role;

-- Add comment for clarity
COMMENT ON VIEW public.vw_orders_with_items IS 'Orders view with aggregated order items (used by OrdersService realtime callbacks)';
