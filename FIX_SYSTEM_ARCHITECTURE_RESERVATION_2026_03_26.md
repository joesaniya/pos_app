# Complete Reservation System Fix - Architecture & Implementation (2026-03-26)

## Executive Summary

**The Problem**: Tables with upcoming reservations appear as "available" in the app, and reservations don't automatically expire when customers don't show up.

**The Root Cause**: A critical database function (`fn_update_table_statuses_for_slots`) that the Flutter app calls every minute doesn't exist.

**The Solution**: Implement slot-based table status management with automatic buffer window enforcement and reservation expiration.

---

## System Architecture

### Current State (Broken)

```
┌─────────────────────────────────────────────┐
│ Flutter App - Every Minute                  │
├─────────────────────────────────────────────┤
│ _runPeriodicChecks()                        │
│ ├─ _expireStaleReservations()               │
│ │  └─ fn_expire_stale_reservations() ✓ [DB]│
│ │     └─ Marks old reservations as 'no_show'│
│ │                                            │
│ └─ _updateSlotStatuses()                    │
│    └─ fn_update_table_statuses_for_slots()  │
│       └─ ❌ DOES NOT EXIST!                  │
│          └─ Tables never marked 'reserved'  │
└─────────────────────────────────────────────┘
```

### Fixed State

```
┌──────────────────────────────────────────────────────┐
│ Flutter App - Every Minute                           │
├──────────────────────────────────────────────────────┤
│ _runPeriodicChecks()                                 │
│ ├─ _expireStaleReservations()                        │
│ │  └─ fn_expire_stale_reservations() ✓ [DB]         │
│ │     └─ Calls comprehensive function               │
│ │                                                    │
│ └─ _updateSlotStatuses()                            │
│    └─ fn_update_table_statuses_for_slots() ✓ [DB]  │
│       ├─ Part 1: Mark 'reserved' in buffer window   │
│       ├─ Part 2: Mark 'available' outside window    │
│       └─ Part 3: Auto-expire past grace period      │
└──────────────────────────────────────────────────────┘

Database Functions:
├─ fn_update_table_statuses_for_slots(business_id)
│  ├─ Updates table status based on reservation timing
│  ├─ Handles buffer window (30 min before reservation)
│  ├─ Handles grace period (15 min after reservation)
│  └─ Auto-expires no-show reservations
│
├─ fn_expire_stale_reservations(business_id)
│  └─ Backward-compatible wrapper
│
└─ Views:
   ├─ vw_tables_with_reservation (existing)
   │  └─ Provides table + reservation data to Flutter
   │
   └─ vw_table_reservation_status (new)
      └─ Shows reservation state calculation at each moment
```

---

## Database Functions Deep Dive

### `fn_update_table_statuses_for_slots(business_id)`

**Purpose**: Sync table statuses with reservation time windows

**Called by**: Flutter app every 60 seconds via `_updateSlotStatuses()`

**Logic**:

```
Part 1: Mark tables as 'RESERVED'
  ├─ Find all restaurants_tables with status NOT IN ('occupied', 'cleaning')
  ├─ Check if any active reservation exists for that table
  ├─ If NOW() is in buffer window (30 min before → 15 min after)
  │  └─ SET status = 'reserved'
  └─ Result: Tables in time window marked unavailable for walk-ins

Part 2: Mark tables as 'AVAILABLE'
  ├─ Find all tables currently marked 'reserved'
  ├─ Check if any active reservation is in time window
  ├─ If NOT in time window
  │  └─ SET status = 'available'
  └─ Result: Tables freed when reservation window closes

Part 3: Auto-EXPIRE RESERVATIONS
  ├─ Find all 'active' reservations where check_in IS NULL
  ├─ Check if NOW() >= (reserved_for + 15 minutes)
  ├─ If past grace period and no check-in
  │  ├─ SET reservation.status = 'no_show'
  │  └─ SET reservation.updated_at = NOW()
  └─ Result: Stale reservations marked, tables freed automatically
```

**Pseudo-code**:

```sql
FUNCTION fn_update_table_statuses_for_slots(business_id)

  -- Part 1: Mark reserved
  UPDATE restaurant_tables
  SET status = 'reserved'
  WHERE business_id = ?
    AND EXISTS (active reservation in buffer window)

  -- Part 2: Mark available
  UPDATE restaurant_tables
  SET status = 'available'
  WHERE status = 'reserved'
    AND NOT EXISTS (active reservation in buffer window)

  -- Part 3: Expire old reservations
  UPDATE table_reservations
  SET status = 'no_show'
  WHERE status = 'active'
    AND check_in IS NULL
    AND NOW() >= (reserved_for + 15 minutes)

  RETURN {
    tables_marked_reserved: count,
    tables_marked_available: count,
    reservations_expired: count
  }
```

---

## Reservation Lifecycle

### Timeline for a Single Table

