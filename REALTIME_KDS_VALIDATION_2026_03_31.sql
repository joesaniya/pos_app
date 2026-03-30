-- ═══════════════════════════════════════════════════════════════════════════════
-- SQL Validation Script: Verify Real-Time KDS Implementation Deployment
-- Run this in Supabase SQL Editor to verify all components are correctly deployed
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. VERIFY ALL 6 TABLES EXIST
-- ═══════════════════════════════════════════════════════════════════════════════

-- Check that all required tables exist
SELECT 
  table_name,
  CASE 
    WHEN table_name IN ('order_kot_mapping', 'kitchen_routing_rules', 'order_item_kitchen_map',
                        'sync_event_queue', 'sync_status_tracking', 'status_change_log')
    THEN 'REQUIRED'
    ELSE 'EXTRA'
  END as table_status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'order_kot_mapping', 
    'kitchen_routing_rules', 
    'order_item_kitchen_map',
    'sync_event_queue', 
    'sync_status_tracking', 
    'status_change_log'
  )
ORDER BY table_name;
-- Expected: 6 rows, all with table_status = 'REQUIRED'

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. VERIFY order_item_kitchen_map TABLE HAS kitchen_id COLUMN (CRITICAL FIX)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'order_item_kitchen_map'
ORDER BY ordinal_position;
-- Expected: 10 columns including kitchen_id (TEXT, NOT NULL)

-- Specifically check for kitchen_id column:
SELECT COUNT(*) as kitchen_id_column_exists
FROM information_schema.columns 
WHERE table_name = 'order_item_kitchen_map' 
  AND column_name = 'kitchen_id'
  AND data_type = 'text';
-- Expected: 1 (column exists)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. VERIFY ALL REQUIRED VIEWS EXIST
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  table_name as view_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'VIEW'
  AND table_name IN ('vw_order_kot_sync_state', 'vw_kitchen_routing_summary', 'vw_orders_pending_sync')
ORDER BY table_name;
-- Expected: 3 rows (all 3 views)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. VERIFY ALL REQUIRED INDEXES ARE CREATED
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN (
    'order_kot_mapping',
    'kitchen_routing_rules', 
    'order_item_kitchen_map',
    'sync_event_queue',
    'sync_status_tracking',
    'status_change_log'
  )
ORDER BY tablename, indexname;
-- Expected: All indexes for all 6 tables

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. VERIFY TRIGGERS ARE CREATED (if any auto-creation triggers exist)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
-- Shows all triggers in the database

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. VERIFY FUNCTIONS/PROCEDURES ARE CREATED (if any complex logic exists)
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
ORDER BY routine_name;
-- Shows all functions/procedures

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. TEST COLUMN REFERENCES IN VIEWS (CRITICAL: Test the fix)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Try to query the view that was failing - this will error if kitchen_id is missing
SELECT COUNT(*) as test_view_access
FROM public.vw_order_kot_sync_state;
-- Expected: Success (number of rows)

-- Try the other view as well:
SELECT COUNT(*) as test_routing_view
FROM public.vw_kitchen_routing_summary;
-- Expected: Success (number of rows)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. SUMMARY - DEPLOYMENT STATUS
-- ═══════════════════════════════════════════════════════════════════════════════

SELECT 
  'Tables' as component,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 6 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN (
    'order_kot_mapping', 
    'kitchen_routing_rules', 
    'order_item_kitchen_map',
    'sync_event_queue', 
    'sync_status_tracking', 
    'status_change_log'
  )

UNION ALL

SELECT 
  'Views' as component,
  COUNT(*) as count,
  CASE WHEN COUNT(*) >= 2 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'VIEW'
  AND table_name LIKE 'vw_%'

UNION ALL

SELECT 
  'kitchen_id column' as component,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 1 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.columns 
WHERE table_name = 'order_item_kitchen_map' 
  AND column_name = 'kitchen_id';

-- ═══════════════════════════════════════════════════════════════════════════════
-- ✅ IF ALL QUERIES PASS WITH EXPECTED RESULTS, DEPLOYMENT IS SUCCESSFUL
-- ═══════════════════════════════════════════════════════════════════════════════
