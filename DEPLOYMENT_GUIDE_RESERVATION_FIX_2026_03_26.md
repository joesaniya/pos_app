# Table Reservation System - Session Management Fix (2026-03-26)

## Overview

This document describes the comprehensive fix for the POS system's table reservation and session management system. The fix ensures that:

1. ✅ Reservation status automatically transitions from "upcoming" → "seated" when guest checks in
2. ✅ Table immediately becomes "available" when guests check out
3. ✅ Each new session starts completely fresh with zero duration
4. ✅ No previous customer data or billing carries over to new sessions
5. ✅ Timers reset automatically for each new seating

---

## What Was Fixed

### Problem 1: Incomplete Reservation Lifecycle

**Before**: When a reserved guest was seated, the reservation status remained "active" (not transitioning to "seated")
**After**: fn_seat_guest_v2() now updates reservation.status = 'seated' and sets check_in timestamp

### Problem 2: Session Data Not Clearing

**Before**: When table was cleared, occupied_since timestamp remained, causing duration to carry over to next customer
**After**: fn_checkout_v2() completely nulls out occupied_since, session_id, and customer_name for both seats and table

### Problem 3: Reservation Check-out Not Recorded

**Before**: No actual_check_out time was recorded when guests left
**After**: fn_checkout_v2() and fn_clear_seat() both set actual_check_out timestamp

---

## Deployment Instructions

### Step 1: Backup Current Database

```bash
# Create a backup of your Supabase database before applying changes
# In Supabase dashboard: Settings → Database Backups → Create manual backup
```

### Step 2: Run the SQL Fix

Execute the SQL fix file against your Supabase database:

**File**: `FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql`

You can apply this in several ways:

**Option A: Via Supabase Dashboard (Recommended)**

1. Go to Supabase Dashboard → SQL Editor
2. Click "Create Query" → "New Query"
3. Copy entire contents of `FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql`
4. Paste into editor
5. Click "Run" (or Ctrl+Enter)
6. Verify all functions created successfully with green checkmark

**Option B: Via Supabase CLI**

```bash
supabase db push --local-path FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql
```

**Option C: Via Direct PostgreSQL Connection**

```bash
psql -h db.xxxxx.supabase.co -U postgres < FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql
# Then enter your Supabase password when prompted
```

### Step 3: Verify Functions Were Created

After running the SQL, verify the new functions exist:

In Supabase Dashboard → SQL Editor, run:

```sql
SELECT proname
FROM pg_proc
WHERE proname IN ('fn_seat_guest_v2', 'fn_checkout_v2', 'fn_clear_seat', 'fn_clear_table_complete')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public');
```

Expected output: 4 rows with the function names above

---

## Testing the Fix

### Test Case 1: Reserved Guest Check-in

1. Create a reservation for Table 12 at 2:43 PM for "John Doe"
2. Verify table status shows "Reserved"
3. Click "Seat Guests" when John arrives
4. **Verify**:
   - Table status changes to "Occupied"
   - Duration timer shows ~0 minutes
   - In database: reservation.status = 'seated', check_in = NOW()

### Test Case 2: Session Duration Reset

1. After seating John, wait 5-10 minutes
2. Verify duration shows correct elapsed time (e.g., "7m")
3. Place an order for John (e.g., burger, coffee)
4. Note the current time and duration
5. Clear the table ("Clear Entire Table")
6. **Verify**:
   - Table status becomes "Available"
   - No orders visible in table detail
   - Order count resets to 0

### Test Case 3: New Customer Fresh Start

