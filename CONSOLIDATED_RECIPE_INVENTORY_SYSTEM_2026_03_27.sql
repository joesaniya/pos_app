-- ═══════════════════════════════════════════════════════════════════════════
--  CONSOLIDATED INVENTORY CONSUMPTION SYSTEM MIGRATION
--  Complete schema for recipe-based inventory deduction
--
--  Includes:
--    ✓ Core tables: recipes, recipe_ingredients, ingredient_consumption
--    ✓ Support tables: menu_items.is_active, recipes.menu_item_id
--    ✓ Missing columns: category, ingredients, audit roles
--    ✓ Functions: validation, deduction, auditing, initialization
--    ✓ Views: recipe composition, consumption tracking
--
--  Run in: Supabase Dashboard → SQL Editor → paste all → run
--  Date: 2026-03-27
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: ENABLE SOFT DELETES ON MENU_ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE menu_items 
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_menu_items_is_active 
  ON menu_items(is_active);

CREATE INDEX IF NOT EXISTS idx_menu_items_business_is_active 
  ON menu_items(business_id, is_active);

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: ADD MISSING COLUMNS TO RECIPES
-- ═══════════════════════════════════════════════════════════════════════════

-- Link recipes to menu items
ALTER TABLE recipes 
  ADD COLUMN IF NOT EXISTS menu_item_id UUID REFERENCES menu_items(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_recipes_menu_item_id 
  ON recipes(menu_item_id);

CREATE INDEX IF NOT EXISTS idx_recipes_business_menu_item 
  ON recipes(business_id, menu_item_id);

-- Recipe category for filtering
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Other';

CREATE INDEX IF NOT EXISTS idx_recipes_category
  ON recipes(category);

CREATE INDEX IF NOT EXISTS idx_recipes_business_category
  ON recipes(business_id, category);

-- Denormalized ingredients storage (supports both denormalized + normalized patterns)
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS ingredients JSONB DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_recipes_ingredients
  ON recipes USING GIN(ingredients);

-- Recipe notes/instructions
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- Preparation time for recipes
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS preparation_time_minutes INT DEFAULT 0;

-- Recipe selling price
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS selling_price NUMERIC(10,2) DEFAULT 0;

-- Audit role tracking
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS created_by_role TEXT DEFAULT 'chef';

ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS updated_by_role TEXT DEFAULT 'chef';

CREATE INDEX IF NOT EXISTS idx_recipes_created_by_role
  ON recipes(created_by_role);


-- Featured recipes flag for UI highlighting
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_recipes_is_featured
  ON recipes(is_featured);

CREATE INDEX IF NOT EXISTS idx_recipes_business_is_featured
  ON recipes(business_id, is_featured);
-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: ENSURE RECIPE_INGREDIENTS TABLE EXISTS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  
  ingredient_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  ingredient_name TEXT NOT NULL,
  ingredient_unit TEXT NOT NULL,
  
  quantity_required NUMERIC(10,3) NOT NULL CHECK (quantity_required > 0),
  
  is_optional BOOLEAN DEFAULT FALSE,
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: ENSURE INGREDIENT_CONSUMPTION TABLE EXISTS (audit trail)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ingredient_consumption (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  order_number INT NOT NULL,
  
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  menu_item_id UUID REFERENCES menu_items(id) ON DELETE SET NULL,
  menu_item_name TEXT NOT NULL,
  
  ingredient_id UUID REFERENCES inventory_items(id) ON DELETE SET NULL,
  ingredient_name TEXT NOT NULL,
  ingredient_unit TEXT NOT NULL,
  
  quantity_consumed NUMERIC(10,3) NOT NULL,
  cost_per_unit NUMERIC(10,2),
  total_cost NUMERIC(10,2),
  
  transaction_status TEXT DEFAULT 'completed'
    CHECK (transaction_status IN ('pending', 'completed', 'failed')),
  
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consumption_business ON ingredient_consumption(business_id);
CREATE INDEX IF NOT EXISTS idx_consumption_order ON ingredient_consumption(order_id);
CREATE INDEX IF NOT EXISTS idx_consumption_ingredient ON ingredient_consumption(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_consumption_created ON ingredient_consumption(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: DISABLE RLS (Firebase Auth isolation in app layer)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE recipes DISABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients DISABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_consumption DISABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: SAFE REALTIME PUBLICATION
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'recipes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE recipes;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'ingredient_consumption'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ingredient_consumption;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: ORDER VALIDATION FUNCTION
--   Pre-order stock validation before order confirmation
--   Returns: success, can_place, blocked_count, blocking_items
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_validate_order_ingredients(
  p_business_id TEXT,
  p_cart_items JSONB  -- [{menu_item_id: uuid, quantity: int}, ...]
)
RETURNS TABLE (
  success BOOLEAN,
  can_place BOOLEAN,
  blocked_count INT,
  blocking_items JSONB
) AS $$
DECLARE
  v_item JSONB;
  v_menu_item_id UUID;
  v_quantity INT;
  v_recipe_id UUID;
  v_ingredient_id UUID;
  v_ingredient_name TEXT;
  v_ingredient_unit TEXT;
  v_required_qty NUMERIC;
  v_available_qty NUMERIC;
  v_is_optional BOOLEAN;
  v_blocking_items JSONB := '[]'::jsonb;
  v_blocked_count INT := 0;
BEGIN
  FOR v_item IN (SELECT jsonb_array_elements(p_cart_items))
  LOOP
    v_menu_item_id := (v_item->>'menu_item_id')::UUID;
    v_quantity := (v_item->>'quantity')::INT;
    
    SELECT id INTO v_recipe_id
    FROM recipes
    WHERE menu_item_id = v_menu_item_id
      AND business_id = p_business_id
      AND is_active = TRUE
    LIMIT 1;
    
    IF v_recipe_id IS NULL THEN
      CONTINUE;
    END IF;
    
    FOR v_ingredient_id, v_ingredient_name, v_ingredient_unit, v_required_qty, v_is_optional
    IN
      SELECT ri.ingredient_id, ri.ingredient_name, ri.ingredient_unit, 
             ri.quantity_required, ri.is_optional
      FROM recipe_ingredients ri
      WHERE ri.recipe_id = v_recipe_id
    LOOP
      SELECT current_stock INTO v_available_qty
      FROM inventory_items
      WHERE id = v_ingredient_id;
      
      v_available_qty := COALESCE(v_available_qty, 0);
      
      DECLARE
        v_total_needed NUMERIC;
      BEGIN
        v_total_needed := v_required_qty * v_quantity;
        
        IF v_total_needed > v_available_qty AND NOT v_is_optional THEN
          v_blocking_items := v_blocking_items || jsonb_build_object(
            'menu_item_id', v_menu_item_id::TEXT,
            'ingredient_id', v_ingredient_id::TEXT,
            'ingredient_name', v_ingredient_name,
            'ingredient_unit', v_ingredient_unit,
            'required', v_total_needed,
            'available', v_available_qty
          );
          v_blocked_count := v_blocked_count + 1;
        END IF;
      END;
    END LOOP;
  END LOOP;
  
  RETURN QUERY
  SELECT
    true::BOOLEAN,
    (v_blocked_count = 0)::BOOLEAN,
    v_blocked_count,
    v_blocking_items;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8: RECORDING FUNCTION
--   Record ingredient consumption for audit trail
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_record_ingredient_consumption(
  p_business_id TEXT,
  p_order_id UUID,
  p_order_number INT,
  p_recipe_id UUID,
  p_menu_item_id UUID,
  p_menu_item_name TEXT,
  p_ingredient_id UUID,
  p_ingredient_name TEXT,
  p_ingredient_unit TEXT,
  p_quantity_consumed NUMERIC,
  p_cost_per_unit NUMERIC DEFAULT 0,
  p_notes TEXT DEFAULT ''
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_total_cost NUMERIC;
BEGIN
  v_total_cost := p_quantity_consumed * COALESCE(p_cost_per_unit, 0);
  
  INSERT INTO ingredient_consumption (
    business_id, order_id, order_number, recipe_id, menu_item_id, menu_item_name,
    ingredient_id, ingredient_name, ingredient_unit, quantity_consumed, 
    cost_per_unit, total_cost, notes
  ) VALUES (
    p_business_id, p_order_id, p_order_number, p_recipe_id, p_menu_item_id, p_menu_item_name,
    p_ingredient_id, p_ingredient_name, p_ingredient_unit, p_quantity_consumed,
    p_cost_per_unit, v_total_cost, p_notes
  )
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 9: INVENTORY DEDUCTION FUNCTION
--   Post-order stock reduction. Atomically updates stock + records audit trail.
--   Called AFTER order is created
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_deduct_inventory_for_order(
  p_business_id TEXT,
  p_order_id UUID,
  p_order_number INT,
  p_cart_items JSONB
)
RETURNS TABLE (
  success BOOLEAN,
  deducted_count INT,
  errors JSONB
) AS $$
DECLARE
  v_item JSONB;
  v_menu_item_id UUID;
  v_quantity INT;
  v_recipe_id UUID;
  v_menu_item_name TEXT;
  v_ingredient_id UUID;
  v_ingredient_name TEXT;
  v_ingredient_unit TEXT;
  v_required_qty NUMERIC;
  v_available_qty NUMERIC;
  v_stock_before NUMERIC;
  v_stock_after NUMERIC;
  v_cost_per_unit NUMERIC;
  v_deducted INT := 0;
  v_errors JSONB := '[]'::jsonb;
  v_total_needed NUMERIC;
BEGIN
  FOR v_item IN (SELECT jsonb_array_elements(p_cart_items))
  LOOP
    v_menu_item_id := (v_item->>'menu_item_id')::UUID;
    v_quantity := (v_item->>'quantity')::INT;
    
    SELECT id, name INTO v_recipe_id, v_menu_item_name
    FROM recipes
    WHERE menu_item_id = v_menu_item_id
      AND business_id = p_business_id
      AND is_active = TRUE
    LIMIT 1;
    
    IF v_recipe_id IS NULL THEN
      CONTINUE;
    END IF;
    
    FOR v_ingredient_id, v_ingredient_name, v_ingredient_unit, v_required_qty
    IN
      SELECT ri.ingredient_id, ri.ingredient_name, ri.ingredient_unit, ri.quantity_required
      FROM recipe_ingredients ri
      WHERE ri.recipe_id = v_recipe_id
    LOOP
      SELECT current_stock, cost_per_unit 
      INTO v_available_qty, v_cost_per_unit
      FROM inventory_items
      WHERE id = v_ingredient_id;
      
      v_available_qty := COALESCE(v_available_qty, 0);
      v_cost_per_unit := COALESCE(v_cost_per_unit, 0);
      v_total_needed := v_required_qty * v_quantity;
      v_stock_before := v_available_qty;
      
      UPDATE inventory_items
      SET current_stock = current_stock - v_total_needed,
          last_updated = NOW()
      WHERE id = v_ingredient_id;
      
      SELECT current_stock INTO v_stock_after
      FROM inventory_items
      WHERE id = v_ingredient_id;
      
      v_stock_after := COALESCE(v_stock_after, 0);
      
      PERFORM fn_record_ingredient_consumption(
        p_business_id, p_order_id, p_order_number, v_recipe_id, v_menu_item_id, v_menu_item_name,
        v_ingredient_id, v_ingredient_name, v_ingredient_unit, v_total_needed,
        v_cost_per_unit, 'Automatic deduction for order #' || p_order_number
      );
      
      INSERT INTO stock_transactions (
        item_id, business_id, transaction_type, quantity, stock_before, stock_after, unit,
        cost_per_unit, total_cost, note, updated_by_uid, updated_by_name, updated_by_role
      ) VALUES (
        v_ingredient_id, p_business_id, 'stock_out', v_total_needed, v_stock_before, v_stock_after,
        v_ingredient_unit, v_cost_per_unit, (v_total_needed * v_cost_per_unit),
        'Order #' || p_order_number || ' consumption', 'system', 'System', 'system'
      );
      
      v_deducted := v_deducted + 1;
    END LOOP;
  END LOOP;
  
  RETURN QUERY
  SELECT
    (array_length(string_to_array(v_errors::TEXT, ','), 1) IS NULL)::BOOLEAN,
    v_deducted,
    v_errors;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 10: AUTO-INITIALIZATION FUNCTION
--   Create placeholder recipes for menu items without recipes
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION fn_auto_initialize_recipes(
  p_business_id TEXT
)
RETURNS TABLE (
  created_count INT,
  already_exist INT,
  total_menu_items INT
) AS $$
DECLARE
  v_created INT := 0;
  v_existing INT := 0;
  v_total INT := 0;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM menu_items
  WHERE business_id = p_business_id;

  SELECT COUNT(*) INTO v_existing
  FROM recipes
  WHERE business_id = p_business_id;

  INSERT INTO recipes (business_id, menu_item_id, menu_item_name, name, description, is_active, created_by_uid, created_by_name)
  SELECT
    p_business_id,
    mi.id,
    mi.name,
    mi.name || ' (Placeholder)',
    'Auto-generated placeholder recipe for ' || mi.name || '. Customize by adding ingredients.',
    TRUE,
    'system',
    'System'
  FROM menu_items mi
  WHERE mi.business_id = p_business_id
    AND NOT EXISTS (
      SELECT 1 FROM recipes r
      WHERE r.menu_item_id = mi.id
        AND r.business_id = p_business_id
    );

  GET DIAGNOSTICS v_created = ROW_COUNT;

  RETURN QUERY
  SELECT v_created AS created_count, v_existing AS already_exist, v_total AS total_menu_items;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 11: VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW vw_recipes_with_ingredients AS
SELECT
  r.id,
  r.business_id,
  r.menu_item_id,
  r.menu_item_name,
  r.name,
  r.description,
  r.serving_size,
  r.allergens,
  r.nutritional_info,
  r.is_active,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', ri.id,
        'ingredient_id', ri.ingredient_id::TEXT,
        'ingredient_name', ri.ingredient_name,
        'ingredient_unit', ri.ingredient_unit,
        'quantity_required', ri.quantity_required,
        'is_optional', ri.is_optional,
        'notes', ri.notes
      ) ORDER BY ri.created_at
    ) FILTER (WHERE ri.id IS NOT NULL),
    '[]'::jsonb
  ) AS ingredients,
  r.created_at,
  r.updated_at
FROM recipes r
LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.id
GROUP BY r.id;

CREATE OR REPLACE VIEW vw_order_ingredient_consumption AS
SELECT
  business_id,
  order_id,
  order_number,
  COUNT(*) AS ingredient_count,
  SUM(quantity_consumed) AS total_consumed,
  SUM(total_cost) AS total_consumption_cost,
  MAX(created_at) AS last_updated
FROM ingredient_consumption
GROUP BY business_id, order_id, order_number;

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 12: SCHEMA CACHE RELOAD & VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 
  '✅ Menu Items: is_active column' :: TEXT AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='menu_items' AND column_name='is_active') AS status;

SELECT 
  '✅ Recipes: category column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='category') AS status;

SELECT 
  '✅ Recipes: ingredients column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='ingredients') AS status;


SELECT 
  '✅ Recipes: notes column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='notes') AS status;


SELECT 
  '✅ Recipes: preparation_time_minutes column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='preparation_time_minutes') AS status;

SELECT 
  '✅ Recipes: selling_price column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='selling_price') AS status;

SELECT 
  '✅ Recipes: created_by_role column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='created_by_role') AS status;

SELECT 
  '✅ Recipes: updated_by_role column' AS step,
  EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='updated_by_role') AS status;

