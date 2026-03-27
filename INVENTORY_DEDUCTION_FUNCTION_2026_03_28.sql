-- ═══════════════════════════════════════════════════════════════════════════
-- INVENTORY DEDUCTION FUNCTION & MIGRATION
-- Date: 2026-03-28
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: deduct_inventory
-- ─────────────────────────────────────────────────────────────────────────
-- Atomically deducts inventory and updates current_stock
-- Throws error if:
--   - Stock is insufficient
--   - Inventory item not found
--   - Invalid parameters
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION deduct_inventory(
  p_inventory_item_id UUID,
  p_quantity NUMERIC,
  p_business_id TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_stock NUMERIC;
  v_item_name TEXT;
  v_result JSON;
BEGIN
  -- ✓ Fetch current stock and item details
  SELECT 
    current_stock,
    name
  INTO 
    v_current_stock,
    v_item_name
  FROM inventory_items
  WHERE id = p_inventory_item_id
    AND business_id = p_business_id
    AND is_active = true
  FOR UPDATE; -- Lock row for atomic operation

  -- ✗ Check if item exists
  IF v_current_stock IS NULL THEN
    RAISE EXCEPTION 'Inventory item not found: %', p_inventory_item_id;
  END IF;

  -- ✗ Check if stock is sufficient
  IF v_current_stock < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock for %. Required: %, Available: %',
      v_item_name,
      p_quantity,
      v_current_stock;
  END IF;

  -- ✓ Deduct inventory
  UPDATE inventory_items
  SET 
    current_stock = current_stock - p_quantity,
    last_updated = NOW()
  WHERE id = p_inventory_item_id
    AND business_id = p_business_id;

  -- ✓ Get updated stock
  SELECT 
    json_build_object(
      'inventory_item_id', p_inventory_item_id,
      'item_name', v_item_name,
      'quantity_deducted', p_quantity,
      'previous_stock', v_current_stock,
      'new_stock', v_current_stock - p_quantity,
      'timestamp', NOW()
    )
  INTO v_result;

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  -- Log and re-raise error
  RAISE EXCEPTION 'Inventory deduction failed for %: %', 
    p_inventory_item_id, 
    SQLERRM;
END;
$$;

-- ✓ Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION deduct_inventory(UUID, NUMERIC, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- AUDIT FUNCTION: update_consumption_status
-- ─────────────────────────────────────────────────────────────────────────
-- Updates ingredient consumption transaction status after deduction
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_consumption_status(
  p_order_id UUID,
  p_status TEXT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE ingredient_consumption
  SET 
    transaction_status = p_status,
    updated_at = NOW()
  WHERE order_id = p_order_id
    AND transaction_status != p_status;

  RETURN ROW_COUNT;
END;
$$;

GRANT EXECUTE ON FUNCTION update_consumption_status(UUID, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEANUP: Remove duplicate functions if they exist multiple times
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop old versions if they exist (prevents conflicts)
DROP FUNCTION IF EXISTS deduct_inventory(TEXT, NUMERIC, TEXT) CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES (Run these to confirm setup)
-- ═══════════════════════════════════════════════════════════════════════════

-- Verify function exists and is accessible
-- SELECT proname FROM pg_proc 
-- WHERE proname = 'deduct_inventory' 
-- AND proisecurity = true;

-- Verify tables are properly set up
-- SELECT 
--   EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'ingredient_consumption') as consumption_exists,
--   EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'inventory_items' AND column_name = 'current_stock') as stock_column_exists,
--   EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'recipes' AND column_name = 'menu_item_id') as recipe_menu_link_exists;
