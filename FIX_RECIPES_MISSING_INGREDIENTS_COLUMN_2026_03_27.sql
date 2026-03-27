-- ═══════════════════════════════════════════════════════════════════════════
--  FIX: Add missing 'ingredients' column to recipes table
--
--  Error: PGRST204 — Could not find the 'ingredients' column of 'recipes'
--  Cause: App tries to save recipe.ingredients but schema is missing the column
--
--  How to run:
--   Supabase Dashboard → SQL Editor → Paste → Run
--
--  Date: 2026-03-27
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Add missing 'ingredients' column to recipes table
--    This stores a JSONB array of ingredients inline with the recipe
--    Mirrors the vw_recipes_with_ingredients view structure
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS ingredients JSONB DEFAULT '[]'::jsonb;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create index for ingredient searches if needed
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_recipes_ingredients
  ON recipes USING GIN(ingredients);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Reload Supabase schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION CHECKS
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ Column added: recipes.ingredients' AS check_1,
       EXISTS(
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'recipes' AND column_name = 'ingredients'
       ) AS exists;

SELECT '✅ Index created: idx_recipes_ingredients' AS check_2,
       EXISTS(
         SELECT 1 FROM pg_indexes
         WHERE tablename = 'recipes' AND indexname = 'idx_recipes_ingredients'
       ) AS exists;

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTES: 
-- 
-- The recipes table now supports TWO ways to store ingredients:
--
-- 1. DENORMALIZED (direct storage in recipes.ingredients JSONB column)
--    - App sends: { ingredients: [{id, name, unit, quantity}, ...] }
--    - Stored directly in recipes row
--    - Fast for reads, good for small ingredient lists
--
-- 2. NORMALIZED (separate recipe_ingredients table)
--    - recipe_ingredients table has one row per ingredient
--    - Foreign key: recipe_id → recipes.id
--    - Better for complex queries and ingredient inventory tracking
--    - View vw_recipes_with_ingredients joins and aggregates these
--
-- App may use one or both. The column is now provided to support both patterns.
-- ═══════════════════════════════════════════════════════════════════════════
