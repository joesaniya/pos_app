-- ============================================================
-- MIGRATION GUIDE: SEAT & TABLE CLEARING IMPLEMENTATION
-- Version: 1.0 (Production Ready)
-- Date: March 24, 2026
-- ============================================================

-- ============================================================
-- STEP 1: VERIFY EXISTING SCHEMA
-- ============================================================
-- Before deploying, verify your current schema has these tables:

-- Check table_seats exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_name = 'table_seats'
) as table_seats_exists;

-- Check restaurant_tables exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_name = 'restaurant_tables'
) as restaurant_tables_exists;

-- Check orders table exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_name = 'orders'
) as orders_exists;

-- Verify table_seats has required columns
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'table_seats'
ORDER BY ordinal_position;

-- Verify restaurant_tables has required columns
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'restaurant_tables'
ORDER BY ordinal_position;

-- Verify orders table has required columns - especially table_seat_id
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;


-- ============================================================
-- STEP 2: ADD MISSING COLUMNS (if needed)
-- ============================================================
-- Run these only if columns don't exist in your schema:

-- Add table_seat_id to orders if missing
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_seat_id UUID;

-- Add business_id to table_seats if missing
ALTER TABLE table_seats ADD COLUMN IF NOT EXISTS business_id TEXT;

-- Add session_id to table_seats if missing
ALTER TABLE table_seats ADD COLUMN IF NOT EXISTS session_id UUID;

-- Add status to restaurant_tables if missing
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'available'
  CHECK (status IN ('available','occupied','reserved','cleaning','inactive'));

-- Add session_id to restaurant_tables if missing
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS session_id UUID;

-- Add current_session_id to restaurant_tables if missing
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS current_session_id UUID;


-- ============================================================
-- STEP 3: VERIFY FOREIGN KEY RELATIONSHIPS
-- ============================================================

-- Verify foreign key: table_seats.table_id -> restaurant_tables.id
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_name = 'table_seats' AND column_name = 'table_id';

-- Verify foreign key: orders.table_id -> restaurant_tables.id
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_name = 'orders' AND column_name = 'table_id';

-- Verify foreign key: orders.table_seat_id -> table_seats.id
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_name = 'orders' AND column_name = 'table_seat_id';


-- ============================================================
-- STEP 4: VERIFY INDEXES (for performance)
-- ============================================================

-- List all indexes on table_seats
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'table_seats';

-- List all indexes on restaurant_tables
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'restaurant_tables';

-- List all indexes on orders
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'orders';

-- Create missing indexes if they don't exist:
CREATE INDEX IF NOT EXISTS idx_seats_table ON table_seats(table_id);
CREATE INDEX IF NOT EXISTS idx_seats_session ON table_seats(session_id);
CREATE INDEX IF NOT EXISTS idx_tables_business ON restaurant_tables(business_id);
CREATE INDEX IF NOT EXISTS idx_orders_seat ON orders(table_seat_id);


-- ============================================================
-- STEP 5: DEPLOY SQL FUNCTIONS
-- ============================================================
-- Copy the entire content of SEAT_AND_TABLE_CLEAR_FUNCTIONS.sql
-- and execute it in Supabase SQL Editor.
-- This creates:
--   - fn_clear_seat()
--   - fn_clear_table_complete()
--   - fn_get_seat_details()
--   - fn_get_table_seat_summaries()


-- ============================================================
-- STEP 6: VERIFY FUNCTION DEPLOYMENT
-- ============================================================

-- Check if clearing functions exist
SELECT proname, prosecdef FROM pg_proc
WHERE proname IN (
  'fn_clear_seat',
  'fn_clear_table_complete',
  'fn_get_seat_details',
  'fn_get_table_seat_summaries'
)
ORDER BY proname;

-- Expected output:
-- 4 rows, all with prosecdef = false (not security definer)


-- ============================================================
-- STEP 7: VERIFY PERMISSIONS
-- ============================================================

-- Check if functions are executable by anon and authenticated roles
-- This is set in SEAT_AND_TABLE_CLEAR_FUNCTIONS.sql with:
-- GRANT EXECUTE ON FUNCTION fn_clear_seat(...) TO anon, authenticated;

SELECT p.proname, 
       CASE WHEN p.proacl::text LIKE '%anon%' THEN 'Granted to anon' ELSE 'NOT granted to anon' END,
       CASE WHEN p.proacl::text LIKE '%authenticated%' THEN 'Granted to authenticated' ELSE 'NOT granted to authenticated' END
FROM pg_proc p
WHERE p.proname IN (
  'fn_clear_seat',
  'fn_clear_table_complete',
  'fn_get_seat_details',
  'fn_get_table_seat_summaries'
);


-- ============================================================
-- STEP 8: BACKFILL DATA (if needed)
-- ============================================================

-- Set business_id for table_seats if missing
UPDATE table_seats ts
SET business_id = rt.business_id
FROM restaurant_tables rt
WHERE ts.table_id = rt.id AND ts.business_id IS NULL;

-- Verify backfill
SELECT COUNT(*) as null_business_ids FROM table_seats WHERE business_id IS NULL;
-- Should return 0


-- ============================================================
-- STEP 9: TEST FUNCTIONS (in development/staging only)
-- ============================================================

-- Step 9.1: Get a test table and seat
SELECT 
  rt.id as table_id,
  ts.id as seat_id,
  ts.seat_label
