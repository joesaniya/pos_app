-- ════════════════════════════════════════════════════════════════════════════
-- STEP 1: VERIFY fn_revenue_summary EXISTS AND HAS CORRECT SIGNATURE
-- Run this in Supabase SQL Editor to check the current function
-- ════════════════════════════════════════════════════════════════════════════

SELECT 
  p.proname as function_name,
  count(*) as param_count,
  pg_get_functiondef(p.oid) as function_def
FROM pg_proc p
WHERE p.proname = 'fn_revenue_summary'
GROUP BY p.oid, p.proname
ORDER BY p.proname;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 2: If the above returned NOTHING, the function doesn't exist yet!
-- Run the complete function definition below:
-- ════════════════════════════════════════════════════════════════════════════

-- Drop old function (if it exists with old signature)
DROP FUNCTION IF EXISTS fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) CASCADE;

-- Create new function with correct signature
CREATE FUNCTION fn_revenue_summary(
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
  cancelled BIGINT,
  cancel_rate DECIMAL
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_total_revenue DECIMAL := 0;
  v_avg_order DECIMAL := 0;
  v_completed BIGINT := 0;
  v_cancelled BIGINT := 0;
  v_total_orders BIGINT := 0;
  v_cancel_rate DECIMAL := 0;
BEGIN
  -- Calculate COMPLETED orders metrics (revenue only from these)
  SELECT
    COALESCE(SUM(total_amount), 0)::DECIMAL,
    CASE WHEN COUNT(*) > 0 THEN COALESCE(AVG(total_amount), 0)::DECIMAL ELSE 0 END,
    COUNT(*)::BIGINT
  INTO v_total_revenue, v_avg_order, v_completed
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND payment_status = 'paid'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- Calculate CANCELLED orders count
  SELECT COUNT(*)::BIGINT
  INTO v_cancelled
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'cancelled'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- Calculate TOTAL ORDERS
  v_total_orders := v_completed + v_cancelled;

  -- Calculate CANCELLATION RATE percentage
  v_cancel_rate := CASE 
    WHEN v_total_orders > 0 THEN ROUND((v_cancelled::DECIMAL / v_total_orders::DECIMAL * 100), 2)
    ELSE 0
  END;

  RETURN QUERY SELECT v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled, v_cancel_rate;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 3A: FIRST - Find your actual business IDs in the orders table
-- ════════════════════════════════════════════════════════════════════════════

SELECT 
  DISTINCT business_id,
  COUNT(*) as order_count,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
  COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_count,
  SUM(CASE WHEN status = 'completed' AND payment_status = 'paid' THEN total_amount ELSE 0 END)::DECIMAL as total_revenue
FROM orders
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY business_id
ORDER BY order_count DESC;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 3B: COPY YOUR ACTUAL business_id FROM ABOVE AND PASTE IT BELOW
-- Replace 'your-business-id' with the real value (e.g., 'biz_abc123xyz')
-- Then run this query:
-- ════════════════════════════════════════════════════════════════════════════

-- Test the RPC function with TODAY's data
SELECT * FROM fn_revenue_summary(
  'your-business-id',
  CURRENT_DATE AT TIME ZONE 'Asia/Kolkata',
  (CURRENT_DATE + 1) AT TIME ZONE 'Asia/Kolkata'
);

-- Test the RPC function with THIS WEEK's data
SELECT * FROM fn_revenue_summary(
  'your-business-id',
  CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE) - 1)::INT * INTERVAL '1 day'),
  CURRENT_DATE + ((8 - EXTRACT(DOW FROM CURRENT_DATE))::INT * INTERVAL '1 day')
);

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 4: If the function returns data, check orders table directly
-- ════════════════════════════════════════════════════════════════════════════

SELECT 
  COUNT(*) as total_orders,
  COUNT(CASE WHEN status = 'completed' AND payment_status = 'paid' THEN 1 END) as completed,
  COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled,
  SUM(CASE WHEN status = 'completed' AND payment_status = 'paid' THEN total_amount ELSE 0 END)::DECIMAL as revenue
FROM orders
WHERE business_id = 'your-business-id'
  AND created_at >= NOW() - INTERVAL '7 days';
