# Reservation Visibility, Buffer Period & Expiration Fix - Deployment Guide (2026-03-26)

## Executive Summary

**Problem**: Tables with upcoming reservations appear as "available"; reservations don't automatically expire; buffer periods not enforced.

**Solution**: Implement slot-based table status management and automatic reservation expiration using database functions and views.

---

## Root Causes

### 1. **Missing Database Function**

- The Flutter app calls `fn_update_table_statuses_for_slots()` but this function doesn't exist
- Tables never get marked as "reserved" automatically based on reservation timing
- No mechanism to update table status within buffer/grace periods

### 2. **No Buffer Period Enforcement**

- System doesn't mark tables as "reserved" 30 minutes **before** reservation time
- Walk-in customers can still be seated at tables with upcoming reservations

### 3. **No Automatic Expiration Timing**

- Reservations with `status='active'` and `check_in IS NULL` stay active indefinitely
- System relies on manual expiration or grace period logic (15 min) that never runs
- Tables remain "reserved" even after customers don't show up

### 4. **Incomplete Reservation Visibility**

- Views may not include all reservation fields needed by the app
- Table status inconsistencies (`status='reserved'` but `reservation IS NULL`)

---

## Solution Architecture

### Timeline Configuration

```
Reservation Time = 2:43 PM (reserved_for)

Buffer Period:
  Start: 2:13 PM (30 min before) ← Table marked "reserved"
  End:   2:43 PM

Grace Period (for late arrivals):
  Start: 2:43 PM
  End:   2:58 PM (15 min after)

Auto-Expiry:
  Trigger: NOW() >= 2:58 PM AND status='active' AND check_in IS NULL
  Action: Mark as 'no_show', free table
```

### Database Changes

#### 1. **New View: `vw_table_reservation_status`**

Determines current reservation state of each table:

- Identifies buffer window (30 min before reservation)
- Identifies grace period (15 min after reservation)
- Flags tables that need auto-expiry
- Shows current appropriate table status

#### 2. **New Function: `fn_update_table_statuses_for_slots(business_id)`**

Runs every minute from Flutter app (`_runPeriodicChecks()`):

- **Part 1**: Mark tables as "reserved" (in buffer/grace period)
- **Part 2**: Mark tables as "available" (no active reservation in windows)
- **Part 3**: Auto-expire stale reservations (past grace period + no check-in)
- **Returns**: Count of tables updated, reservations expired

#### 3. **Updated: `fn_expire_stale_reservations(business_id)`**

Now calls the comprehensive `fn_update_table_statuses_for_slots()`:

- Maintains backward compatibility
- Returns just the expired count

### Flutter App Logic

#### Already Implemented (No Changes Needed)

```dart
// In tables_provider.dart line 264-265:
await _expireStaleReservations();
await _updateSlotStatuses();  // This now has a working DB function
```

The app already calls these functions every minute in `_runPeriodicChecks()`.

---

## Deployment Steps

### Phase 1: Database Migration (Manual - 2 minutes)

**File**: `FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql`

**Action**: Run the complete SQL file in Supabase SQL Editor

**What it does**:

1. ✅ Adds `grace_period_start` column to `table_reservations`
2. ✅ Creates view: `vw_table_reservation_status`
3. ✅ Creates function: `fn_update_table_statuses_for_slots()`
4. ✅ Updates function: `fn_expire_stale_reservations()`
5. ✅ Reloads PostgREST schema

**Expected Output**: No errors; schema reloaded

### Phase 2: View Update (If Using Old View)

If `vw_tables_with_reservation` doesn't include all reservation columns, update it:

```sql
-- Drop old view
DROP VIEW IF EXISTS public.vw_tables_with_reservation CASCADE;

-- Create comprehensive new view
CREATE VIEW public.vw_tables_with_reservation AS
SELECT
  rt.*,
  jsonb_build_object(
    'id', tr.id,
    'customer_name', tr.customer_name,
    'phone', tr.phone,
    'guest_count', tr.guest_count,
    'reserved_for', tr.reserved_for,
    'check_in', tr.check_in,
    'check_out', tr.check_out,
    'notes', tr.notes,
    'status', tr.status,
    'warning_sent', tr.warning_sent,
    'created_at', tr.created_at,
    'created_by_name', tr.created_by_name,
    'created_by_role', tr.created_by_role
  ) AS reservation_data
FROM public.restaurant_tables rt
LEFT JOIN public.table_reservations tr ON
  rt.id = tr.table_id
  AND tr.status IN ('active', 'seated');

-- Notify PostgREST
NOTIFY pgrst, 'reload schema';
```

### Phase 3: Flutter App - No Changes Required

The app is already set up to call:

- Every minute: `_expireStaleReservations()` + `_updateSlotStatuses()`
- Realtime subscriptions to both `restaurant_tables` and `table_reservations`

Once the database functions exist, they'll work automatically.

---

## Testing Checklist

### Test 1: Buffer Period Activation

```
Setup:
  Table 12: 4-seat
  Reservation: John Doe for 2:43 PM

Steps:
  1. Time = 2:30 PM (before buffer)
     → Table shows: "Available" ✅

  2. Time = 2:13 PM (in buffer window start)
     → Run: SELECT fn_update_table_statuses_for_slots('YOUR_BUSINESS_ID');
     → Table 12 status = 'reserved' ✅
     → Flutter: Table shows "Reserved" ✅

  3. Time = 2:43 PM (reservation time)
     → Table 12 still 'reserved' ✅

  4. Time = 2:58 PM (past grace period, no check-in)
     → Run function again
     → Reservation status changes to 'no_show' ✅
     → Table 12 status changes to 'available' ✅
```

### Test 2: Check-In Cancels Expiry

```
Setup:
  Table 13: Reservation for 2:30 PM

Steps:
  1. Time = 2:45 PM
  2. Staff seats guest: fn_seat_guest_v2(...)
     → Reservation: check_in = NOW(), status = 'seated' ✅
  3. Time = 2:50 PM (after grace period)
     → Expiry check runs
     → Reservation NOT expired (status='seated') ✅
     → Table remains 'occupied' ✅
```

### Test 3: Walk-In on Reserved Table

```
Setup:
  Table 14: Future reservation 4:00 PM
  Current time: 2:30 PM

Steps:
  1. Table 14 status = 'available' (not in buffer yet) ✅
  2. Staff seats walk-in at 2:40 PM
     → fn_seat_guest_v2(...)
     → Table status = 'occupied' ✅
     → Reservation untouched (status='active') ✅
  3. Walk-in checked out 3:20 PM
     → fn_checkout_v2(...)
     → Table status = 'available' ✅
  4. Time = 3:30 PM
     → Buffer window starts for 4:00 PM reservation ✅
     → fn_update_table_statuses_for_slots() marks table 'reserved' ✅
```

### Test 4: Multiple Reservations on Same Table

```
Query:
  SELECT id, table_id, customer_name, reserved_for, status
  FROM table_reservations
  WHERE table_id = 'TABLE_14' AND status IN ('active', 'seated')
  ORDER BY reserved_for;

Expected:
  - Only one 'active' reservation per table at a time
  - Status transitions: active → seated → completed
  - OR: active → no_show
```

---

## SQL Verification Queries

Run these to verify the fix is working:

### 1. Check View Exists

```sql
SELECT table_name FROM information_schema.views
WHERE table_name = 'vw_table_reservation_status';
-- Expected: 1 row
```

### 2. Check Function Exists

```sql
SELECT proname FROM pg_proc
WHERE proname = 'fn_update_table_statuses_for_slots';
-- Expected: 1 row
```

### 3. Test View Output

```sql
SELECT
  table_id,
  reservation_id,
  customer_name,
  reserved_for,
  buffer_window_start,
  grace_period_end,
  current_table_status,
  needs_expiry
FROM vw_table_reservation_status
WHERE business_id = 'YOUR_BUSINESS_ID'
ORDER BY reserved_for;
```

### 4. Test Function

```sql
SELECT fn_update_table_statuses_for_slots('YOUR_BUSINESS_ID');
-- Expected: JSON with counts
-- {"success": true, "tables_marked_reserved": N, "tables_marked_available": M, ...}
```

