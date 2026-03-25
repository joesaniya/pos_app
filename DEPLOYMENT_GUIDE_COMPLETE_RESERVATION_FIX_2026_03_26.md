# Reservation System Complete Fix - Deployment Guide

**Date**: March 26, 2026  
**Version**: Complete System Fix  
**Status**: Ready for Deployment

## Issues Fixed

1. ✅ **Tables appear "available" with upcoming reservations** - Tables were not being marked as 'reserved' during the buffer window (30 min before)
2. ✅ **Reservation data not visible in UI** - View was not properly joining reservation data for reserved tables
3. ✅ **Reservations not auto-expiring** - Grace period logic was inconsistent between DB and Flutter
4. ✅ **Missing buffer period enforcement** - No differentiation between buffer window and grace period
5. ✅ **UI not refreshing after status updates** - Periodic checks weren't triggering UI refresh for status changes

## Timeline Configuration

The system now uses a consistent timing model across all components:

### Reservation Lifecycle

```
BEFORE RESERVATION:
├─ 30 min before reserved_for time = Buffer window STARTS
│  └─ Table marked as 'reserved'
│  └─ Walk-in customers cannot be added
│  └─ UI shows reservation details
│
AT RESERVATION TIME (reserved_for):
├─ Buffer window ENDS
├─ Grace period STARTS
│  └─ Table still marked as 'reserved'
│  └─ Customer must check in soon
│
15 MIN AFTER RESERVATION TIME:
├─ Grace period ENDS
│  └─ If check_in IS NULL → Auto-expire as 'no_show'
│  └─ Table returns to 'available'
│
AFTER CHECK-IN:
├─ Table status → 'occupied' (by seat allocation)
├─ Reservation status → 'active' with check_in time
```

## Deployment Steps

### Step 1: Deploy SQL Changes (Required First)

Execute this SQL file in your Supabase database:

```
FIX_COMPLETE_RESERVATION_SYSTEM_2026_03_26.sql
```

This file contains:

- **vw_tables_with_reservation** - Fixed view to include reservation_data JSON for all active reservations
- **vw_table_reservation_status** - Diagnostic view for understanding table state
- **fn_update_table_statuses_for_slots()** - Function to mark tables reserved and auto-expire no-shows
- **fn_expire_stale_reservations()** - Backward compatibility wrapper

**Verification After Deployment:**

```sql
-- Verify function exists
SELECT proname FROM pg_proc
WHERE proname IN ('fn_update_table_statuses_for_slots', 'fn_expire_stale_reservations');

-- Verify views exist
SELECT table_name FROM information_schema.views
WHERE table_name IN ('vw_tables_with_reservation', 'vw_table_reservation_status');

-- Check PostgREST schema reload
SELECT * FROM vw_tables_with_reservation LIMIT 1;
```

### Step 2: Restart Flutter App

The app will automatically:

1. Call `_updateSlotStatuses()` every minute (from \_runPeriodicChecks)
2. Call `_expireStaleReservations()` every minute
3. Refresh tables and reservations after status updates
4. Log all operations for debugging

### Step 3: Monitor Logs

The app now logs comprehensive debug information:

```
[SlotStatus] ✅ Updated: Reserved=3, Available=2, Expired=1
[TablesProvider] _fetchTables: 15 tables loaded. Status: {available: 12, occupied: 1, reserved: 2}
[TablesProvider] _refreshAll: Complete. Tables: 15, Reservations: 8
[Expiry] ✅ Auto-expired 1 stale reservation(s)
[TablesRepo] Remote refresh: 15 tables, 2 reserved, 2 with reservation data
```

## Testing Workflow

### Test 1: Buffer Window Reservation Visibility

**Setup:**

- Create a reservation for 30 minutes from now (e.g., 2:00 PM if current time is 1:30 PM)
- Guest count: 2

**Expected Behavior:**

1. ✅ Table should immediately be marked as 'reserved'
2. ✅ UI should show "Table {number}" with "Reserved" status
3. ✅ Reservation details should be visible (guest name, party size, etc.)
4. ✅ Walk-in customers cannot be added to the table

**Verification Query:**

```sql
SELECT rt.table_number, rt.status, tr.customer_name, tr.reserved_for
FROM restaurant_tables rt
LEFT JOIN table_reservations tr ON tr.table_id = rt.id AND tr.status = 'active'
WHERE rt.table_number = YOUR_TABLE
ORDER BY rt.table_number;
-- Expected: status='reserved', customer_name should NOT be NULL
```

### Test 2: Auto-Expiration After Grace Period

**Setup:**

- Create a reservation for 20 minutes AGO (grace period should have ended)
- Do NOT check in the guest

**Expected Behavior:**

1. ✅ On next periodic check (max 1 minute), reservation should auto-expire
2. ✅ Reservation status changes to 'no_show'
3. ✅ Table status returns to 'available'
4. ✅ UI removes "Reserved" badge, shows "Available"

**Verification Query:**

```sql
SELECT customer_name, reserved_for, status, check_in
FROM table_reservations
WHERE customer_name = 'YOUR_GUEST'
ORDER BY reserved_at DESC
LIMIT 1;
-- Expected: status='no_show', check_in=NULL
```

### Test 3: Check-in During Buffer Window

**Setup:**

- Create a reservation for 15 minutes from now
- Guest arrives on time and checks in