FROM restaurant_tables rt
LEFT JOIN table_seats ts ON ts.table_id = rt.id
WHERE rt.business_id = 'your-business-id'
LIMIT 1;

-- Step 9.2: Test fn_get_seat_details (read-only, safe)
SELECT * FROM fn_get_seat_details('your-test-seat-id'::uuid);

-- Step 9.3: Test fn_get_table_seat_summaries (read-only, safe)
SELECT * FROM fn_get_table_seat_summaries('your-test-table-id'::uuid);

-- Step 9.4: Test fn_clear_seat (CAUTION: modifies data)
-- Only run in DEV/STAGING with test data
SELECT * FROM fn_clear_seat('your-test-table-id'::uuid, 'your-test-seat-id'::uuid);

-- Step 9.5: Test fn_clear_table_complete (CAUTION: modifies data)
-- Only run in DEV/STAGING with test data
SELECT * FROM fn_clear_table_complete('your-test-table-id'::uuid);


-- ============================================================
-- STEP 10: PRODUCTION VERIFICATION QUERY
-- ============================================================
-- Run this after deployment to verify everything is working:

SELECT 
  'Functions Deployed' as check_item,
  COUNT(*) as count
FROM pg_proc
WHERE proname IN ('fn_clear_seat', 'fn_clear_table_complete', 'fn_get_seat_details', 'fn_get_table_seat_summaries')

UNION ALL

SELECT 
  'Table Seats Records',
  COUNT(*)
FROM table_seats

UNION ALL

SELECT 
  'Restaurant Tables Records',
  COUNT(*)
FROM restaurant_tables

UNION ALL

SELECT 
  'Orders with table_seat_id',
  COUNT(*)
FROM orders
WHERE table_seat_id IS NOT NULL;


-- ============================================================
-- STEP 11: MONITORING QUERIES
-- ============================================================
-- Use these in production to monitor clearing operations:

-- Check recent clearing operations (by looking at completed orders)
SELECT 
  o.id,
  o.table_id,
  o.table_seat_id,
  o.status,
  o.updated_at
FROM orders o
WHERE o.status = 'completed'
  AND o.updated_at > NOW() - INTERVAL '1 hour'
ORDER BY o.updated_at DESC
LIMIT 20;

-- Check tables currently occupied (should return occupied seats)
SELECT 
  rt.id,
  rt.table_number,
  rt.status,
  COUNT(ts.id) as seq_count,
  SUM(CASE WHEN ts.status = 'occupied' THEN 1 ELSE 0 END) as occupied_count
FROM restaurant_tables rt
LEFT JOIN table_seats ts ON ts.table_id = rt.id
WHERE rt.status = 'occupied'
GROUP BY rt.id, rt.table_number, rt.status;

-- Check for orphaned records (seats without tables - should be none)
SELECT ts.id, ts.seat_label, ts.table_id
FROM table_seats ts
LEFT JOIN restaurant_tables rt ON rt.id = ts.table_id
WHERE rt.id IS NULL;

-- Check for orders with invalid seat_id (should be none)
SELECT o.id, o.table_seat_id
FROM orders o
LEFT JOIN table_seats ts ON ts.id = o.table_seat_id
WHERE o.table_seat_id IS NOT NULL AND ts.id IS NULL;


-- ============================================================
-- STEP 12: ROLLBACK PROCEDURE (if needed)
-- ============================================================
-- If you need to rollback, run these (ONLY in emergencies):

-- Drop functions (this will fail if views/triggers depend on them)
DROP FUNCTION IF EXISTS fn_clear_seat(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS fn_clear_table_complete(UUID) CASCADE;
DROP FUNCTION IF EXISTS fn_get_seat_details(UUID) CASCADE;
DROP FUNCTION IF EXISTS fn_get_table_seat_summaries(UUID) CASCADE;

-- Drop indexes (optional)
DROP INDEX IF EXISTS idx_seats_table CASCADE;
DROP INDEX IF EXISTS idx_seats_session CASCADE;
DROP INDEX IF EXISTS idx_tables_business CASCADE;
DROP INDEX IF EXISTS idx_orders_seat CASCADE;

-- Remove columns (CAUTION: data loss!)
-- ALTER TABLE table_seats DROP COLUMN IF EXISTS business_id;
-- ALTER TABLE table_seats DROP COLUMN IF EXISTS session_id;
-- ALTER TABLE orders DROP COLUMN IF EXISTS table_seat_id;


-- ============================================================
-- FINAL VERIFICATION (run after all steps)
-- ============================================================

-- Should return all 4 functions
SELECT COUNT(*) FROM pg_proc 
WHERE proname IN ('fn_clear_seat', 'fn_clear_table_complete', 'fn_get_seat_details', 'fn_get_table_seat_summaries');

-- Should return True for all columns
SELECT 
  (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='table_seats' AND column_name='business_id')) as has_business_id,
  (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='table_seats' AND column_name='session_id')) as has_session_id,
  (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='table_seat_id')) as has_table_seat_id,
  (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='restaurant_tables' AND column_name='session_id')) as has_table_session_id;

-- Should return 4 indexes
SELECT COUNT(*) FROM pg_indexes 
WHERE indexname IN ('idx_seats_table', 'idx_seats_session', 'idx_tables_business', 'idx_orders_seat');

-- ============================================================
-- ✅ MIGRATION COMPLETE
-- All functions deployed, schema verified, ready for production
-- ============================================================
