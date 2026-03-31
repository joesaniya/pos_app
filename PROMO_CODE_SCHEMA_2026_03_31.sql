-- ════════════════════════════════════════════════════════════════════════════
-- 🎟️ PROMO CODE & DISCOUNT MANAGEMENT SYSTEM
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- 1. PROMO CODES TABLE
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.promo_codes (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT, -- Unique identifier
  business_id TEXT NOT NULL,                            -- Company reference
  code TEXT NOT NULL,                                   -- Promo code (e.g., SAVE20)
  discount_type TEXT NOT NULL,                          -- 'percentage' | 'fixed'
  discount_value NUMERIC NOT NULL,                      -- Discount amount/percentage
  min_order_value NUMERIC DEFAULT 0,                    -- Minimum order amount (optional)
  start_date TIMESTAMPTZ NOT NULL,                      -- Validity start
  expiry_date TIMESTAMPTZ NOT NULL,                     -- Validity end
  applicable_items JSONB DEFAULT NULL,                  -- Array of menu item IDs (null = all items)
  applicable_categories JSONB DEFAULT NULL,             -- Array of category IDs (null = all categories)
  customer_id TEXT DEFAULT NULL,                        -- Customer-specific coupon (null = all customers)
  is_active BOOLEAN DEFAULT TRUE,                       -- Status (active/inactive)
  created_by TEXT NOT NULL,                             -- Admin/Manager/Owner who created
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(business_id, code),                            -- Unique promo code per business
  CONSTRAINT valid_discount_type CHECK (discount_type IN ('percentage', 'fixed')),
  CONSTRAINT valid_discount_value CHECK (discount_value > 0),
  CONSTRAINT valid_dates CHECK (start_date <= expiry_date),
  CONSTRAINT valid_min_order CHECK (min_order_value >= 0)
);

-- ════════════════════════════════════════════════════════════════════════════
-- 2. PROMO CODE USAGE TRACKING TABLE (Optional but Recommended)
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.promo_code_usage (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  business_id TEXT NOT NULL,
  promo_code_id TEXT NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  customer_id TEXT DEFAULT NULL,                        -- Customer using the code
  discount_amount NUMERIC NOT NULL,                     -- Actual discount applied
  used_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(order_id, promo_code_id),                      -- Ensure code used once per order
  CONSTRAINT valid_discount_amount CHECK (discount_amount >= 0)
);

