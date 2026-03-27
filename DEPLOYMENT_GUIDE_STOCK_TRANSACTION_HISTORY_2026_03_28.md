<!-- ═══════════════════════════════════════════════════════════════════════════════
FIX: Inventory Deduction Transaction History Recording (2026-03-28)
═══════════════════════════════════════════════════════════════════════════════ -->

# 🔧 Inventory Deduction Transaction History Fix

## 📋 What Was the Problem?

When inventory items were deducted during order processing:
- ✓ The `current_stock` was correctly updated in the `inventory_items` table
- ✓ Consumption records were created in `ingredient_consumption` table
- ✓ **BUT** no transaction records were created in `stock_transactions` table
- ✗ Result: History screens and transaction reports showed **NOTHING**

### User Symptoms
```
[log] ✅ LIVE stock fetched for oofll: 7.0kg
[log] ✅ Deducted 1.0 kg of oofll for order #123
[screen] ❌ History tab shows: "No transaction history"
```

---

## ✨ What the Fix Does

### 1. Modified PostgreSQL Function: `deduct_inventory()`

**Previous Signature:**
```sql
deduct_inventory(
  p_inventory_item_id UUID,
  p_quantity NUMERIC,
  p_business_id TEXT
)
```

**New Signature:**
```sql
deduct_inventory(
  p_inventory_item_id UUID,
  p_quantity NUMERIC,
  p_business_id TEXT,
  p_order_id UUID DEFAULT NULL,        -- NEW: For audit trail
  p_order_number INT DEFAULT NULL       -- NEW: For reference
)
```

**Key Changes:**
1. ✨ Now accepts `order_id` and `order_number` for audit trail
2. 🔍 Fetches `cost_per_unit` from inventory_items
3. 📝 Inserts complete transaction record into `stock_transactions`
4. 💾 Atomically updates `current_stock`

### 2. Transaction Record Creation

After each deduction, the function now records:

```sql
INSERT INTO stock_transactions (
  item_id,                    -- Which inventory item?
  business_id,                -- Which business?
  transaction_type,           -- 'stock_out' for deductions
  quantity,                   -- How much was deducted?
  stock_before,               -- What was the stock before?
  stock_after,                -- What is the stock after?
  unit,                       -- kg, liters, etc.
  cost_per_unit,              -- For cost analysis
  total_cost,                 -- quantity * cost_per_unit
  note,                       -- 'Order #123 consumption'
  updated_by_uid,             -- 'system'
  updated_by_name,            -- 'System'
  updated_by_role             -- 'system'
)
```

### 3. Updated Dart Code

The `InventoryDeductionService` now passes order info to the RPC:

```dart
await _db.rpc(
  'deduct_inventory',
  params: {
    'p_inventory_item_id': ing.ingredientId,
    'p_quantity': totalToDeduct,
    'p_business_id': businessId,
    'p_order_id': orderId,             // NEW
    'p_order_number': orderNumber,     // NEW
  },
);
```

---

## 🚀 How to Deploy

### Step 1: Run the SQL Migration

Execute the SQL file in your Supabase SQL Editor:

```sql
-- File: FIX_STOCK_TRANSACTION_HISTORY_2026_03_28.sql
-- Copy and paste the entire contents into Supabase SQL Editor
-- Then click "Execute"
```

**What it does:**
1. Drops the old `deduct_inventory()` function
2. Creates the new function with transaction recording
3. Updates execute permissions

### Step 2: Update your Dart code

The code update is already included in [lib/services/inventory_deduction_service.dart](lib/services/inventory_deduction_service.dart)

**Change at line ~415:**
```dart
// OLD CODE (without order info):
await _db.rpc(
  'deduct_inventory',
  params: {
    'p_inventory_item_id': ing.ingredientId,
    'p_quantity': totalToDeduct,
    'p_business_id': businessId,
  },
);

// NEW CODE (with order tracking):
await _db.rpc(
  'deduct_inventory',
  params: {
    'p_inventory_item_id': ing.ingredientId,
    'p_quantity': totalToDeduct,
    'p_business_id': businessId,
    'p_order_id': orderId,             // ✨ NEW
    'p_order_number': orderNumber,     // ✨ NEW
  },
);
```

### Step 3: Rebuild and Deploy

```bash
# Clear old builds
flutter clean

# Rebuild with new code
flutter pub get
flutter run --release

# Or build APK
flutter build apk --release
```

---

## ✅ Verification

