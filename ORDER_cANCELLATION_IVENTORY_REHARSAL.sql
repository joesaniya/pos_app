-- ═══════════════════════════════════════════════════════════════════════════
-- ORDER CANCELLATION WITH INVENTORY REVERSAL SYSTEM (2026-03-28)
-- ═══════════════════════════════════════════════════════════════════════════
-- Purpose: When orders are cancelled, intelligently revert inventory based 
--          on order processing status to prevent food waste
--
-- Key Logic:
--   CREATED/PLACED/PENDING → Revert ALL inventory (not yet preparing)
--   PREPARING/READY/COMPLETED → DO NOT revert (ingredients being used/consumed)
--   CANCELLED → Revert inventory according to policies above
--
-- Database Requirements:
--   1. ingredient_consumption table tracks what was consumed per order
--   2. stock_transactions table records all deductions
--   3. inventory_items tracks current_stock
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION 1: revert_inventory_for_order
-- ─────────────────────────────────────────────────────────────────────────
-- Reverts inventory consumption for a specific order IF it's in a pre-processing state
-- Called when order is cancelled BEFORE kitchen processing begins
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION revert_inventory_for_order(
  p_order_id UUID,
  p_order_status TEXT,
  p_business_id TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  reverted_items INT,
  failed_items INT,
  message TEXT
) AS $$
DECLARE
  v_reverted INT := 0;
  v_failed INT := 0;
  v_message TEXT := '';
  v_consumption RECORD;
  v_current_stock NUMERIC;
  v_new_stock NUMERIC;
  v_item_name TEXT;
  v_cost_per_unit NUMERIC;
BEGIN
  -- ✅ POLICY: Only revert if order is in pre-processing or early kitchen status
  -- CREATED = not yet placed, safe to revert
  -- PLACED = just placed, kitchen not yet started, safe to revert
  -- PENDING = in kitchen queue but not yet preparing, can revert before prep
  -- PREPARING/READY/COMPLETED = ingredients being used or already used, cannot revert
  
  IF p_order_status NOT IN ('created', 'placed', 'pending') THEN
    RETURN QUERY SELECT 
      FALSE::BOOLEAN,
      0::INT,
      0::INT,
      'Cannot revert: Order status is ' || p_order_status || 
      ' (only CREATED/PLACED/PENDING orders can be reverted before preparation begins)'::TEXT;
    RETURN;
  END IF;

  -- ✅ STEP 1: Fetch all consumption records for this order
  FOR v_consumption IN 
    SELECT 
      ingredient_id,
      ingredient_name,
      quantity_consumed,
      ingredient_unit
    FROM ingredient_consumption
    WHERE order_id = p_order_id
      AND business_id = p_business_id
      AND transaction_status = 'completed'
  LOOP
    BEGIN
      -- ✅ STEP 2: Get current stock + cost for reversal
      SELECT 
        current_stock,
        name,
        cost_per_unit
      INTO 
        v_current_stock,
        v_item_name,
        v_cost_per_unit
      FROM inventory_items
      WHERE id = v_consumption.ingredient_id
        AND business_id = p_business_id
        AND is_active = true;

      IF v_current_stock IS NULL THEN
        v_failed := v_failed + 1;
        v_message := v_message || 'Item not found: ' || v_consumption.ingredient_name || '; ';
        CONTINUE;
      END IF;

      -- ✅ STEP 3: Calculate new stock (add back)
      v_new_stock := v_current_stock + v_consumption.quantity_consumed;

      -- ✅ STEP 4: Update inventory
      UPDATE inventory_items
      SET 
        current_stock = v_new_stock,
        last_updated = NOW()
      WHERE id = v_consumption.ingredient_id
        AND business_id = p_business_id;

      -- ✅ STEP 5: Create reversal transaction record (for audit)
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
        v_consumption.ingredient_id,
        p_business_id,
        'stock_in',  -- Reversal is recorded as stock_in (opposite of deduction)
        v_consumption.quantity_consumed,
        v_current_stock,
        v_new_stock,
        v_consumption.ingredient_unit,
        v_cost_per_unit,
        (v_consumption.quantity_consumed * v_cost_per_unit),
        'Order #' || (SELECT order_number FROM orders WHERE id = p_order_id) || 
        ' cancellation reversal',
        'system',
        'System',
        'system'
      );

      -- ✅ STEP 6: Mark consumption as reverted
      UPDATE ingredient_consumption
      SET transaction_status = 'reverted'
      WHERE order_id = p_order_id
        AND ingredient_id = v_consumption.ingredient_id;

      v_reverted := v_reverted + 1;

    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
      v_message := v_message || 'Error reverting ' || v_consumption.ingredient_name || ': ' || SQLERRM || '; ';
    END;
  END LOOP;

  -- ✅ Return result
  RETURN QUERY SELECT 
    (v_failed = 0)::BOOLEAN,
    v_reverted,
    v_failed,
    CASE 
      WHEN v_reverted > 0 AND v_failed = 0 THEN 
        'Successfully reverted ' || v_reverted || ' ingredient(s)'
      WHEN v_reverted > 0 AND v_failed > 0 THEN 
        'Partially reverted: ' || v_reverted || ' success, ' || v_failed || ' failed. ' || v_message
      WHEN v_reverted = 0 AND v_failed = 0 THEN
        'No consumption records found to revert'
      ELSE
        'Failed to revert ' || v_failed || ' item(s). ' || v_message
    END;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    FALSE::BOOLEAN,
    0::INT,
    1::INT,
    'Reversal failed: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Grant permission