-- ════════════════════════════════════════════════════════════════════════════
-- 3. INDEXES FOR PERFORMANCE
-- ════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_promo_codes_business_id ON public.promo_codes(business_id);
CREATE INDEX IF NOT EXISTS idx_promo_codes_business_code ON public.promo_codes(business_id, code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON public.promo_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_promo_codes_customer_id ON public.promo_codes(customer_id);
CREATE INDEX IF NOT EXISTS idx_promo_codes_validity ON public.promo_codes(start_date, expiry_date);

CREATE INDEX IF NOT EXISTS idx_promo_usage_business_id ON public.promo_code_usage(business_id);
CREATE INDEX IF NOT EXISTS idx_promo_usage_promo_code_id ON public.promo_code_usage(promo_code_id);
CREATE INDEX IF NOT EXISTS idx_promo_usage_order_id ON public.promo_code_usage(order_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 4. RLS & PERMISSIONS
-- ════════════════════════════════════════════════════════════════════════════

-- DISABLE RLS FOR NOW - RBAC enforced at Flutter app layer
ALTER TABLE public.promo_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_code_usage DISABLE ROW LEVEL SECURITY;

-- Grant permissions to authenticated users
GRANT ALL PRIVILEGES ON public.promo_codes TO authenticated;
GRANT ALL PRIVILEGES ON public.promo_code_usage TO authenticated;
GRANT EXECUTE ON FUNCTION fn_validate_promo_code TO authenticated;
GRANT EXECUTE ON FUNCTION fn_calculate_discount_amount TO authenticated;
GRANT EXECUTE ON FUNCTION fn_record_promo_usage TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 5. UPDATED ORDERS TABLE - ADD PROMO CODE REFERENCE
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS promo_code_id TEXT 
  REFERENCES public.promo_codes(id) ON DELETE SET NULL;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. FUNCTION: VALIDATE PROMO CODE
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_validate_promo_code(
  p_code TEXT,
  p_business_id TEXT,
  p_customer_id TEXT DEFAULT NULL,
  p_order_amount NUMERIC DEFAULT 0
)
RETURNS TABLE (
  is_valid BOOLEAN,
  promo_code_id TEXT,
  discount_type TEXT,
  discount_value NUMERIC,
  error_message TEXT
) AS $$
DECLARE
  v_promo_code RECORD;
BEGIN
  -- Check if promo code exists and is active
  SELECT * INTO v_promo_code
  FROM public.promo_codes
  WHERE code = p_code
    AND business_id = p_business_id
    AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, 0::NUMERIC, 'Promo code not found or inactive'::TEXT;
    RETURN;
  END IF;

  -- Check if promo code is within validity period
  IF NOW() < v_promo_code.start_date OR NOW() > v_promo_code.expiry_date THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, 0::NUMERIC, 'Promo code has expired or not yet valid'::TEXT;
    RETURN;
  END IF;

  -- Check minimum order value
  IF v_promo_code.min_order_value > 0 AND p_order_amount < v_promo_code.min_order_value THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, 0::NUMERIC, 'Order amount does not meet minimum requirement'::TEXT;
    RETURN;
  END IF;

  -- Check customer-specific promo code
  IF v_promo_code.customer_id IS NOT NULL AND v_promo_code.customer_id != COALESCE(p_customer_id, '') THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, 0::NUMERIC, 'Promo code is not available for your account'::TEXT;
    RETURN;
  END IF;

  -- All validations passed
  RETURN QUERY SELECT 
    TRUE,
    v_promo_code.id,
    v_promo_code.discount_type,
    v_promo_code.discount_value,
    NULL::TEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. FUNCTION: CALCULATE DISCOUNT AMOUNT
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_calculate_discount_amount(
  p_discount_type TEXT,
  p_discount_value NUMERIC,
  p_order_amount NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
  IF p_discount_type = 'percentage' THEN
    RETURN LEAST(
      ROUND((p_order_amount * p_discount_value / 100)::NUMERIC, 2),
      p_order_amount
    );
  ELSIF p_discount_type = 'fixed' THEN
    RETURN LEAST(p_discount_value, p_order_amount);
  ELSE
    RETURN 0;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ════════════════════════════════════════════════════════════════════════════
-- 8. FUNCTION: RECORD PROMO CODE USAGE
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_record_promo_usage(
  p_business_id TEXT,
  p_promo_code_id TEXT,
  p_order_id UUID,
  p_customer_id TEXT DEFAULT NULL,
  p_discount_amount NUMERIC DEFAULT 0
)
RETURNS TABLE (
  success BOOLEAN,
  usage_id TEXT,
  error_message TEXT
) AS $$
DECLARE
  v_usage_id TEXT;
BEGIN
  -- Insert usage record
  INSERT INTO public.promo_code_usage (
    business_id, promo_code_id, order_id, customer_id, discount_amount
  )
  VALUES (
    p_business_id, p_promo_code_id, p_order_id, p_customer_id, p_discount_amount
  )
  RETURNING id INTO v_usage_id;

  RETURN QUERY SELECT TRUE, v_usage_id, NULL::TEXT;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT FALSE, NULL::TEXT, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════════════════════
-- 9. TEST DATA (Optional - Remove in production)
-- ════════════════════════════════════════════════════════════════════════════

-- Insert test promo codes (replace business_id with actual values)
-- INSERT INTO public.promo_codes (
--   business_id, code, discount_type, discount_value, min_order_value,
--   start_date, expiry_date, created_by, is_active
-- ) VALUES
--   ('test-biz-1', 'SAVE20', 'percentage', 20, 500, NOW(), NOW() + INTERVAL '30 days', 'admin', TRUE),
--   ('test-biz-1', 'FLAT100', 'fixed', 100, 1000, NOW(), NOW() + INTERVAL '30 days', 'admin', TRUE);

/* ════════════════════════════════════════════════════════════════════════════
   DEPLOYMENT GUIDE:
   ════════════════════════════════════════════════════════════════════════════
   
   1. Run this SQL in Supabase SQL Editor
   2. Enable RLS on promo_codes and promo_code_usage tables
   3. Grant permissions to service role:
   
      GRANT ALL ON public.promo_codes TO authenticated;
      GRANT ALL ON public.promo_code_usage TO authenticated;
      GRANT EXECUTE ON FUNCTION fn_validate_promo_code TO authenticated;
      GRANT EXECUTE ON FUNCTION fn_calculate_discount_amount TO authenticated;
      GRANT EXECUTE ON FUNCTION fn_record_promo_usage TO authenticated;
   
   4. Test validation functions
   5. Deploy Flutter changes
*/