### Check 1: Database Transactions Created

```sql
-- Run this in Supabase SQL Editor
SELECT * FROM stock_transactions 
WHERE transaction_type = 'stock_out' 
ORDER BY created_at DESC 
LIMIT 10;

-- Expected: Should see entries like:
-- | item_id | transaction_type | quantity | stock_before | stock_after | note |
-- | ... | stock_out | 1.0 | 8.0 | 7.0 | Order #123 consumption |
```

### Check 2: History Tab Now Shows Deductions

1. Create an order in the app
2. Select items and place order
3. Go to Inventory → Select an item → History tab
4. **Expected:** "Use Stock (Stock Out)" transaction appears with:
   - Date/time of order
   - Quantity deducted
   - Stock before/after
   - Order reference

### Check 3: Real-time UI Update

After deduction, the history should show:
```
✅ LIVE stock: 7.0 kg (down from 8.0 kg)
📝 Recent Transactions:
   - Use Stock (Stock Out): 1.0 kg
   - Timestamp: [order time]
   - Order Reference: #123
```

---

## 🔄 Backward Compatibility

✅ **Fully backward compatible!**

- Old code that calls `deduct_inventory(p_inventory_item_id, p_quantity, p_business_id)` still works
- The new parameters (`p_order_id`, `p_order_number`) are optional with `DEFAULT NULL`
- Transaction will still be created even if order info is NULL

---

## 🐛 If Issues Occur

### Issue: "Insufficient stock" errors appearing

**Cause:** A concurrent order processing may have deducted inventory

**Solution:** Orders have proper stock validation before deduction - this is expected behavior

### Issue: Transactions not appearing

**Cause 1:** Old SQL function still in use
```bash
# Fix: Clear Flutter cache and rebuild
flutter clean
flutter pub get
flutter run
```

**Cause 2:** RLS (Row Level Security) restrictions
```sql
-- Check RLS policies on stock_transactions
SELECT * FROM pg_policies 
WHERE tablename = 'stock_transactions';

-- Should allow system user to insert
-- If not, check COMPLETE_RLS_STOCK_FIX_GUIDE_2026_03_28.md
```

### Issue: "Table stock_transactions doesn't exist"

**Cause:** Migration not applied

**Solution:**
1. Check that your database has `stock_transactions` table
2. Run the CONSOLIDATED_RECIPE_INVENTORY_SYSTEM_2026_03_27.sql if missing
3. See LIVE_STOCK_ARCHITECTURE_FIX_2026_03_28.md for schema

---

## 📊 Impact Summary

| Aspect | Before | After |
|--------|--------|-------|
| Stock Updated | ✓ Yes | ✓ Yes |
| Transaction Recorded | ✗ NO | ✓ YES |
| History Visible | ✗ NO | ✓ YES |
| Cost Tracking | ✗ NO | ✓ YES |
| Audit Trail | ⚠️ Partial | ✓ Complete |

---

## 📝 Related Files

- **SQL Migration:** [FIX_STOCK_TRANSACTION_HISTORY_2026_03_28.sql](FIX_STOCK_TRANSACTION_HISTORY_2026_03_28.sql)
- **Dart Changes:** [lib/services/inventory_deduction_service.dart](lib/services/inventory_deduction_service.dart#L415)
- **Database Schema:** [LIVE_STOCK_ARCHITECTURE_FIX_2026_03_28.md](LIVE_STOCK_ARCHITECTURE_FIX_2026_03_28.md)
- **Stock Transaction Recording:** [lib/repositories/inventory_repository.dart](lib/repositories/inventory_repository.dart#L300)

---

## ❓ FAQ

**Q: Do I need to re-enter old inventory data?**
A: No! Only NEW deductions after this fix will be recorded in stock_transactions.

**Q: Will this affect offline mode?**
A: Good question! Currently deductions only work in online mode (since they call RPC). Offline mode queues transactions for sync, which will be recorded when online.

**Q: How do I test this locally?**
A: Create an order in dev mode → Check Supabase SQL Editor for new stock_transactions entry.

---

## 🎯 Next Steps

1. ✅ Apply the SQL migration
2. ✅ Update your Flutter build
3. ✅ Test order creation → Check history
4. ✅ Monitor for any errors in logs
5. ✅ Verify transaction reports now show deductions

---

**Date Created:** 2026-03-28
**Status:** Ready for Production
**Testing:** Complete locally, verified with production data structure
