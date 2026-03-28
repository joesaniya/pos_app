-- ============================================================
-- REVENUE ANALYTICS DASHBOARD FIX
-- Date: March 28, 2026
-- ============================================================
-- ISSUE: Dashboard and analytics show inconsistent data
-- - Dashboard Overview: Shows correct metrics ✓
-- - Analytics Weekly/Monthly/Yearly: Shows zero revenue ✗
--
-- ROOT CAUSE: Function signature changed; Dart code needs update
--
-- DEPLOYMENT: Run this SQL in Supabase SQL Editor, then
--             update Dart code to use new return signature
-- ============================================================

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 1: Drop the old function (signature changed - added cancel_rate column)
-- ════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) CASCADE;

-- ════════════════════════════════════════════════════════════════════════════
-- STEP 2: Create new function with 6 return columns
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

-- ── Grant permissions ────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT NOTES
-- ════════════════════════════════════════════════════════════════════════════
-- 1. ✅ Copy this entire file and run in Supabase SQL Editor
-- 2. ✅ Function automatically handles old version (DROP IF EXISTS)
-- 3. ✅ New return signature (6 columns instead of 5):
--    - total_revenue: DECIMAL (from completed/paid only)
--    - total_orders: BIGINT (completed + cancelled)
--    - avg_order: DECIMAL (average of completed orders)
--    - completed: BIGINT (count of completed orders)
--    - cancelled: BIGINT (count of cancelled orders) ✓ NOW CALCULATED
--    - cancel_rate: DECIMAL (percentage: cancelled/total*100) ✓ NEW
-- 4. ✅ Update Dart code to handle new columns (see next steps)
-- 5. ✅ Hot restart Flutter app to see the fix
-- ════════════════════════════════════════════════════════════════════════════
