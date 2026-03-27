-- Fix: Add/Update RLS policies for ingredient_consumption table
-- Issue 1: RLS is preventing INSERT into ingredient_consumption
-- Issue 2: Inventory deducts but consumption history is NOT recorded
-- Solution: Simple RLS policies that allow authenticated users

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: Drop ALL existing policies (clean slate)
-- ═══════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "allow_users_select_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_insert_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_update_ingredient_consumption" ON ingredient_consumption;

DROP POLICY IF EXISTS "allow_select_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_insert_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_update_ingredient_consumption" ON ingredient_consumption;

DROP POLICY IF EXISTS "allow_users_select_own_business_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_insert_own_business_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_update_own_business_ingredient_consumption" ON ingredient_consumption;

DROP POLICY IF EXISTS "allow_service_role_all_ingredient_consumption" ON ingredient_consumption;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: Ensure RLS is ENABLED on the table
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE ingredient_consumption ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: Create NEW simplified RLS policies
-- Allow any authenticated user (non-anonymous) to CRUD consumption records
-- ═══════════════════════════════════════════════════════════════════════════

-- Policy 1: SELECT - Allow authenticated users to view consumption records
CREATE POLICY "consumption_select_policy"
  ON ingredient_consumption
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND auth.uid() != '00000000-0000-0000-0000-000000000000'::uuid
  );

-- Policy 2: INSERT - Allow authenticated users to create consumption records
CREATE POLICY "consumption_insert_policy"
  ON ingredient_consumption
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND auth.uid() != '00000000-0000-0000-0000-000000000000'::uuid
  );

-- Policy 3: UPDATE - Allow authenticated users to update consumption records
CREATE POLICY "consumption_update_policy"
  ON ingredient_consumption
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND auth.uid() != '00000000-0000-0000-0000-000000000000'::uuid
  )
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND auth.uid() != '00000000-0000-0000-0000-000000000000'::uuid
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 4: OPTIONAL - If RLS still causes issues, disable it entirely
-- Uncomment the line below and run if you want to disable RLS for debugging
-- ═══════════════════════════════════════════════════════════════════════════

-- ALTER TABLE ingredient_consumption DISABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 5: Verify the fix
-- ═══════════════════════════════════════════════════════════════════════════

-- Run these SELECT queries to verify:

-- Check if policies exist:
-- SELECT tablename, policyname, permissive, cmd FROM pg_policies 
-- WHERE tablename = 'ingredient_consumption' ORDER BY policyname;

-- Check RLS status:
-- SELECT tablename, rowsecurity FROM pg_tables 
-- WHERE tablename = 'ingredient_consumption';

-- Test insert (should succeed now):
-- INSERT INTO ingredient_consumption (
--   business_id, order_id, order_number, menu_item_id, menu_item_name,
--   ingredient_id, ingredient_name, ingredient_unit, quantity_consumed, 
--   transaction_status
-- ) VALUES (
--   'POS001', 'test-id-001', 123, 'menu-id', 'Test Item',
--   'ing-id', 'Test Ingredient', 'ml', 1.0, 'completed'
-- );
-- Expected: INSERT should succeed without errors
