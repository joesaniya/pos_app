# 🔧 Database Schema Fixes - FINAL MIGRATION

## Issues Fixed

This migration resolves **2 critical database errors**:

### ❌ Error 1: `PGRST204 - Could not find column 'res_actual_check_out'`

**Root Cause:** Schema cache mismatch between Flutter app expectations and actual database state.

**Fix:** Recreates `vw_tables_with_reservation` view with proper column mapping including `actual_check_out` from `table_reservations` table (NOT `restaurant_tables`).

---

### ❌ Error 2: `PGRST202 - Could not find function 'fn_table_orders_v2'`

**Root Cause:** The `OrdersService.fetchTableOrders()` method tries to call `fn_table_orders_v2` RPC which doesn't exist in the database.

**Fix:** Creates the missing `fn_table_orders_v2()` PostgreSQL function that:

- Takes `table_id` as parameter
- Returns orders for that table
- Filters by current session to avoid cross-guest order contamination
- Falls back gracefully in OrdersService if not found

---

## Migration File

**Location:** `migration_fixes_final.sql`

### What It Does (Step by Step)

1. **Cleanups**
   - Drops conflicting views and functions to avoid duplication
   - Refreshes schema cache

2. **Table Structure**
   - Ensures `actual_check_out` column exists in `table_reservations`
   - Creates `table_seats` table for per-seat tracking
   - Adds `table_seat_id` column to orders for seat-specific ordering

3. **Views**
   - ✅ `vw_tables_with_reservation` - Tables with reservation JSONB data
   - ✅ `vw_orders_with_items` - Orders with nested items array

4. **Functions**
   - ✅ `fn_table_orders_v2(p_table_id)` - Session-aware order retrieval
   - ✅ `fn_seat_guest_v2()` - Seat guest with per-seat support
   - ✅ `fn_checkout_v2()` - Checkout with per-seat isolation

5. **Indexes & Constraints**
   - Performance indexes on foreign keys
   - Unique constraint preventing duplicate active orders per seat

---

## How to Apply

### ✅ Step 1: Run in Supabase SQL Editor

1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **SQL Editor**
3. Open `migration_fixes_final.sql` file
4. Copy the entire content
5. Paste into SQL Editor
6. Click **Run**

```
Expected Result: ✅ All statements completed successfully
```

### ✅ Step 2: Verify Fixes

After running the migration, execute these verification queries:

```sql
-- Verify function exists
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'fn_table_orders_v2'
AND routine_schema = 'public';

-- Should return: fn_table_orders_v2
```

```sql
-- Verify view columns
SELECT column_name FROM information_schema.columns
WHERE table_name = 'vw_tables_with_reservation'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Should include: reservation_data (JSONB)
```

```sql
-- Verify actual_check_out exists
SELECT column_name FROM information_schema.columns
WHERE table_name = 'table_reservations'
AND table_schema = 'public'
AND column_name = 'actual_check_out';

-- Should return: actual_check_out
```

---

## Dart Code Changes Required

### ✅ `OrdersService.fetchTableOrders()` - ALREADY HANDLED

The method has **built-in fallback logic**:

1. First tries `fn_table_orders_v2` RPC
2. If RPC fails (during migration), uses direct query
3. No code changes needed ✓

This is why the error message says:

```
[OrdersService] fn_table_orders_v2 not found, using fallback
```

After migration completes, ErrorStops appearing and RPC is used directly.

---

## Deployment Checklist

- [ ] Backup current database
- [ ] Run migration in Supabase SQL Editor
- [ ] Run verification queries (see above)
- [ ] Restart Flutter app
- [ ] Monitor logs for sync errors (should be 0)
- [ ] Test:
  - [ ] Seat guest
  - [ ] Create order
  - [ ] Checkout seat
  - [ ] View table with reservation

---

## Rollback Plan

If something goes wrong, you can rollback specific components:

```sql
-- Drop the new view and function (go back to old schema)
DROP FUNCTION IF EXISTS fn_table_orders_v2 CASCADE;
DROP VIEW IF EXISTS vw_tables_with_reservation CASCADE;
```

But keep the structural changes (`actual_check_out` column, `table_seats` table, etc.) as they're compatible with existing code.

---

## Files Reference

| File                                            | Purpose                                        |
| ----------------------------------------------- | ---------------------------------------------- |
| `migration_fixes_final.sql`                     | Complete migration with all fixes              |
| `lib/services/order_service.dart`               | Already has fallback logic (no changes needed) |
| `lib/repositories/seat_history_repository.dart` | Uses session IDs correctly (no changes needed) |

---

## Timeline

**After Migration:**

- Error messages will stop appearing ✅
- Orders will be session-aware ✅
- Per-seat checkout will work ✅
- Reservation view will return correct data ✅

---

**Status:** 🟢 Ready for production  
**Last Updated:** 2026-03-24  
**Tested Against:** Flutter app v1.0+ with Supabase integration
