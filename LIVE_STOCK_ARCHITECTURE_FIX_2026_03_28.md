<!-- ═════════════════════════════════════════════════════════════════════════════────
     ARCHITECTURAL FIX: LIVE STOCK ARCHITECTURE
     ════════════════════════════════════════════════════════════════════════════════ -->

# 🏗️ Live Stock Architecture Fix — Single Source of Truth

## ❌ The Problem

**Before This Fix:**
```
Recipe (Static/Cached):                  Inventory (Dynamic/Live):
- Hot Tea                                - Milk
  ├─ ingredients array                   ├─ current_stock = 2.0L ✓ (REAL)
  │  └─ milk
  │     └─ available_quantity = 4.0L ✗ (STALE!)
```

**What Happened:**
1. Admin added milk stock → UI shows history ✓
2. current_stock updates to 2.0L in inventory_items ✓
3. User adds Hot Tea to cart → Validation fetches recipe ✓
4. Recipe still shows embedded `available_quantity = 4.0L` ✗
5. System thinks 4L is available, but only 2L exists
6. Order placed → Deduction fails or incorrect amount used ✗

## ✅ The Solution

**After This Fix:**
```
Recipe (Store Only Requirements):        Inventory (Single Source of Truth):
- Hot Tea                                - Milk
  ├─ ingredients array                   ├─ current_stock = 2.0L ✓ (ALWAYS FRESH)
  │  └─ milk
  │     ├─ inventory_item_id ✓
  │     └─ required_quantity ✓
  │        (NO available_quantity)
  └─ JOINS inventory_items table at runtime for live stock
```

**Data Flow:**
```
1. User adds Hot Tea → fetchRecipeIngredients()
2. Get recipe: ingredients array with inventory_item_id
3. FOR EACH ingredient:
   - Query inventory_items.current_stock (LIVE)
   - Use this value for validation
4. Always reflects actual current stock ✓
```

---

## 🔧 Changes Made

### 1️⃣ Database Schema Cleanup
**File:** `REMOVE_STATIC_AVAILABLE_QUANTITY_2026_03_28.sql`

Removes embedded `available_quantity` from recipe ingredients JSON:

```sql
-- Before:
{
  "inventory_item_id": "866e3acb...",
  "required_quantity": 1.0,
  "available_quantity": 4.0,  ✗ REMOVED
  "inventory_item_name": "milk"
}

-- After:
{
  "inventory_item_id": "866e3acb...",
  "required_quantity": 1.0,
  "inventory_item_name": "milk"
  // ✓ No available_quantity — it's LIVE from inventory_items!
}
```

**Why?** Eliminates the source of stale data. Available stock now comes ONLY from inventory_items table.

---

### 2️⃣ Updated Dart Code
**File:** `lib/services/inventory_deduction_service.dart`
**Method:** `fetchRecipeIngredients()`

#### Key Changes:

```dart
// ✨ BEFORE: Used static embedded value
availableQuantity: 
  double.tryParse(ing['available_quantity']?.toString() ?? '0') ?? 0.0,

// ✨ AFTER: Fetches LIVE current_stock via JOIN
double currentStock = 0.0;
if (inventoryItemId.isNotEmpty) {
  try {
    final invItem = await _db
        .from('inventory_items')
        .select('current_stock')
        .eq('id', inventoryItemId)
        .maybeSingle();
    
    if (invItem != null) {
      currentStock = double.tryParse(
        invItem['current_stock']?.toString() ?? '0',
      ) ?? 0.0;
      debugPrint('📦 Fetched LIVE stock: $currentStock${ing['unit']}');
    }
  } catch (e) {
    debugPrint('⚠️  Failed to fetch live stock: $e');
    currentStock = 0.0;
  }
}
```

#### What This Means:

| Aspect | Before | After |
|--------|--------|-------|
| **Data Source** | Static JSON in recipes table | Live query from inventory_items |
| **Update Lag** | Minutes/Hours (app restart needed) | Real-time (every validation) |
| **Stock Changes Visible** | No (requires cache clear) | Yes (immediate) |
| **Single Source of Truth** | ❌ Duplicated (recipes + inventory) | ✅ Only inventory_items.current_stock |

---

## 🎯 Architecture Benefits

### 1. **Consistency**
- Everywhere in app uses same current_stock value
- No stale data between recipe fetch and validation

### 2. **Real-time Accuracy**
- If stock depletes mid-order, validation catches it
- UI always shows live values

### 3. **Simplicity**
- Single place to manage stock: `inventory_items` table
- Recipe = just recipe requirements, not inventory state

### 4. **Reduced Bugs**
- No sync issues between tables
- No cache invalidation problems
- No "where is the real value?"

---

## 📊 Data Flow Diagram

