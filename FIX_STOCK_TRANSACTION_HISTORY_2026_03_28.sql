-- ═══════════════════════════════════════════════════════════════════════════
-- FIX: Record Stock Transactions During Inventory Deduction
-- ═══════════════════════════════════════════════════════════════════════════
-- Problem: deduct_inventory() was updating current_stock but NOT recording
--          transactions in stock_transactions table, so history screens were empty
--
-- Solution: Modify deduct_inventory() to:
--   1. Accept order_id, order_number for audit trail
--   2. Fetch cost_per_unit from inventory_items
--   3. Insert transaction record into stock_transactions
--   4. Update current_stock atomically
--
-- Result: All deductions now appear in transaction history ✓
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 1: Replace deduct_inventory function with transaction recording
DROP FUNCTION IF EXISTS deduct_inventory(UUID, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION deduct_inventory(
  p_inventory_item_id UUID,
  p_quantity NUMERIC,
  p_business_id TEXT,
  p_order_id UUID DEFAULT NULL,
  p_order_number INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_stock NUMERIC;
  v_item_name TEXT;
  v_unit TEXT;
  v_cost_per_unit NUMERIC;
  v_stock_before NUMERIC;
  v_stock_after NUMERIC;
  v_result JSON;
BEGIN
  -- ✓ Fetch current stock and item details
  SELECT 
    current_stock,
    name,
    unit::TEXT,
    COALESCE(cost_per_unit, 0)
  INTO 
    v_current_stock,
    v_item_name,
    v_unit,
    v_cost_per_unit
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

  -- Store before/after for transaction record
  v_stock_before := v_current_stock;
  v_stock_after := v_current_stock - p_quantity;

  -- ✓ Deduct inventory
  UPDATE inventory_items
  SET 
    current_stock = v_stock_after,
    last_updated = NOW()
  WHERE id = p_inventory_item_id
    AND business_id = p_business_id;

  -- ✨ KEY FIX: Record transaction in stock_transactions table
  -- This ensures history screens show all deductions
  INSERT INTO stock_transactions (
    item_id,
    business_id,
    transaction_type,
    quantity,
    stock_before,
    stock_after,
    unit,
    cost_per_unit,
    total_cost,
    note,
    updated_by_uid,
    updated_by_name,
    updated_by_role
  ) VALUES (
    p_inventory_item_id,
    p_business_id,
    'stock_out',
    p_quantity,
    v_stock_before,
    v_stock_after,
    v_unit,
    v_cost_per_unit,
    (p_quantity * v_cost_per_unit),
    CASE 
      WHEN p_order_number IS NOT NULL THEN 
        'Order #' || p_order_number::TEXT || ' consumption'
      ELSE
        'Inventory deduction'
    END,
    'system',
    'System',
    'system'
  );

  -- ✓ Return result
  SELECT 
    json_build_object(
      'inventory_item_id', p_inventory_item_id,
      'item_name', v_item_name,
      'quantity_deducted', p_quantity,
      'previous_stock', v_stock_before,
      'new_stock', v_stock_after,
      'unit', v_unit,
      'cost_per_unit', v_cost_per_unit,
      'timestamp', NOW(),
      'order_id', p_order_id,
      'order_number', p_order_number,
      'transaction_recorded', TRUE
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
GRANT EXECUTE ON FUNCTION deduct_inventory(UUID, NUMERIC, TEXT, UUID, INT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Verify function signature updated
-- SELECT routine_name, routine_definition 
-- FROM information_schema.routines 
-- WHERE routine_name = 'deduct_inventory';

-- Test: Should now create transaction record for any deduction
-- SELECT * FROM stock_transactions 
-- WHERE transaction_type = 'stock_out' 
-- ORDER BY created_at DESC LIMIT 5;
