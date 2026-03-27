-- ═══════════════════════════════════════════════════════════════════════════
--  FIX: Add missing 'category' column to recipes table
--
--  Error: PGRST204 — Could not find the 'category' column of 'recipes'
--  Cause: App tries to save recipe.category but schema is missing the column
--
--  How to run:
--   Supabase Dashboard → SQL Editor → Paste → Run
--
--  Date: 2026-03-27
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Add missing 'category' column to recipes table
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Other';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create index for recipe category lookups (for filtering by category)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_recipes_category
  ON recipes(category);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Create composite index for business + category queries (common pattern)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_recipes_business_category
  ON recipes(business_id, category);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Ensure all expected columns are present (verify schema)
-- ─────────────────────────────────────────────────────────────────────────────
-- Run this separately to verify all columns exist:
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'recipes'
-- ORDER BY ordinal_position;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Reload Supabase schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION CHECKS
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ Column added: recipes.category' AS check_1,
       EXISTS(
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'recipes' AND column_name = 'category'
       ) AS exists;

SELECT '✅ Index created: idx_recipes_category' AS check_2,
       EXISTS(
         SELECT 1 FROM pg_indexes
         WHERE tablename = 'recipes' AND indexname = 'idx_recipes_category'
       ) AS exists;

SELECT '✅ Index created: idx_recipes_business_category' AS check_3,
       EXISTS(
         SELECT 1 FROM pg_indexes
         WHERE tablename = 'recipes' AND indexname = 'idx_recipes_business_category'
       ) AS exists;

-- ═══════════════════════════════════════════════════════════════════════════
-- FULL RECIPES TABLE SCHEMA (after fix)
-- ═══════════════════════════════════════════════════════════════════════════
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'recipes'
-- ORDER BY ordinal_position;
--
-- Expected columns:
--  ✓ id (UUID)
--  ✓ business_id (TEXT)
--  ✓ menu_item_id (UUID) — links to menu_items
--  ✓ menu_item_name (TEXT)
--  ✓ name (TEXT)
--  ✓ description (TEXT)
--  ✓ serving_size (TEXT)
--  ✓ category (TEXT) ← NEWLY ADDED
--  ✓ allergens (TEXT[])
--  ✓ nutritional_info (JSONB)
--  ✓ is_active (BOOLEAN)
--  ✓ created_by_uid (TEXT)
--  ✓ created_by_name (TEXT)
--  ✓ updated_by_uid (TEXT)
--  ✓ updated_by_name (TEXT)
--  ✓ created_at (TIMESTAMPTZ)
--  ✓ updated_at (TIMESTAMPTZ)
-- ═══════════════════════════════════════════════════════════════════════════