SELECT 
  '✅ Table: recipe_ingredients' AS step,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='recipe_ingredients') AS status;

SELECT 
  '✅ Table: ingredient_consumption' AS step,
  EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='ingredient_consumption') AS status;

SELECT 
  '✅ Function: fn_validate_order_ingredients' AS step,
  EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='public' AND p.proname='fn_validate_order_ingredients') AS status;

SELECT 
  '✅ Function: fn_deduct_inventory_for_order' AS step,
  EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='public' AND p.proname='fn_deduct_inventory_for_order') AS status;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- ✓ Section 1: Menu Items soft-delete support (is_active column)
-- ✓ Section 2: Missing recipe columns added:
--   - menu_item_id (FK to menu_items)
--   - category (TEXT)
--   - ingredients (JSONB denormalized storage)
--   - notes (TEXT for instructions/metadata)
--   - preparation_time_minutes (INT for cooking time)
--   - selling_price (NUMERIC for menu price)
--   - created_by_role, updated_by_role (TEXT audit fields)
--   - is_featured (BOOLEAN for UI highlighting)
-- ✓ Section 3: recipe_ingredients table (normalized ingredient storage)
-- ✓ Section 4: ingredient_consumption table (audit trail)
-- ✓ Section 5: RLS disabled (Firebase Auth in app layer)
-- ✓ Section 6: Realtime publications for recipes + consumption
-- ✓ Section 7: fn_validate_order_ingredients() — pre-order stock validation
-- ✓ Section 8: fn_record_ingredient_consumption() — audit logging
-- ✓ Section 9: fn_deduct_inventory_for_order() — atomic stock reduction
-- ✓ Section 10: fn_auto_initialize_recipes() — batch recipe creation
-- ✓ Section 11: Views for recipe composition + consumption tracking
-- ✓ Section 12: Verification checks + PostgREST schema reload
--
-- ═══════════════════════════════════════════════════════════════════════════
