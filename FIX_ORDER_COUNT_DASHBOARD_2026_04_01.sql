-- ============================================================
-- FUNCTION: fn_revenue_summary
-- Returns revenue analytics for dashboard
-- Filters by business_id, date range, and optionally staff_uid
-- Only includes completed orders
-- ============================================================

CREATE OR REPLACE FUNCTION fn_revenue_summary(
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
  cancelled BIGINT
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_total_revenue DECIMAL := 0;
  v_total_orders BIGINT := 0;
  v_avg_order DECIMAL := 0;
  v_completed BIGINT := 0;
  v_cancelled BIGINT := 0;
BEGIN
  -- Calculate metrics from completed orders only
  SELECT
    COALESCE(SUM(total_amount), 0)::DECIMAL,
    COUNT(*)::BIGINT,
    CASE WHEN COUNT(*) > 0 THEN COALESCE(AVG(total_amount), 0)::DECIMAL ELSE 0 END,
    COUNT(*)::BIGINT, -- completed orders
    0::BIGINT -- cancelled (we'll calculate separately if needed)
  INTO v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND payment_status = 'paid'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- If we want cancelled orders too, uncomment this:
  -- SELECT COUNT(*)::BIGINT
  -- INTO v_cancelled
  -- FROM orders
  -- WHERE business_id = p_business_id
  --   AND status = 'cancelled'
  --   AND created_at >= p_from
  --   AND created_at < p_to
  --   AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  RETURN QUERY SELECT v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;


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


--April1 ordercount mismstched

-- ════════════════════════════════════════════════════════════════════════════
-- FIX: Dashboard Order Count Inconsistency
-- Date: April 1, 2026
-- Issue: Dashboard shows 1 order but "Today's Orders" shows 2 completed orders
--
-- ROOT CAUSE:
-- The RPC function fn_revenue_summary counts only COMPLETED + PAID orders.
-- If you have 2 completed orders but 1 is unpaid, total_orders shows only 1.
--
-- SOLUTION:
-- Separate the concern:
-- - total_revenue: Only from PAID orders (existing logic)
-- - total_orders: Count ALL COMPLETED orders (regardless of payment status)
-- - completed: All completed orders (regardless of payment status) ✓ FIXED
-- - cancelled: All cancelled orders
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) CASCADE;

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
  -- Step 1: Calculate REVENUE from PAID completed orders only
  -- ════════════════════════════════════════════════════════════════════════════
  SELECT
    COALESCE(SUM(total_amount), 0)::DECIMAL,
    CASE WHEN COUNT(*) > 0 THEN COALESCE(AVG(total_amount), 0)::DECIMAL ELSE 0 END
  INTO v_total_revenue, v_avg_order
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND payment_status = 'paid'  -- ← Revenue only from paid orders
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 2: Count ALL COMPLETED orders (regardless of payment status)
  -- ════════════════════════════════════════════════════════════════════════════
  SELECT COUNT(*)::BIGINT
  INTO v_completed
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'completed'  -- ← ALL completed orders, not just paid
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 3: Count CANCELLED orders
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
  -- Step 4: Calculate TOTAL ORDERS
  -- Note: Counted orders = completed + cancelled (excludes pending/preparing/ready)
  -- ════════════════════════════════════════════════════════════════════════════
  v_total_orders := v_completed + v_cancelled;

  -- ════════════════════════════════════════════════════════════════════════════
  -- Step 5: Calculate CANCELLATION RATE percentage
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT INSTRUCTIONS
-- ════════════════════════════════════════════════════════════════════════════
-- 1. ✅ Copy the entire SQL above (from DROP to GRANT)
-- 2. ✅ Open Supabase Dashboard → SQL Editor
-- 3. ✅ Paste the entire SQL and execute
-- 4. ✅ The function automatically drops the old version and creates the new one
-- 5. ✅ Hot restart your Flutter app
-- 6. ✅ Navigate to Dashboard
-- 7. ✅ Verify: Dashboard order count now matches "Today's Orders" count
-- ════════════════════════════════════════════════════════════════════════════

-- WHAT CHANGED:
-- ─────────────────────────────────────────────────────────────────────────────
-- OLD LOGIC:
--   - Count completed: Only IF status='completed' AND payment_status='paid'
--   - Result: 2 completed orders where 1 is unpaid → shows count of 1 ❌
--
-- NEW LOGIC:
--   - total_revenue: Only from payment_status='paid' (unchanged)
--   - Count completed: ALL orders with status='completed' (regardless of payment)
--   - Result: 2 completed orders → shows count of 2 ✅
-- ────────────────────────────────────────────────────────────────────────────
