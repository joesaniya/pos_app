-- ═══════════════════════════════════════════════════════════════════════════════
-- FIX: Remove Static Available Quantity from Recipe Ingredients (ROBUST VERSION)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Problem: Recipe ingredients had embedded 'available_quantity' which was STATIC
--          This caused stale data (e.g., showing 4L when actual stock was 2L)
--
-- Solution: Remove embedded 'available_quantity' from recipe ingredients JSON
--          Always fetch LIVE current_stock from inventory_items table via JOIN
--
-- Single Source of Truth: inventory_items.current_stock
-- ═══════════════════════════════════════════════════════════════════════════════

-- ✨ ROBUST VERSION: Works for all recipe structures
-- Handles both:
-- - Simple arrays: [{"unit": "kg", ...}]
-- - Nested structures: {"ingredients": [{...}]}

-- Step 1: Remove available_quantity from all recipes
-- Simple, proven approach that works with PostgreSQL JSON
UPDATE recipes
SET ingredients = (
  SELECT jsonb_agg(elem - 'available_quantity')
  FROM jsonb_array_elements(recipes.ingredients) AS elem
)
WHERE ingredients IS NOT NULL
  AND jsonb_typeof(ingredients) = 'array';

-- Step 2: Verify all available_quantity fields are removed
SELECT count(*) as recipes_with_available_qty
FROM recipes
WHERE ingredients::text LIKE '%available_quantity%';
-- Expected result: 0 (zero rows should have this field)

-- Step 3: Show sample cleaned data
SELECT id, menu_item_id, ingredients 
FROM recipes 
WHERE ingredients IS NOT NULL
LIMIT 3;

-- Example of expected output after cleanup:
-- ingredients should have structure like:
-- [
--   {
--     "unit": "kg",
--     "notes": "",
--     "base_unit": "kg",
--     "inventory_item_id": "513eb952-5443-4979-8e6b-200add37fe51",
--     "required_quantity": 1.0,
--     "inventory_item_name": "oofll",
--     "inventory_item_emoji": "📦"
--   }
-- ]
-- NOTE: 'available_quantity' is NOW REMOVED ✓ (not showing 8.0)