GRANT EXECUTE ON FUNCTION revert_inventory_for_order(UUID, TEXT, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION 2: update_order_status_with_reversal
-- ─────────────────────────────────────────────────────────────────────────
-- Updates order status and handles inventory reversal if cancelling
-- Atomically updates the order AND reverts inventory (if applicable)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_order_status_with_reversal(
  p_order_id UUID,
  p_old_status TEXT,
  p_new_status TEXT,
  p_business_id TEXT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  v_reversal_success BOOLEAN;
  v_reverted_count INT;
  v_order_number INT;
  v_result JSON;
BEGIN
  -- ✅ STEP 1: Get order number for reference
  SELECT order_number INTO v_order_number
  FROM orders WHERE id = p_order_id;

  -- ✅ STEP 2: If order is being cancelled, try to revert inventory
  -- Reversal allowed for: created, placed, pending (before preparation starts)
  IF p_new_status = 'cancelled' AND p_old_status IN ('created', 'placed', 'pending') THEN
    -- Call reversal function
    SELECT success, reverted_items 
    INTO v_reversal_success, v_reverted_count
    FROM revert_inventory_for_order(p_order_id, p_old_status, p_business_id);
  ELSE
    v_reversal_success := TRUE;
    v_reverted_count := 0;
  END IF;

  -- ✅ STEP 3: Update order status in orders table
  UPDATE orders
  SET 
    status = p_new_status,
    updated_at = NOW()
  WHERE id = p_order_id
    AND business_id = p_business_id;

  -- ✅ STEP 4: Return comprehensive result
  SELECT json_build_object(
    'success', TRUE,
    'order_id', p_order_id,
    'order_number', v_order_number,
    'old_status', p_old_status,
    'new_status', p_new_status,
    'inventory_reverted', v_reversal_success,
    'items_reverted', v_reverted_count,
    'timestamp', NOW()
  ) INTO v_result;

  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', FALSE,
    'error', SQLERRM,
    'order_id', p_order_id
  );
END;
$$;

-- Grant permission
GRANT EXECUTE ON FUNCTION update_order_status_with_reversal(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION 3: check_order_revertible_status
-- ─────────────────────────────────────────────────────────────────────────
-- Before displaying "Cancel" button, check if order is still revertible
-- Returns TRUE if status allows inventory reversal (CREATED/PLACED only)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION check_order_revertible_status(
  p_order_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- ✅ CREATED, PLACED, and PENDING orders can have inventory reverted
  -- Once in PREPARING/READY/COMPLETED, ingredients are being used/consumed so cannot revert
  RETURN p_order_status IN ('created', 'placed', 'pending');
END;
$$;

-- Grant permission
GRANT EXECUTE ON FUNCTION check_order_revertible_status(TEXT) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- DIAGNOSTIC 1: Check if ingredient_consumption records exist for an order
-- Run this AFTER placing an order to see if consumption records were created
-- SELECT 
--   order_id, 
--   order_number, 
--   ingredient_name, 
--   quantity_consumed, 
--   transaction_status,
--   created_at
-- FROM ingredient_consumption
-- WHERE order_number = 14  -- Replace with your order number
-- ORDER BY created_at DESC;

-- DIAGNOSTIC 2: Check all records by business and transaction status
-- SELECT 
--   business_id,
--   order_number,
--   COUNT(*) as consumption_count,
--   json_agg(json_build_object(
--     'ingredient', ingredient_name,
--     'qty', quantity_consumed,
--     'status', transaction_status
--   )) as details
-- FROM ingredient_consumption
-- WHERE business_id = 'POS001'  -- Replace with your business ID
-- GROUP BY business_id, order_number
-- ORDER BY MAX(created_at) DESC;

-- DIAGNOSTIC 3: Verify reversal function works manually
-- SELECT * FROM revert_inventory_for_order(
--   'ORDER_UUID_HERE'::uuid,
--   'pending',
--   'POS001'
-- );

-- Test 2: List all stock_in/stock_out transactions (should see reversals)
-- SELECT item_id, transaction_type, quantity, stock_before, stock_after, 
--        note, created_at
-- FROM stock_transactions
-- WHERE item_id = 'INGREDIENT_ID'
-- ORDER BY created_at DESC LIMIT 10;

-- ═══════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT CHECKLIST
-- ═══════════════════════════════════════════════════════════════════════════
-- ✓ 1. RLS policies on ingredient_consumption allow authenticated inserts
--        (use FIX_INGREDIENT_CONSUMPTION_RLS_2026_03_28.sql)
-- ✓ 2. stock_transactions records all deductions with order_number reference
--        (use FIX_STOCK_TRANSACTION_HISTORY_2026_03_28.sql)
-- ✓ 3. ingredient_consumption table exists with transaction_status column
-- ✓ 4. This SQL file: CREATE/REPLACE the three functions above
-- ✓ 5. Dart code: Call revert_inventory_for_order() when cancelOrder is invoked
-- ═══════════════════════════════════════════════════════════════════════════
