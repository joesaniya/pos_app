-- ═══════════════════════════════════════════════════════════════════════════
--  FIX: Add missing 'created_by_role' column to recipes table
--
--  Error: PGRST204 — Could not find the 'created_by_role' column of 'recipes'
--  Cause: App tries to save recipe.created_by_role but schema is missing the column
--
--  How to run:
--   Supabase Dashboard → SQL Editor → Paste → Run
--
--  Date: 2026-03-27
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Add missing audit columns to recipes table
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS created_by_role TEXT DEFAULT 'chef';

ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS updated_by_role TEXT DEFAULT 'chef';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Create indexes for role-based filtering (if needed)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_recipes_created_by_role
  ON recipes(created_by_role);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Reload Supabase schema cache
-- ─────────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION CHECKS
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ Column added: recipes.created_by_role' AS check_1,
       EXISTS(
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'recipes' AND column_name = 'created_by_role'
       ) AS exists;

SELECT '✅ Column added: recipes.updated_by_role' AS check_2,
       EXISTS(
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'recipes' AND column_name = 'updated_by_role'
       ) AS exists;

-- ═══════════════════════════════════════════════════════════════════════════
-- FULL RECIPES TABLE SCHEMA (after fix)
-- ═══════════════════════════════════════════════════════════════════════════
-- Run this separately to verify all columns:
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'recipes'
-- ORDER BY ordinal_position;
--
-- Expected audit columns:
--  ✓ created_by_uid (TEXT)
--  ✓ created_by_name (TEXT)
--  ✓ created_by_role (TEXT) ← NEWLY ADDED
--  ✓ updated_by_uid (TEXT)
--  ✓ updated_by_name (TEXT)
--  ✓ updated_by_role (TEXT) ← NEWLY ADDED
--  ✓ created_at (TIMESTAMPTZ)
--  ✓ updated_at (TIMESTAMPTZ)
-- ═══════════════════════════════════════════════════════════════════════════