```
Table 12 (4 seats) - Reservation: John Doe, 2:43 PM

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TIME: 2:10 PM (33 min before reservation)
  Status in DB: 'available'
  Status in App: "Available"
  Walk-in seating: ✅ Allowed
  Reason: Not yet in buffer window

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TIME: 2:13 PM (30 min before) ← BUFFER WINDOW STARTS
  Periodic check runs:
    └─ fn_update_table_statuses_for_slots() called
    └─ Detects reservation in buffer window
    └─ UPDATE restaurant_tables SET status = 'reserved'

  Status in DB: 'reserved'
  Status in App: "Reserved" (with customer name)
  Walk-in seating: ❌ Blocked
  Reason: In buffer window (staff notified)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TIME: 2:43 PM (reservation time) ← BUFFER WINDOW ENDS
  Status in DB: 'reserved' (still)
  Status in App: "Reserved"

  Scenario A: Customer Arrives
  ├─ Staff taps "Check In" → fn_seat_guest_v2()
  ├─ UPDATE table_reservations SET check_in = NOW(), status = 'seated'
  ├─ UPDATE restaurant_tables SET status = 'occupied'
  └─ Flutter: Shows "Occupied - John Doe (0m)"

  Scenario B: Customer Delayed (still coming)
  ├─ Status stays 'reserved'
  ├─ Grace period (15 min) still active
  └─ Waiter can call customer

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TIME: 2:58 PM (15 min after reservation) ← GRACE PERIOD ENDS
  Periodic check runs:

  Scenario A (Customer arrived at 2:50):
  ├─ Reservation status = 'seated'
  ├─ Expiry logic SKIPS (status != 'active')
  ├─ Table status = 'occupied'
  └─ No change - everything fine

  Scenario B (Customer never showed):
  ├─ Reservation still status = 'active'
  ├─ check_in = NULL
  ├─ Now PAST grace period
  ├─ fn_update_table_statuses_for_slots() expires it:
  │  └─ UPDATE table_reservations SET status = 'no_show'
  │  └─ UPDATE restaurant_tables SET status = 'available'
  ├─ Status in DB: 'available'
  ├─ Status in App: "Available" [notification: "Expired: John Doe"]
  ├─ Walk-in seating: ✅ Allowed again
  └─ Table freed automatically

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TIME: 3:00 PM (ongoing available)
  Status in DB: 'available'
  Status in App: "Available"

  Scenario 1: Seat walk-in guest
  └─ Table shows as available, seating allowed

  Scenario 2: New reservation created for 4:30 PM
  └─ Status stays 'available' (reservation not in buffer yet)
  └─ At 4:00 PM (30 min before) → status changes to 'reserved'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## View: `vw_table_reservation_status`

**Purpose**: Calculate and display reservation status logic

**Updated**: Every database query (no caching)

**Columns**:

```sql
table_id              → Database ID of table
business_id           → Business that owns table
reservation_id        → ID of reservation (if any)
customer_name         → Name of reservation
reserved_for          → Reservation time
buffer_window_start   → When table becomes reserved (START)
buffer_window_end     → When buffer ends (at reservation time)
grace_period_start    → When grace period starts (at reservation time)
grace_period_end      → When grace period ends (15 min after)
current_table_status  → What status table should be RIGHT NOW
                        ├─ 'available' (no reservation or past grace)
                        ├─ 'reserved' (in buffer/grace window)
                        └─ 'should_expire' (past grace, never checked in)
needs_expiry          → Boolean flag for expiry candidates
```

**Example Query**:

```sql
SELECT
  table_id,
  current_table_status,
  customer_name,
  reserved_for,
  buffer_window_start,
  grace_period_end,
  needs_expiry
FROM vw_table_reservation_status
WHERE business_id = 'biz_123'
ORDER BY reserved_for;

Result:
┌──────────┬─────────────────┬──────────────┬───────────┬──────┬──────┬────────┐
│ table_id │ current_status  │ customer     │ reserved  │ buff │ grace│ expire │
├──────────┼─────────────────┼──────────────┼───────────┼──────┼──────┼────────┤
│ t1       │ reserved        │ John Doe     │ 2:43 PM   │ 2:13 │ 2:58 │ false  │
│ t2       │ available       │ (none)       │           │      │      │ false  │
│ t3       │ should_expire   │ Jane Smith   │ 2:30 PM   │ 2:00 │ 2:45 │ true   │
└──────────┴─────────────────┴──────────────┴───────────┴──────┴──────┴────────┘
```

---

## Integration with Flutter App

### Every 60 Seconds

```dart
_runPeriodicChecks() {
  // 1. Try to expire old reservations
  await _expireStaleReservations();
  // └─ Calls: fn_expire_stale_reservations(business_id)

  // 2. Update table status windows
  await _updateSlotStatuses();
  // └─ Calls: fn_update_table_statuses_for_slots(business_id)
  // └─ If function doesn't exist, silently continues

  // 3. Check notifications
  _notif.checkAll(...);
}
```

### Realtime Subscriptions

```dart
// App subscribes to changes on:
- restaurant_tables (any status change)
  └─ Triggers: _refreshAll() → ReloadUI

- table_reservations (any status/check_in change)
  └─ Triggers: _refreshAll() → ReloadUI

