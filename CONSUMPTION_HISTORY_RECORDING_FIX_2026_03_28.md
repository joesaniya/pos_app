## Inventory Consumption History Recording Fix
**Date**: 2026-03-28  
**Issue**: Inventory deducts but transaction history NOT visible

---

## Problem Analysis

Your system is working PARTIALLY:
- ✅ Inventory quantities ARE being deducted (via `deduct_inventory` RPC)
- ❌ Transaction history is NOT being recorded (via `ingredient_consumption` insert)

### Why This Happens
```
Order Placed
    ↓
[1] Fetch recipe & validate stock ✅
    ↓
[2] Create order in database ✅
    ↓
[3] Try to insert consumption record ❌ (RLS blocks it)
    ↓
[4] Deduct inventory via RPC ✅
    ↓
Result: Stock changed ✔️ but NO history ✔️
```

---

## Solution (3 Steps)

### Step 1: Apply Updated RLS Policies
**File**: `FIX_INGREDIENT_CONSUMPTION_RLS_2026_03_28.sql`

1. Open **Supabase Dashboard → SQL Editor**
2. Create new query
3. **Delete everything** and paste ENTIRE updated SQL file
4. Click **Run**

The updated policy:
- Drops old conflicting policies
- Creates 3 new simplified policies (SELECT, INSERT, UPDATE)
- All check: `auth.uid() != '00000000-0000-0000-0000-000000000000'` (just authenticated user)
- Disables RLS temporarily to create function, then re-enables it

### Step 2: Verify Policies Applied
Run these verification queries in Supabase SQL Editor:

```sql
-- Check if policies exist
SELECT schemaname, tablename, policyname, permissive, cmd
FROM pg_policies
WHERE tablename = 'ingredient_consumption'
ORDER BY policyname;
```

Expected result: 3 rows (select, insert, update policies)

### Step 3: Test Consumption Recording

#### Option A: Run test insert (if you want to verify manually)
```sql
INSERT INTO ingredient_consumption (
  business_id, order_id, order_number, menu_item_id, menu_item_name,
  ingredient_id, ingredient_name, ingredient_unit, quantity_consumed, transaction_status
) VALUES (
  'POS001', 'test-order', 1, 'test-menu', 'Test Item',
  'test-ing', 'Test Ingredient', 'ml', 1.0, 'completed'
);
```

If this succeeds → RLS is working! Move on.
If it fails → RLS still blocking (see Troubleshooting below).

#### Option B: Place a test order in your app
1. Add Hot Tea to cart
2. Place order
3. **Check logs** - should see:
   ```
   📝 Attempting to create consumption record for Hot Tea: qty=1 ml
   ✅ Consumption record created: Hot Tea → -1 ml
   ```
4. **Check Supabase** - `ingredient_consumption` table should have new rows
5. **Check app UI** - Inventory history should show transaction

---

## Enhanced Error Logging

The code now provides detailed logs when consumption recording fails:

```
⚠️  Failed to create consumption record: PostgrestException(...)
Details: Hot Tea, qty: 1 ml
Proceeding with inventory deduction anyway.
```

**What to do if you see this error:**
1. Copy the error message
2. Check if it says "RLS" or "policy"
3. Verify SQL migration was run properly
4. Check Supabase logs for more details

---

## Troubleshooting

### Symptom: "relation 'ingredient_consumption' does not exist"
**Cause**: Table doesn't exist yet  
**Fix**: Create the table (template below) or check table name spelling

```sql
CREATE TABLE ingredient_consumption (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id TEXT NOT NULL,
  order_id UUID NOT NULL,
  order_number INTEGER NOT NULL,
  menu_item_id UUID NOT NULL,
  menu_item_name TEXT NOT NULL,
  ingredient_id TEXT NOT NULL,
  ingredient_name TEXT NOT NULL,
  ingredient_unit TEXT NOT NULL,
  quantity_consumed NUMERIC NOT NULL,
  transaction_status TEXT DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT now(),
  created_by TEXT,
  notes TEXT
);

ALTER TABLE ingredient_consumption ENABLE ROW LEVEL SECURITY;
```

### Symptom: "new row violates row-level security policy"
**Cause**: RLS policies not applied or incorrect  
**Fix**: 
1. Run the SQL migration again
2. Verify policies exist with verification query
3. Check `auth.uid()` vs `auth.uid()!` syntax

### Symptom: Consumption records added BUT showing old data
**Cause**: Caching issue  
**Fix**: 
1. In app: Force refresh with pull-to-refresh
2. In Supabase: Check `created_at` timestamp is recent
3. Verify order_id matches order in system

---

## How It Works (After Fix)

```
Order Placed
    ↓
[1] Fetch recipe & validate stock ✅
    ↓
[2] Create order in database ✅
    ↓
[3] Insert consumption record 
    ├─ Try INSERT → succeeds (RLS allows authenticated user) ✅
    └─ On error: Log warning, continue anyway
    ↓
[4] Deduct inventory via RPC ✅
    ↓
[5] Update consumption status to 'completed' ✅
    ↓
Result: Stock changed ✔️ AND history visible ✔️
```

---

## Consumption Record Fields

When a consumption record is created, it captures:

| Field | Value | Purpose |
|-------|-------|---------|
| `order_id` | UUID | Link to order |
| `order_number` | Integer | Human-readable order # |
| `menu_item_name` | "Hot Tea" | What was ordered |
| `ingredient_name` | "milk" | What was consumed |
| `quantity_consumed` | 1.0 | How much was used |
| `ingredient_unit` | "ml" | Unit of measurement |
| `transaction_status` | "pending" → "completed" | Deduction state |
| `created_at` | Timestamp | When it happened |

---

## Next Steps After Applying Fix

1. ✅ Run the SQL migration file
2. ✅ Verify with the 4 test queries
3. ✅ Place a test order and check logs
4. ✅ Check Supabase `ingredient_consumption` table for new records
5. ✅ Verify inventory history shows in app UI
6. If issues persist, share:
   - Error message from app logs
   - Result of verification queries
   - Screenshot of Supabase table contents

---

## Code Changes Summary

### File: `lib/services/inventory_deduction_service.dart`

**Added:** Enhanced logging for consumption operations
- `📝 Attempting to create consumption record...`
- `✅ Consumption record created...`
- `⚠️ Failed to create consumption record...`

**Changed:** Made consumption insert non-blocking
- Wraps insert in try-catch
- Continues with actual deduction even if consumption fails
- Logs detailed error info for debugging

**Why:** Ensures:
- Order processing continues even if audit trail fails
- Critical deduction is never blocked by RLS issues
- Detailed logs help diagnose RLS problems

---

## Testing Checklist

- [ ] SQL migration run successfully (no errors)
- [ ] Verification queries show 3 policies
- [ ] Manual test insert succeeds (or shows specific error)
- [ ] App logs show "✅ Consumption record created"
- [ ] Supabase shows new records in `ingredient_consumption`
- [ ] App UI shows transaction in inventory history
- [ ] Multiple test orders work correctly
- [ ] Consumption records increment with each order