**Expected Behavior:**

1. ✅ Table marked as 'reserved' (buffer window active)
2. ✅ Staff can click "Seat Guest" to mark table as 'occupied'
3. ✅ Reservation status becomes 'seated'
4. ✅ Table shows occupied details, not reservation details

**Verification Query:**

```sql
SELECT rt.status AS table_status, tr.status AS reservation_status, tr.check_in
FROM restaurant_tables rt
LEFT JOIN table_reservations tr ON tr.table_id = rt.id
WHERE rt.table_number = YOUR_TABLE;
-- Expected: table_status='occupied', reservation_status='seated', check_in NOT NULL
```

### Test 4: Multiple Reservations Same Date

**Setup:**

- Table 12, 2:00 PM - Guest 1 (2 people)
- Table 12, 4:00 PM - Guest 2 (4 people)

**Expected Behavior:**

1. ✅ At 1:30 PM: Table shows "Reserved for Guest 1"
2. ✅ At 2:30 PM (after grace): Guest 1 reservation expires as 'no_show', table becomes available
3. ✅ At 3:30 PM (30 min before 4 PM): Table shows "Reserved for Guest 2"
4. ✅ Never shows both reservations simultaneously

## Troubleshooting Guide

### Problem: Reserved table shows null reservation data

**Symptoms:**

- Table status is 'reserved' but shows "Reservation is for a different date"
- Logs show: `⚠️ CRITICAL: Table X marked RESERVED but NO reservation data found`

**Causes:**

1. View hasn't been refreshed by PostgREST after function run
2. Reservation has status other than 'active' or 'seated'
3. Reservation is marked 'is_active=false'

**Fix:**

```sql
-- Check if reservation exists and is active
SELECT id, status, is_active, table_id
FROM table_reservations
WHERE table_id = 'TABLE_ID'
ORDER BY created_at DESC LIMIT 1;

-- Check view query
SELECT status, reservation_data
FROM vw_tables_with_reservation
WHERE table_number = YOUR_TABLE;

-- Force schema reload
NOTIFY pgrst, 'reload schema';
```

### Problem: Reservations not auto-expiring

**Symptoms:**

- Reservation past grace period still shows as 'active'
- Table still marked as 'reserved'
- Logs don't show '[Expiry] ✅' messages

**Causes:**

1. `fn_update_table_statuses_for_slots` RPC failed silently
2. Fallback local expiry has a bug
3. Periodic check not running (check if background timer is working)

**Fix:**

```dart
// In Flutter, check logs:
[SlotStatus] ✅ Updated: Reserved=X, Available=Y, Expired=Z
[Expiry] ✅ Auto-expired N stale reservation(s)

// If no messages, check:
// 1. Is _runPeriodicChecks() being called? (should see periodic logs)
// 2. Is the business_id correct in the RPC call?
// 3. Check database logs for RPC errors
```

### Problem: UI not updating after status change

**Symptoms:**

- Slot status updates in DB but UI still shows old status
- Logs show function ran but no refresh

**Causes:**

1. Real-time subscription not subscribed to changes
2. PostgREST latency
3. Refresh triggered but cache not invalidated

**Fix:**

```dart
// Force manual refresh
TablesProvider().refreshFromRemote(businessId);

// Monitor logs
debugPrint('[TablesProvider] _refreshAll: Refreshing...');
debugPrint('[TablesProvider] _refreshAll: Complete. Tables: X');
```

## Key Changes Summary

### Database (SQL)

1. **vw_tables_with_reservation** - Now properly joins ALL active reservations
2. **fn_update_table_statuses_for_slots()** - Handles all state transitions
3. **Consistent timing** - 30min buffer before, 15min grace after reservation time

### Flutter Code

1. **Updated \_updateSlotStatuses()** - Now refreshes UI when changes detected
2. **Added \_localUpdateSlotStatuses()** - Fallback when RPC fails
3. **Enhanced logging** - Comprehensive debug information for troubleshooting
4. **Fixed expiry timing** - Now uses 15min grace period consistently

### UI Components

1. **ReservationSection** - Better handling of null reservation with logging
2. **Real-time subscription** - Enhanced to catch all table/reservation changes
3. **Periodic checks** - Every minute for up-to-date status

## Performance Notes

- Periodic checks run once per minute (5-10 RPC calls depending on number of active reservations)
- UI refresh triggered only when status changes detected (not on every check)
- Local cache used for reservation lookups (minimal DB queries)
- All operations are non-blocking and handle failures gracefully

## Rollback Plan

If issues arise:

1. Remove the SQL function calls from TablesProvider
2. Tables will still update via real-time subscription
3. Reservations won't auto-expire (manual action required)
4. Revert to previous SQL (vw_tables_with_reservation will still work)

## Next Steps

1. ✅ Deploy SQL file
2. ✅ Restart Flutter app
3. ✅ Monitor logs during first 5 minutes
4. ✅ Test with the 4 test scenarios above
5. ✅ Verify no issues in console logs
6. ✅ Enable scheduled daily review of 'no_show' reservations

## Support

If issues persist:

1. Check logs for error messages (search for "⚠️" and "❌")
2. Run verification queries above
3. Check network connectivity (RPC might fail on poor connections)
4. Verify business_id is correct in all RPC calls
5. Force schema reload: `NOTIFY pgrst, 'reload schema';`