```
┌─── User Adds Hot Tea ───┐
│                          │
├─ fetchRecipeIngredients()
│  ├─ Query: recipes table
│  ├─ Get: ingredients array
│  │   └─ Contains: [
│  │       { inventory_item_id: "866e3acb...", 
│  │         required_quantity: 1.0,
│  │         inventory_item_name: "milk" }
│  │     ]
│  │
│  ├─ FOR EACH ingredient:
│  │  ├─ Extract: inventory_item_id
│  │  ├─ Query: inventory_items table ← ✨ LIVE FETCH
│  │  └─ Get: current_stock = 2.0L (REAL)
│  │
│  ├─ Build RecipeIngredient with LIVE stock
│  └─ Return: List<RecipeIngredient>
│
├─ validateStock()
│  ├─ For each ingredient
│  │  └─ maxItems = current_stock / required
│  │        = 2.0 / 1.0 = 2 items (ACCURATE)
│  │
│  └─ Return: maxAllowed = 2 items
│
├─ UI Shows: "You can make 2 hot teas"
└─ System: NEVER shows stale 4L value
```

---

## 🚀 Implementation Steps

### Step 1: Apply Database Migration
```bash
# In Supabase SQL Editor:
# Run: REMOVE_STATIC_AVAILABLE_QUANTITY_2026_03_28.sql
# This removes the stale available_quantity from recipes JSON
```

**Verify:**
```sql
SELECT id, ingredients->0->'available_quantity' as old_field
FROM recipes
WHERE menu_item_id = 'a0b4a7e0-8c3d-47ba-9919-3fa35ac898bd';
-- Result: NULL (field removed successfully)
```

### Step 2: Update Flutter App
- File already updated: `lib/services/inventory_deduction_service.dart`
- No additional changes needed

### Step 3: Hot Restart App
```bash
# In VS Code terminal:
# flutter clean
# flutter pub get
# flutter run
```

### Step 4: Test
```
1. Go to Inventory
2. Add stock to milk (e.g., add 3L)
3. UI shows: History entry + current_stock = 3.0L ✓
4. Go to Menu
5. Add Hot Tea to cart
6. Console shows "📦 Fetched LIVE stock: 3.0L" ✓
7. UI shows validation based on LIVE 3.0L, not stale 4.0L ✓
```

---

## 🔍 Debugging Indicators

### Check if working:
In console, you should see during recipe fetch:
```
📦 Fetched LIVE stock for milk: 2.0L
✅ Fetched 1 ingredients for menu item: a0b4a7e0... (with LIVE stock data)
📊 Stock validation breakdown:
  • milk: Available=2.0L, Required/item=1.0L, MaxItems=2
```

### If NOT working:
```
⚠️  Failed to fetch live stock for inventory item 866e3acb...: error details
📦 Fetched LIVE stock: 0.0L
```

**Check:**
1. Is ingredient.inventory_item_id populated? `866e3acb-8...` format
2. Is that ID in inventory_items table?
3. Does inventory_items have current_stock column?

---

## 📋 Verification Checklist

After applying this fix:

- [ ] SQL migration executed in Supabase
- [ ] `available_quantity` removed from recipes.ingredients JSON
- [ ] Flutter app hot restarted
- [ ] Added inventory stock → sees live value in history
- [ ] Added menu item to cart → console shows "📦 Fetched LIVE stock"
- [ ] Stock shown in validation matches inventory_items.current_stock
- [ ] Multiple items show correct max calculation (stock / required)
- [ ] Order placed → inventory deducts correctly
- [ ] Stock no longer shows stale values

---

## 🎓 Key Principles

| ❌ Don't | ✅ Do |
|---------|-------|
| Store stock values in multiple places | Store once in inventory_items table |
| Cache inventory in recipes | Fetch live on each validation |
| Assume embedded values are current | Always query the source table |
| Update stock without transaction history | Record all changes in transactions |

---

## 📌 Single Source of Truth

**From now on:**

```
💾 STORAGE (Write to):
└─ inventory_items.current_stock (main store)
└─ stock_transactions (history/audit)

🔍 CONSUMPTION (Read from):
├─ fetchRecipeIngredients() → queries inventory_items
├─ validateStock() → uses fetched current_stock
├─ deductInventoryForOrder() → uses fetched current_stock
└─ UI Screens → all show current_stock

❌ NEVER:
└─ Store or cache current_stock anywhere else
```

---

## 🎯 Result

**Stock Entry Added:**
```
Before Fix:
- Inventory: ✓ Stock history recorded ✓ current_stock = 2L
- Recipe: Still showing cached 4L ✗
- Order: Used stale value ✗

After Fix:
- Inventory: ✓ Stock history recorded ✓ current_stock = 2L
- Recipe: Fetches LIVE 2L on every access ✓
- Order: Uses current 2L ✓
- UI: Shows 2L everywhere ✓
```

**Bottom Line:** Live stock from single source of truth = accurate orders, every time. ✨

