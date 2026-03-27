-- DIAGNOSTIC QUERIES - Run these one at a time in Supabase SQL Editor

-- STEP 1: Check if ingredient_consumption table exists
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'ingredient_consumption'
LIMIT 1;

-- Expected: Should show ingredient_consumption with rowsecurity = true

---

-- STEP 2: Check current RLS policies on ingredient_consumption
SELECT schemaname, tablename, policyname, permissive, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'ingredient_consumption'
ORDER BY policyname;

-- Expected: Should show 3 policies (select, insert, update)
-- If empty or old policies shown → SQL migration didn't apply correctly

---

-- STEP 3: If policies are NOT correct, DISABLE RLS temporarily and recreate
-- DISABLE RLS (temporary):
ALTER TABLE ingredient_consumption DISABLE ROW LEVEL SECURITY;

-- Then DROP all old policies:
DROP POLICY IF EXISTS "allow_users_select_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_insert_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_update_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_select_own_business_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_insert_own_business_ingredient_consumption" ON ingredient_consumption;
DROP POLICY IF EXISTS "allow_users_update_own_business_ingredient_consumption" ON ingredient_consumption;

-- RE-ENABLE RLS:
ALTER TABLE ingredient_consumption ENABLE ROW LEVEL SECURITY;

-- Then CREATE new policies:
CREATE POLICY "allow_select_ingredient_consumption" ON ingredient_consumption
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "allow_insert_ingredient_consumption" ON ingredient_consumption
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "allow_update_ingredient_consumption" ON ingredient_consumption
  FOR UPDATE USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

---

-- STEP 4: Verify policies now exist:
SELECT schemaname, tablename, policyname, permissive, cmd
FROM pg_policies
WHERE tablename = 'ingredient_consumption'
ORDER BY policyname;

---




