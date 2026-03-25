-- ═════════════════════════════════════════════════════════════════════════════
-- FIX: vw_tables_with_reservation View - Include reservation_data JSON field
-- Issue: ReservationSection receiving null reservation when table.status = 'reserved'
-- Root Cause: View missing reservation_data field that _rowToTable expects
-- ═════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;

CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.*,
  -- 🔧 FIX: Build reservation_data as JSON object for _rowToTable parsing
  CASE
    WHEN tr.id IS NOT NULL THEN jsonb_build_object(
      'id', tr.id,
      'customer_name', tr.customer_name,
      'phone', tr.phone,
      'guest_count', tr.guest_count,
      'reserved_for', tr.reserved_for::text,
      'check_in', tr.check_in::text,
      'check_out', tr.check_out::text,
      'actual_check_out', tr.actual_check_out::text,
      'notes', tr.notes,
      'status', tr.status,
      'warning_sent', tr.warning_sent,
      'created_at', tr.created_at::text,
      'created_by_name', tr.created_by_name,
      'created_by_role', tr.created_by_role
    )
    ELSE NULL
  END AS reservation_data
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr
  ON tr.table_id = rt.id
  AND tr.status IN ('active', 'seated');  -- Only active/seated reservations

-- Grant permissions
GRANT SELECT ON public.vw_tables_with_reservation TO anon, authenticated;

-- Force Postgrest schema cache refresh
NOTIFY pgrst, 'reload schema';

-- ═════════════════════════════════════════════════════════════════════════════
-- Verification Query
-- ═════════════════════════════════════════════════════════════════════════════
-- Run this to verify the view works correctly:
-- SELECT id, table_id, status, reservation_data 
-- FROM vw_tables_with_reservation 
-- WHERE status = 'reserved' 
-- LIMIT 5;
-- 
-- Expected: Reserved tables should have non-NULL reservation_data in JSON format
-- ═════════════════════════════════════════════════════════════════════════════
