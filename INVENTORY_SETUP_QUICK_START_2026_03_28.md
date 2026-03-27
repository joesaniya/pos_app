## 🚀 QUICK SETUP GUIDE - Inventory Validation & Deduction
**Implementation Complete — Date: 2026-03-28**

### ⚡ 3-Step Quick Setup

#### **STEP 1: Run Database Setup (2 minutes)**

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Create new query
3. Copy-paste entire contents from: `INVENTORY_DEDUCTION_FUNCTION_2026_03_28.sql`
4. Click **Run** button
5. Verify: Should see "No errors" message

✅ Database is now ready!

---

#### **STEP 2: Verify Code Changes (5 minutes)**

The following files have been updated:

| File | Changes |
|------|---------|
| `lib/services/inventory_deduction_service.dart` | ✨ **NEW** — Core inventory service |
| `lib/screens/new_order_screen.dart` | ✏️ Updated — Add validation & deduction |
| `lib/services/order_service.dart` | ✏️ Updated — Auto-deduct on order creation |

**What Changed:**
```dart
// In new_order_screen.dart:

// 1. Import new service
import '../../services/inventory_deduction_service.dart';

// 2. _addItem() now validates stock before adding
void _addItem(Map<String, dynamic> item) async {
  final validation = await InventoryDeductionService()
    .validateStock(id, quantity);
  
  if (!validation.isValid) {
    // Show user-friendly constraint dialog
    _showStockConstraintDialog(...);
    return;
  }
  // Add to cart normally
}

// 3. _placeOrder() now deducts inventory
Future<void> _placeOrder() async {
  // ... validation ...
  final order = await prov.createOrder(...);
  
  // Auto-deduct inventory after order created
  await InventoryDeductionService()
    .deductInventoryForOrder(...);
}
```

✅ Code changes are already done!

---

#### **STEP 3: Test with Sample Data (10 minutes)**

1. **Create Test Menu Item & Recipe:**

```sql
-- In Supabase SQL Editor, run:

-- 1. Add menu item (if not exists)
INSERT INTO menu_items (id, business_id, name, price, category_id, is_available)
VALUES ('test-item-1', 'POS001', 'Test Coffee', 100, 'cat-1', true);

-- 2. Add recipe
INSERT INTO recipes (id, business_id, menu_item_id, name)
VALUES ('recipe-1', 'POS001', 'test-item-1', 'Coffee Recipe');

-- 3. Add ingredient requirement
INSERT INTO recipe_ingredients (recipe_id, ingredient_id, ingredient_name, ingredient_unit, quantity_required)
VALUES ('recipe-1', 'milk-item-id', 'Milk', 'litre', 0.5);

-- 4. Verify inventory item has stock
UPDATE inventory_items 
SET current_stock = 5.0 
WHERE id = 'milk-item-id' AND business_id = 'POS001';
```

2. **Test in App:**

- Open POS app
- Go to "New Order"
- Find "Test Coffee" in menu
- Tap **ADD** button

**Expected Result:**
- ✅ Should add to cart (shows "✅ Added to cart")
- ✅ Quantity increments normally

3. **Test Order Placement:**

- Add 5 coffees to cart (5 × 0.5L = 2.5L milk needed)
- Tap **Place Order**
- Wait for success message

**Expected Result:**
```
✅ Order placed & inventory updated
(Milk should deduct 2.5L)
```

4. **Verify Deduction:**

```sql
-- Check updated stock
SELECT current_stock FROM inventory_items 
WHERE id = 'milk-item-id';
-- Should show: 2.5 (was 5.0, deducted 2.5)

-- Check consumption record
SELECT * FROM ingredient_consumption 
WHERE order_id = '<last_order_id>'
ORDER BY created_at DESC;
-- Should show: transaction_status = 'completed'
```

---

### 🎯 Key Features Implementation Checklist

- [x] **Real-time Stock Validation** — Validates before adding to cart
- [x] **Constraint Dialogs** — Shows max qty when stock is partial
- [x] **Auto Quantity Adjustment** — User can click "Adjust & Add" to set max qty
- [x] **One-time Deduction** — Only happens after order creates successfully
- [x] **No Duplicate Deductions** — Each order item deducted once per order
- [x] **Accurate Calculation** — multiplies order qty × recipe ingredient qty
- [x] **Audit Trail** — ingredient_consumption records all deductions
- [x] **Atomic Operations** — Database function ensures safety
- [x] **Error Handling** — Orders created even if deduction fails (logged)
- [x] **Offline Support** — Deduction happens when sync occurs

