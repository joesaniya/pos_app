-- ═════════════════════════════════════════════════════════════════════════════
-- FIX: Reservation Status Constraint Violation (2026-03-26)
-- ═════════════════════════════════════════════════════════════════════════════
-- Issue: fn_expire_stale_reservations tries to set status='expired'
--        but table_reservations only accepts: active, seated, cancelled, no_show
-- Error: "new row for relation "table_reservations" violates check constraint 
--         "table_reservations_status_check""
-- ═════════════════════════════════════════════════════════════════════════════

-- Drop and recreate the function with correct status value
DROP FUNCTION IF EXISTS public.fn_expire_stale_reservations(TEXT) CASCADE;

CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE v_count INT;
BEGIN
  -- Expire stale active reservations by marking them as 'no_show'
  -- (the only valid terminal status for not-shown reservations)
  UPDATE public.table_reservations
  SET status='no_show', updated_at=NOW()
  WHERE business_id=p_business_id
    AND status='active'
    AND check_in IS NULL
    AND reserved_for < NOW()-INTERVAL '15 min';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('expired_count',v_count,'success',true);
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- Verification
-- ═════════════════════════════════════════════════════════════════════════════
-- SELECT pg_get_functiondef('public.fn_expire_stale_reservations(TEXT)'::regprocedure);