### 5. Check Auto-Expired Reservations

```sql
SELECT customer_name, reserved_for, status, check_in
FROM table_reservations
WHERE business_id = 'YOUR_BUSINESS_ID'
  AND status = 'no_show'
ORDER BY reserved_for DESC
LIMIT 10;
```

---

## Troubleshooting

### Symptom: "Schema cache error PGRST205"

**Cause**: PostgREST schema cache not reloaded after function creation
**Fix**:

```sql
NOTIFY pgrst, 'reload schema';
```

Then restart Flutter app.

### Symptom: Tables not marked as reserved

**Cause**: Function not running or database queries incorrect
**Fix**:

1. Verify function exists: `SELECT fn_update_table_statuses_for_slots(...);`
2. Check database time: `SELECT NOW();`
3. Verify table has active reservation: `SELECT * FROM vw_table_reservation_status WHERE table_id = '...';`

### Symptom: Reservations not auto-expiring

**Cause**: Grace period calculation incorrect or function not called
**Fix**:

1. Verify reservation has `check_in IS NULL`
2. Manually run: `SELECT fn_update_table_statuses_for_slots('BUSINESS_ID');`
3. Check if reservation status changed to 'no_show'

### Symptom: "Invariant violation" in Flutter logs

**Cause**: Table status inconsistency (status='reserved' but reservation=null)
**Fix**: This is gracefully handled now:

- UI shows warning card with "Sync" button
- Falls back to showing available seats
- Does not crash

---

## Impact Summary

| Scenario                  | Before Fix                         | After Fix                                 |
| ------------------------- | ---------------------------------- | ----------------------------------------- |
| View reservation in app   | ❌ Doesn't show if not checking-in | ✅ Shows when reserved status active      |
| 30 min before reservation | ❌ Table appears available         | ✅ Table shows "Reserved"                 |
| Customer doesn't arrive   | ❌ Stays reserved indefinitely     | ✅ Auto-expires as 'no_show' after 15 min |
| Walk-in conflicts         | ❌ Can seat at reserved table      | ✅ Table unavailable during buffer        |
| Multiple reservations     | ❌ Data may accumulate             | ✅ Only latest active tracked             |

---

## Files Modified

1. **Database**:
   - Run: `FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql`
   - Creates: `vw_table_reservation_status`
   - Creates: `fn_update_table_statuses_for_slots()`
   - Updates: `fn_expire_stale_reservations()`

2. **Flutter App**:
   - ✅ No changes needed!
   - Already calls: `_updateSlotStatuses()` every minute
   - Already has fallback logic for when DB function not available

---

## Rollback Plan

If issues occur:

```sql
-- Step 1: Drop new function (revert to old expiry logic)
DROP FUNCTION IF EXISTS public.fn_update_table_statuses_for_slots(TEXT) CASCADE;

-- Step 2: Recreate old fn_expire_stale_reservations
CREATE FUNCTION public.fn_expire_stale_reservations(p_business_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE v_count INT;
BEGIN
  UPDATE public.table_reservations
  SET status='no_show', updated_at=NOW()
  WHERE business_id=p_business_id
    AND status='active'
    AND check_in IS NULL
    AND reserved_for < NOW()-INTERVAL '15 min';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('expired_count',v_count,'success',true);
END;
$$;

-- Step 3: Reload schema
NOTIFY pgrst, 'reload schema';
```

---

## Success Metrics

After deployment, verify:

✅ Upcoming reservations visible in app at 30-min window
✅ Table shows "Reserved" status in app during buffer period
✅ Walk-in customers cannot be seated during buffer period
✅ No-show reservations auto-expire after 15-min grace period
✅ Freed tables show "Available" after expiration
✅ No schema cache errors (PGRST204/PGRST205)
✅ No UI crashes for inconsistent states

---

## Support

For questions or issues:

1. Check troubleshooting section above
2. Run the SQL verification queries
3. Review `flutter_analyze.txt` for any compile errors
4. Check Supabase logs for RPC execution errors