---

### 📋 What Users See

#### **Scenario 1: Normal Add (Sufficient Stock)**

```
User taps ADD on "Coffee"
    ↓
Validation message: "✅ Added to cart"
    ↓
Coffee appears in cart with qty +1
```

#### **Scenario 2: Constraint Dialog (Partial Stock)**

```
User taps ADD (trying to add 3rd coffee when only 2 left)
    ↓
Dialog appears:
"📦 Stock Constraint
Only 2 coffees can be made with available milk.
Would you like to adjust to 2 coffees?

[Cancel] [Adjust & Add]"
    ↓
User clicks "Adjust & Add"
    ↓
Cart updated: Coffee qty = 2
Success: "✅ Added 2 coffees to cart"
```

#### **Scenario 3: Order Placement & Deduction**

```
Cart: 2 Coffees (requires 1L milk)
Available milk: 3L

User taps "Place Order"
    ↓
Validates: 2 × 0.5L = 1L ≤ 3L ✅
    ↓
Order created ✅
    ↓
Inventory deducted:
- Milk: 3L → 2L ✅
- Consumption record: {qty: 1L, status: completed} ✅
    ↓
Success: "✅ Order placed & inventory updated"
```

---

### 🐛 Troubleshooting

#### **Problem: "No recipe found for menu item"**

**Cause:** Menu item doesn't have a linked recipe

**Fix:**
```sql
-- Verify recipe exists
SELECT * FROM recipes WHERE menu_item_id = '<menu_item_id>';

-- If empty, create recipe:
INSERT INTO recipes (id, business_id, menu_item_id, name)
VALUES (uuid_generate_v4(), 'POS001', '<menu_item_id>', 'Recipe Name');
```

---

#### **Problem: Validation always passes (even zero stock)**

**Cause:** No recipe ingredients defined

**Fix:**
```sql
-- Add ingredient requirement
INSERT INTO recipe_ingredients (
  recipe_id, ingredient_id, ingredient_name, 
  ingredient_unit, quantity_required
)
VALUES (
  '<recipe_id>', 
  '<inventory_item_id>', 
  'Ingredient Name', 
  'unit', 
  1.0  -- quantity per item
);
```

---

#### **Problem: Dialog shows wrong max quantity**

**Cause:** Incorrect quantity_required in recipe

**Fix:**
```sql
-- Verify value
SELECT ingredient_name, quantity_required, unit
FROM recipe_ingredients
WHERE recipe_id = '<recipe_id>';

-- Update if needed
UPDATE recipe_ingredients 
SET quantity_required = 0.5  -- correct value
WHERE recipe_id = '<recipe_id>'
AND ingredient_id = '<item_id>';
```

---

### 📊 Monitoring

**For Admins/Developers:**

Check daily:
```sql
-- Stock levels (low inventory alerts)
SELECT name, current_stock, min_threshold
FROM inventory_items
WHERE current_stock < min_threshold
AND business_id = 'POS001';

-- Recent deductions
SELECT COUNT(*) as deductions_today
FROM ingredient_consumption
WHERE created_at > NOW() - INTERVAL '1 day'
AND business_id = 'POS001';

-- Any failed deductions (should be 0)
SELECT COUNT(*) as failures
FROM ingredient_consumption
WHERE transaction_status = 'failed'
AND created_at > NOW() - INTERVAL '7 days'
AND business_id = 'POS001';
```

---

### ✨ Done!

Your inventory system is now:
- ✅ Validating stock in real-time
- ✅ Showing user-friendly constraints
- ✅ Deducting inventory on order placement
- ✅ Tracking all consumption

**No manual reconciliation needed — fully automated!**

---

### 📚 Full Documentation

For detailed information, see:
- `INVENTORY_STOCK_VALIDATION_DEDUCTION_GUIDE_2026_03_28.md` — Complete guide
- `INVENTORY_DEDUCTION_FUNCTION_2026_03_28.sql` — Database function
- `lib/services/inventory_deduction_service.dart` — Service code
