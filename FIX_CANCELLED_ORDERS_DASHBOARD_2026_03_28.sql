-- ============================================================
-- FUNCTION: fn_revenue_summary (FIXED)
-- Returns revenue analytics for dashboard with proper cancelled order counts
-- Properly separates:
-- - Revenue: Only from completed/paid orders
-- - Total Orders: All orders (completed + cancelled)
-- - Completed/Cancelled: Separate counts
-- - Cancellation Rate: (cancelled / total) * 100
-- ============================================================

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 1: Drop the old function first (signature has changed)
-- ════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) CASCADE;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 2: Create the new function with updated return columns
-- ════════════════════════════════════════════════════════════════════════════
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
  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 1: Calculate COMPLETED orders metrics (revenue only from these)
  -- ════════════════════════════════════════════════════════════════════════════
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

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 2: Calculate CANCELLED orders count
  -- ════════════════════════════════════════════════════════════════════════════
  SELECT COUNT(*)::BIGINT
  INTO v_cancelled
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'cancelled'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 3: Calculate TOTAL ORDERS (completed + cancelled)
  -- Note: Excludes pending/preparing/ready to match order lifecycle
  -- ════════════════════════════════════════════════════════════════════════════
  v_total_orders := v_completed + v_cancelled;

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 4: Calculate CANCELLATION RATE percentage
  -- Format: (cancelled / total) * 100
  -- ════════════════════════════════════════════════════════════════════════════
  v_cancel_rate := CASE 
    WHEN v_total_orders > 0 THEN ROUND((v_cancelled::DECIMAL / v_total_orders::DECIMAL * 100), 2)
    ELSE 0
  END;

  -- ════════════════════════════════════════════════════════════════════════════
  -- Return all metrics
  -- ════════════════════════════════════════════════════════════════════════════
  RETURN QUERY SELECT v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled, v_cancel_rate;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT NOTES
-- ════════════════════════════════════════════════════════════════════════════
-- 1. This file automatically drops and recreates the function (no manual steps needed)
-- 2. Copy the ENTIRE file contents and run in Supabase SQL Editor
-- 3. The function now returns 6 columns instead of 5:
--    - total_revenue: DECIMAL (from completed/paid only)
--    - total_orders: BIGINT (completed + cancelled)
--    - avg_order: DECIMAL (average of completed orders)
--    - completed: BIGINT (count of completed orders)
--    - cancelled: BIGINT (count of cancelled orders) ✓ NOW CALCULATED
--    - cancel_rate: DECIMAL (percentage: cancelled/total*100) ✓ NEW
-- 4. No Dart code changes required - already handles all return values
-- 5. After running this SQL, restart the Flutter app to see the fix
-- ════════════════════════════════════════════════════════════════════════════
