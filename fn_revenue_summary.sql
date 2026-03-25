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