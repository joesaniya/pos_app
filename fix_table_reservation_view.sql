-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRATION: Create missing vw_tables_with_reservation view
-- 
-- ISSUE: The view is referenced in tables_repository.dart but was never created.
-- This causes PGRST204 "schema not found" errors during sync operations.
--
-- Run this in Supabase SQL Editor to fix the error:
-- "Could not find the 'res_actual_check_out' column of 'restaurant_tables'"
-- ══════════════════════════════════════════════════════════════════════════════

-- Drop existing view if it has wrong structure
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;

-- Create the view properly
CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.id,
  rt.business_id,
  rt.table_number,
  rt.section,
  rt.capacity,
  rt.status,
  rt.current_customer_name,
  rt.current_customer_name AS customer_name,
  rt.current_order_id,
  rt.current_order_total,
  rt.occupied_since,
  rt.session_id,
  rt.is_active,
  rt.shape,
  rt.floor,
  rt.created_by_uid,
  rt.created_by_name,
  rt.updated_by_uid,
  rt.updated_by_name,
  rt.created_at,
  rt.updated_at,
  -- Include reservation information if one exists for today
  CASE WHEN tr.id IS NOT NULL THEN jsonb_build_object(
    'id', tr.id,
    'customer_name', tr.customer_name,
    'phone', tr.phone,
    'guest_count', tr.guest_count,
    'reserved_for', tr.reserved_for,
    'check_in', tr.check_in,
    'check_out', tr.check_out,
    'notes', tr.notes,
    'status', tr.status,
    'created_by_name', tr.created_by_name
  ) ELSE NULL END AS reservation_data
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr ON 
  tr.table_id = rt.id 
  AND tr.status IN ('active', 'seated')
  AND DATE(tr.reserved_for AT TIME ZONE 'Asia/Kolkata') = DATE(NOW() AT TIME ZONE 'Asia/Kolkata');

-- Grant permissions
GRANT SELECT ON public.vw_tables_with_reservation TO anon, authenticated;

-- Also ensure table_reservations table has all required columns
-- (This should already exist but verify the actual_check_out column)
-- If actual_check_out doesn't exist, add it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'table_reservations' 
    AND column_name = 'actual_check_out'
  ) THEN
    ALTER TABLE public.table_reservations 
    ADD COLUMN actual_check_out TIMESTAMPTZ;
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ══════════════════════════════════════════════════════════════════════════════

-- Verify view exists and has correct columns
-- SELECT * FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'vw_tables_with_reservation';

-- Verify actual_check_out column exists
-- SELECT column_name, data_type FROM information_schema.columns 
-- WHERE table_schema = 'public' AND table_name = 'table_reservations' 
-- ORDER BY ordinal_position;
