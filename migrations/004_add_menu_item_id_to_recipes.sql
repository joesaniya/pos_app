-- Add menu_item_id column to recipes table to link recipes to menu items
-- This allows proper recipe-to-menu-item relationship for inventory deduction

ALTER TABLE recipes 
ADD COLUMN IF NOT EXISTS menu_item_id UUID REFERENCES menu_items(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_recipes_menu_item_id 
ON recipes(menu_item_id);

-- Create index for business + menu_item lookup
CREATE INDEX IF NOT EXISTS idx_recipes_business_menu_item 
ON recipes(business_id, menu_item_id);

-- Update existing recipes to have menu_item_id derived from id pattern
-- If recipe id is 'recipe_<menu_item_id>', extract and link
UPDATE recipes 
SET menu_item_id = (
  CAST(SUBSTRING(id::text FROM 8) AS UUID)
)
WHERE menu_item_id IS NULL 
AND id::text LIKE 'recipe_%'
AND SUBSTRING(id::text FROM 8) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';