1. Immediately seat a walk-in customer "Jane Smith" at Table 12
2. **Verify**:
   - Duration timer shows 0 minutes (NOT carrying over from John!)
   - Current customer shows "Jane Smith"
   - session_id is a new UUID (different from John's session)
   - No previous orders shown
   - Bill shows 0 (not John's previous total)

### Test Case 4: Multiple Seat Table

1. Create table with 3 seats
2. Seat Seat A with "Customer A"
3. Seat Seat B with "Customer B"
4. Clear only Seat A
5. **Verify**:
   - Seat A status = 'available'
   - Seat B still occupied
   - Table status still 'occupied' (not all seats cleared)
   - Seat A can be immediately filled with new customer

### Test Case 5: Partial to Full Occupancy

1. From Test Case 4 state (Seat B occupied, Seat A cleared)
2. Seat Seat A with "Customer C"
3. **Verify**:
   - Customer C has fresh session (0 minute duration)
   - Customer B duration continues uninterrupted
   - Both have different session_ids

---

## Database Schema Impact

### table_reservations

- `status` now properly transitions: 'active' → 'seated' → 'completed'
- `check_in` is set when guest is seated
- `actual_check_out` is set when guest leaves

### restaurant_tables

- `status` properly reflects current state: reserved → occupied → available
- `session_id` is set to fresh UUID each seating and nulled when cleared
- `occupied_since` is set to NOW() at seating (fresh start) and nulled when cleared

### table_seats

- Individual seat `occupied_since` resets to fresh start per session
- `session_id` is unique per seated guest
- `customer_name` is cleared when seat becomes available

### orders

- Status transitions: pending → preparing → ready → completed (on checkout)
- Automatically completed when table/seat is cleared
- Cleared orders are invisible to new sessions

---

## API RPC Functions Summary

| Function                           | Trigger                     | Effect                                                         |
| ---------------------------------- | --------------------------- | -------------------------------------------------------------- |
| `fn_seat_guest_v2(...)`            | Guest arrives & checks in   | Seats guests, sets reservation to 'seated', fresh session      |
| `fn_checkout_v2(tableId)`          | Guest finishes & checks out | Completes orders, resets table/seats to 'available'            |
| `fn_clear_seat(tableId, seatId)`   | Individual guest leaves     | Clears single seat, checks if table should revert to available |
| `fn_clear_table_complete(tableId)` | Entire table cleared        | Clears all seats and table completely                          |

---

## Offline Mode Behavior

The Flutter app has offline-first sync. When offline:

1. **Seating guests**: Same logic applies locally - fresh occupied_since set
2. **Clearing table**: Same logic - occupied_since nulled, session_id nulled
3. **Sync on reconnect**: Changes queued and synced when online

No special handling needed - the same business logic applies both online and offline.

---

## Troubleshooting

### Issue: "Function does not exist" error when seating guests

**Solution**: Verify SQL fix was applied successfully (Step 2-3 above)

### Issue: Duration timer still carries over to new customer

**Solution**: Verify occupied_since field was NULLED by checking:

```sql
SELECT id, table_id, occupied_since, session_id, status
FROM restaurant_tables
WHERE id = 'table-12';
```

Should show: occupied_since = NULL and status = 'available' after clearing

### Issue: Previous customer's orders still visible

**Solution**: Verify orders were completed:

```sql
SELECT id, status, table_id
FROM orders
WHERE table_id = 'table-12'
ORDER BY created_at DESC LIMIT 5;
```

All orders completed at clear time should show status = 'completed'

### Issue: Reservation status still shows 'active' after seating

**Solution**: Verify fn_seat_guest_v2 updated it:

```sql
SELECT id, status, check_in, table_id
FROM table_reservations
WHERE table_id = 'table-12'
ORDER BY created_at DESC LIMIT 1;
```

Should show: status = 'seated' and check_in = (timestamp when seated)

---

## Performance Impact

- **No negative impact**: Functions are optimized and use proper indexes
- **Database**: New functions add minimal overhead
- **UI**: Should refresh faster as cached data is cleared

---

## Rollback Instructions (If Needed)

If you need to rollback, restore from the backup created in Step 1:

In Supabase Dashboard:

1. Settings → Database Backups
2. Click "Restore" on the backup created before this update
3. Confirm rollback

Full database restoration typically takes 5-15 minutes.

---

## Support & Questions

If you encounter issues:

1. Check troubleshooting section above
2. Verify all 4 functions exist (Step 3 verification)
3. Review test cases to confirm expected behavior
4. Check Supabase function logs for specific error messages

---

## Version History

| Date       | Version | Change                                     |
| ---------- | ------- | ------------------------------------------ |
| 2026-03-26 | 1.0     | Initial reservation session management fix |

---