- table_seats (any seat status change)
  └─ Triggers: _refreshAll() → ReloadUI
```

### Table Display Logic

```dart
RestaurantTable table = /* from database */;

if (table.status == TableStatus.occupied) {
  // Show: "Table 12 - John Doe (45m)"
  display OccupiedSection + (walk-in if partial seats free)

} else if (table.status == TableStatus.reserved &&
           table.reservation != null) {
  // Show: "RESERVED for John Doe at 2:43 PM"
  // Show: "Check In" button when time arrives
  display ReservationSection

} else if (table.status == TableStatus.reserved &&
           table.reservation == null) {
  // Debug state: reserved but no data
  // Show: "Sync" button to retry
  display InconsistencyWarning + AvailableSection

} else {
  // Show: "Available • Seats 1,2,3,4"
  display AvailableSection
}
```

---

## Configuration Constants

These are hardcoded in the database functions:

| Parameter                     | Value              | Reason                                       |
| ----------------------------- | ------------------ | -------------------------------------------- |
| **Buffer Period**             | 30 min before      | Prevents walk-in bookings during setup       |
| **Grace Period**              | 15 min after       | Allows late arrivals                         |
| **Auto-Expiry Status**        | 'no_show'          | Valid status only (not 'expired')            |
| **Reservation Join Statuses** | 'active', 'seated' | Only current reservations affect table state |

To change these, update the SQL functions before deployment.

---

## Deployment Steps Summary

### Step 1: Apply Database Functions (2 min)

```sql
-- File: FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql
-- Runs in: Supabase SQL Editor
-- Contents:
--   ✅ Check constraint on table_reservations status
--   ✅ View: vw_table_reservation_status
--   ✅ Function: fn_update_table_statuses_for_slots()
--   ✅ Function: fn_expire_stale_reservations() [updated]
--   ✅ Schema reload notification
```

### Step 2: Verify View (May already exist)

```sql
-- File: FIX_RESERVATION_DATA_VIEW_2026_03_26.sql
-- Check if vw_tables_with_reservation has reservation_data column
```

### Step 3: Restart Flutter App (30 sec)

- Close app completely
- Reopen
- No code changes needed (!!)

### Step 4: Test (2 min)

- Create a test reservation for 10 min from now
- Wait for periodic check (max 60 seconds)
- Verify table shows "Reserved" in app

---

## Success Metrics

✅ **Buffer Window Enforcement**

- Create reservation for 5 min from now
- After 30 sec: Verify table shows "Reserved" in app
- Verify walk-in button is disabled

✅ **Automatic Expiration**

- Create reservation for "now"
- Wait 20 minutes (reservation time + 15 min grace)
- Verify table freed and shows "Available"
- Verify no-show notification appears

✅ **Data Consistency**

- Run query: `SELECT * FROM vw_table_reservation_status`
- Verify all tables either have no reservation OR have matching customer_name

✅ **No Schema Errors**

- Check app logs: No "PGRST204" or "PGRST205" errors
- All table queries succeed

---

## Troubleshooting Decision Tree

```
Tables still show "Available" for upcoming reservations?
├─ YES: Function not deployed
│  └─ Run: SELECT proname FROM pg_proc WHERE proname = 'fn_update_table_statuses_for_slots';
│     ├─ If no result:
│     │  └─ Deploy SQL file again
│     │  └─ Restart app
│     └─ If exists:
│        └─ Check: SELECT NOW(); (is server time correct?)
│        └─ Check: SELECT * FROM vw_table_reservation_status;
│
└─ NO: Working correctly! ✅

Reservations not expiring after grace period?
├─ Check: SELECT * FROM table_reservations WHERE status = 'active' AND check_in IS NULL;
├─ Verify times: SELECT NOW(); vs reserved_for + 15 min
└─ Manually trigger: SELECT fn_update_table_statuses_for_slots('BUSINESS_ID');

Inconsistent states (reserved but no reservation)?
├─ This is now handled gracefully:
│  └─ UI shows inconsistency warning
│  └─ User can tap "Sync" to refresh
│
└─ Check view: SELECT * FROM vw_tables_with_reservation WHERE reservation_data IS NULL;
```

---

## Files Provided

| File                                                    | Purpose               | Status     |
| ------------------------------------------------------- | --------------------- | ---------- |
| `FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql`  | Main DB fix           | ✅ Created |
| `DEPLOYMENT_GUIDE_RESERVATION_VISIBILITY_2026_03_26.md` | Detailed guide        | ✅ Created |
| `QUICK_START_RESERVATION_FIX_2026_03_26.md`             | Quick reference       | ✅ Created |
| `FIX_RESERVATION_DATA_VIEW_2026_03_26.sql`              | View fix (dependency) | ✅ Exists  |
| `FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql`     | Session handling      | ✅ Exists  |

---

## Support

For issues:

1. Check the **Troubleshooting** section above
2. Review **SQL Verification Queries** in deployment guide
3. Check Supabase logs for function execution errors
4. Verify database time: `SELECT NOW();`

For questions about implementation details, see this file.
