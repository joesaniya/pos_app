-- ═════════════════════════════════════════════════════════════════════════════
-- FIX: table_reservations_status_check constraint violation
-- Issue: fn_expire_stale_reservations was setting status='expired' (invalid)
-- Solution: Change to status='no_show' to match valid check constraint
-- Date: March 26, 2026
-- ═════════════════════════════════════════════════════════════════════════════

-- Step 1: Ensure table_reservations has proper CHECK constraint
-- First, drop existing constraint if it exists
ALTER TABLE public.table_reservations
DROP CONSTRAINT IF EXISTS table_reservations_status_check;

-- Add the correct CHECK constraint with valid status values
ALTER TABLE public.table_reservations
ADD CONSTRAINT table_reservations_status_check
CHECK (status IN ('active', 'seated', 'no_show', 'completed', 'cancelled'));

-- Step 2: Update the fn_expire_stale_reservations function to use 'no_show' instead of 'expired'
DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(p_business_id TEXT) CASCADE;

CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE v_count INT;
BEGIN
  UPDATE public.table_reservations
  SET status='no_show',updated_at=NOW()
  WHERE business_id=p_business_id
    AND status='active'
    AND check_in IS NULL
    AND reserved_for < NOW()-INTERVAL '15 min';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('expired_count',v_count,'success',true);
END;
$$;

-- Step 3: Clean up any invalid 'expired' status values that may exist
UPDATE public.table_reservations
SET status='no_show',updated_at=NOW()
WHERE status='expired';

-- Step 4: Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
