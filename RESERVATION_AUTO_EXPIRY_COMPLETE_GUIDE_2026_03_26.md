# Reservation Auto-Expiry System - Complete Implementation Guide

**Date:** March 26, 2026  
**Version:** 2.0 - Full Auto-Expiry with 'Expired' Status  
**Status:** ✅ READY FOR DEPLOYMENT

---

## 🎯 Executive Summary

The reservation system now properly handles the complete reservation lifecycle with automatic expiry for no-show reservations:

```
RESERVATION LIFECYCLE:
┌─────────────────────────────────────────────────────────────────┐
│  Reserved/Upcoming → Active → [Seated → Completed] OR Expired   │
└─────────────────────────────────────────────────────────────────┘

Timeline:
  2:00 PM (reserved_for)       ← Reservation slot begins
  2:00-2:15 PM                 ← Grace period (customer can still arrive)
  2:15 PM (+15 min grace)      ← Grace period ends
  IF check_in NOT MADE:        ← Auto-expire to 'EXPIRED' status
  • Reservation status: 'expired' (NOT 'completed' - no service)
  • Table status: 'available' (immediately released)
  • Seats status: 'available' (immediately released)
```

### Key Improvements

| Aspect            | Before                 | After                                          |
| ----------------- | ---------------------- | ---------------------------------------------- |
| **Expiry Status** | 'no_show' (unclear)    | 'expired' (explicit - no service)              |
| **Table Release** | Manual or inconsistent | Atomic (immediate & guaranteed)                |
| **Seats Release** | Partial or delayed     | Complete (all seats freed)                     |
| **Audit Trail**   | Limited metadata       | Rich metadata (auto_expired_at, expiry_reason) |
| **Atomicity**     | Multiple updates       | Single transaction (all or nothing)            |

---

## 🔧 Changes Made

### 1. Database Schema Updates

#### ✅ Status Check Constraint Extended

```sql
-- Added 'expired' to allowed statuses
CHECK (status IN ('active', 'seated', 'expired', 'no_show', 'completed', 'cancelled'))

-- Status Meanings:
-- 'active'     - Reservation created, awaiting check-in
-- 'seated'     - Guest checked in, currently at table
-- 'expired'    - Guest didn't arrive (grace period passed) → NO SERVICE
-- 'no_show'    - Manually marked by staff (e.g., called to cancel)
-- 'completed'  - Service finished, guest left
-- 'cancelled'  - Staff cancelled reservation
```

#### ✅ Table & Reservation Metadata Columns

```sql
table_reservations:
  - auto_expired_at TIMESTAMPTZ    -- When auto-expiry triggered
  - expiry_reason TEXT             -- Reason code for audit

restaurant_tables:
  - freed_at TIMESTAMPTZ           -- When table/seats freed
  - freed_by_system VARCHAR(50)    -- Source of freedom (e.g., 'reservation_expiry')
```

### 2. SQL Functions (Atomic & Robust)

#### ✅ `fn_expire_single_reservation(reservation_id, reason)`

**Purpose:** Atomically expire one reservation

**What it does (single transaction):**

1. Validates reservation exists
2. Sets reservation status → 'expired'
3. Records auto_expired_at timestamp
4. Frees associated table (reserved → available)
5. Frees all associated seats
6. Returns success/failure with audit details

**Atomicity Guarantee:**

- If ANY step fails → entire transaction rolls back
- No partial state (either fully expired OR unchanged)
- Prevents half-freed tables/seats

**Example:**

```sql
SELECT fn_expire_single_reservation('res-12345', 'grace_period_expired');
-- Returns: {
--   "success": true,
--   "reservation_id": "res-12345",
--   "status": "expired",
--   "seats_freed": 4,
--   "expired_at": "2026-03-26T14:15:30Z"
-- }
```

#### ✅ `fn_expire_stale_reservations(business_id, grace_period_minutes=15)`

**Purpose:** Batch-process all stale reservations

**Criteria for expiry:**

- status = 'active'
- check_in IS NULL (guest never arrived)
- reserved_for + grace_period < NOW()

**Flow:**

1. Query all matching reservations
2. Call fn_expire_single_reservation() for each
3. Collect results for audit log
4. Return summary (count, IDs, timestamp)

**Example:**

```sql
SELECT fn_expire_stale_reservations('biz-456', 15);
-- Returns: {
--   "success": true,
--   "expired_count": 3,
--   "expired_ids": ["res-1", "res-2", "res-3"],
--   "grace_period_minutes": 15,
--   "checked_at": "2026-03-26T14:16:00Z"
-- }
```

### 3. Flutter Application Updates

#### ✅ `tables_provider.dart` - Main Expiry Logic

```dart
// Primary mechanism (calls database function)
Future<void> _expireStaleReservations() async {
  final result = await _sb.rpc(
    'fn_expire_stale_reservations',
    params: {'p_business_id': businessId},
  );
  // Sends notifications & refreshes UI
}

// Fallback mechanism (local expiry if DB unavailable)
Future<void> _localExpireStaleReservations() async {
  // Manually checks conditions
  // Calls database updates directly
  // Uses 'expired' status (NOT 'no_show')
  // Releases tables & seats
  // Falls back to local processing if RPC fails
}
```

#### ✅ `table_modal.dart` - Reservation Model

```dart
// Updated to handle 'expired' status
String get statusLabel {
  case 'expired':
    return '⏰ Expired';  // Clear visual indicator
  // ... other cases
}

// Treats 'expired' like 'cancelled'/'no_show' for UI grouping
if (status == 'cancelled' || status == 'no_show' || status == 'expired') {
  cancelledAt = updatedAt;  // Mark as unavailable
}
```

#### ✅ `background_task_service.dart` - Background Process

```dart
// Updated legacy expiry path to also use 'expired' status
UPDATE status = 'expired'
SET auto_expired_at = NOW(), expiry_reason = 'grace_period_expired'
```

---

## 📊 Audit & Reporting

### New View: `vw_reservation_expiry_audit`

Shows complete lifecycle of every reservation:

```sql
SELECT * FROM vw_reservation_expiry_audit WHERE lifecycle_status = 'EXPIRED_AUTO';
```

**Provides:**

- reservation_status: 'expired'
- auto_expired_at: timestamp
- expiry_reason: 'grace_period_expired'
- minutes_past_reservation: how long overdue
- lifecycle_status: 'EXPIRED_AUTO' (clear indicator)

---

## ✅ Testing Checklist

### Pre-Deployment Tests (Run on Test Database)

#### Test 1: Schema Verification

```sql
-- Verify constraint includes 'expired'
SELECT pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conname = 'table_reservations_status_check';
-- Should show: IN ('active','seated','expired','no_show','completed','cancelled')
```

#### Test 2: Functions Exist

```sql
-- Verify both functions exist
SELECT proname FROM pg_proc
WHERE proname IN ('fn_expire_single_reservation', 'fn_expire_stale_reservations');
-- Should return 2 rows
```

#### Test 3: Columns Exist

```sql
-- Verify new audit columns
SELECT column_name FROM information_schema.columns
WHERE table_name = 'table_reservations'
AND column_name IN ('auto_expired_at', 'expiry_reason');
-- Should return 2 rows
```

#### Test 4: Manual Single Expiry (Requires Test Data)

```sql
-- Create a test reservation 20 minutes in the past, no check-in
INSERT INTO table_reservations (id, table_id, business_id, customer_name,
  reserved_for, status)
VALUES ('test-1', 'table-1', 'biz-1', 'Test Guest',
  NOW() - INTERVAL '20 minutes', 'active');

-- Expire it
SELECT fn_expire_single_reservation('test-1', 'test_manual');

-- Verify
SELECT status, auto_expired_at, expiry_reason
FROM table_reservations WHERE id = 'test-1';
-- Should show: ('expired', NOW(), 'test_manual')
```

#### Test 5: Batch Expiry (Creates Test Data)

```sql
-- Create 3 test reservations, all overdue
INSERT INTO table_reservations (id, table_id, business_id, customer_name,
  reserved_for, status)
VALUES
  ('test-2', 'table-2', 'biz-1', 'Guest 1', NOW() - INTERVAL '20 min', 'active'),
  ('test-3', 'table-3', 'biz-1', 'Guest 2', NOW() - INTERVAL '30 min', 'active'),
  ('test-4', 'table-4', 'biz-1', 'Guest 3', NOW() - INTERVAL '25 min', 'active');

-- Batch expire all
SELECT fn_expire_stale_reservations('biz-1', 15);
-- Should return: { "expired_count": 3, ... }

-- Verify
SELECT COUNT(*) FROM table_reservations
WHERE business_id = 'biz-1' AND status = 'expired';
-- Should show: 3
```

### Runtime Tests (After Deployment)

#### Test 6: Automatic Expiry via Background Service

**Setup:**

1. Create a reservation for NOW (immediate, not future)
2. Leave check_in as NULL
3. Wait 2-3 minutes for background service to run

**Verify:**

- Reservation status changed to 'expired' ✅
- Table status changed to 'available' ✅
- Seats status changed to 'available' ✅
- auto_expired_at timestamp recorded ✅
- Log message appears: `[Expiry] ✅ Auto-expired X stale reservation(s)` ✅

#### Test 7: Grace Period Boundary

**Setup:**

1. Create reservation at time T
2. Create another at time T-14 (within grace period)
3. Create another at time T-16 (past grace period)

**After background run:**

- Reservation at T: stays 'active' ✅
- Reservation at T-14: stays 'active' ✅
- Reservation at T-16: becomes 'expired' ✅

#### Test 8: Check-In Prevents Expiry

**Setup:**

1. Create reservation 40 minutes ago
2. Check-in the guest (set check_in timestamp)
3. Wait for background service

**Verify:**

- Reservation stays 'active' or 'seated' ✅
- NOT changed to 'expired' ✅

#### Test 9: Table/Seat Release Verification

**Setup:**

1. Create reservation with table and seats
2. Mark table as 'reserved'
3. Mark seats as 'reserved'
4. Let auto-expiry trigger

**Verify from DB:**

```sql
-- All seats should be 'available'
SELECT * FROM table_seats WHERE table_id = 'table-X';
-- status should all be 'available'

-- Table should be 'available'
SELECT status, freed_at, freed_by_system
FROM restaurant_tables WHERE id = 'table-X';
-- status='available', freed_by_system='reservation_expiry'
```

#### Test 10: UI Display

**Setup:**

1. After reservations expire in DB
2. Open app and reload

**Verify:**

- Expired reservations show with ⏰ icon ✅
- Status label shows "⏰ Expired" ✅
- Table shows as 'Available' ✅
- Staff can book same table immediately ✅

---

## 🚀 Deployment Steps

### Phase 1: Database Deployment (Production)

**Prerequisites:**

- ✅ Backup Supabase database
- ✅ Have SQL file: `RESERVATION_AUTO_EXPIRY_FIX_2026_03_26.sql`
- ✅ Access to Supabase SQL Editor

**Steps:**

1. **Backup Database** (CRITICAL)

   ```bash
   # In Supabase dashboard:
   # - Project Settings → Backups
   # - Create manual backup
   # - Wait for completion
   ```

2. **Deploy SQL File**

   ````
   - Open Supabase SQL Editor
   - Paste entire RESERVATION_AUTO_EXPIRY_FIX_2026_03_26.sql
   - Click "Run"
   - Monitor for errors (check for red messages)
   - Should see "NOTIFY pgrst, 'reload schema'" at end
   ![alt text](image.png)   ```

   ````

3. **Verify Deployment**

   ```sql
   -- Run these in SQL Editor to confirm:

   -- ✅ Functions exist
   SELECT proname FROM pg_proc
   WHERE proname IN ('fn_expire_single_reservation', 'fn_expire_stale_reservations');

   -- ✅ Constraint updated
   SELECT pg_get_constraintdef(oid)
   FROM pg_constraint WHERE conname = 'table_reservations_status_check';

   -- ✅ View exists
   SELECT column_name FROM information_schema.columns
   WHERE table_name = 'vw_reservation_expiry_audit' LIMIT 1;
   ```

### Phase 2: Flutter Application Deployment

**Files Modified:**

- ✅ `lib/providers/tables_provider.dart` - Main expiry + fallback
- ✅ `lib/models/table_modal.dart` - 'expired' status label
- ✅ `lib/services/background_task_service.dart` - Legacy path update

**Steps:**

1. **Pull Latest Code**

   ```bash
   git pull origin main
   # or merge the changes if on different branch
   ```

2. **Verify Files Updated**

   ```bash
   # Check that these have 'expired' not 'no_show'
   grep -n "status.*=.*'expired'" lib/providers/tables_provider.dart
   grep -n "case 'expired'" lib/models/table_modal.dart
   grep -n "'expired'" lib/services/background_task_service.dart
   ```

3. **Run Tests**

   ```bash
   flutter test  # If you have unit tests
   ```

4. **Build APK/App**

   ```bash
   flutter build apk --release  # Android
   flutter build ipa --release  # iOS
   ```

5. **Deploy to Store**
   - Upload to Google Play / App Store
   - Or distribute via beta testing

### Phase 3: Verification (24-48 Hours)

**Daily Checks:**

```
DAY 1:
☐ Check Supabase logs for "[Expiry] ✅ Auto-expired" messages
☐ Manual test: Create 2 reservations, let one expire
☐ Verify expired reservation shows ⏰ Expired status
☐ Verify table immediately available for new booking
☐ Check for any errors in logs

DAY 2:
☐ Check overall reservation status distribution
☐ Verify no orphaned reserved tables
☐ Test with multiple time zones (IST vs others)
☐ Verify UI update works properly
```

**Monitoring Query:**

```sql
-- Run daily to check expiry health
SELECT
  COUNT(*) as total_active,
  COUNT(*) FILTER (WHERE status = 'expired') as expired_count,
  COUNT(*) FILTER (WHERE status = 'expired' AND auto_expired_at IS NOT NULL) as auto_expired
FROM table_reservations
WHERE business_id = 'YOUR_BUSINESS_ID'
  AND created_at > NOW() - INTERVAL '7 days';
```

---

## 🐛 Troubleshooting

### Issue 1: "Check constraint violation - invalid value for status"

**Cause:** SQL file executed out of order or constraint still has old values  
**Solution:**

```sql
-- Re-run just the constraint update part:
ALTER TABLE public.table_reservations
DROP CONSTRAINT IF EXISTS table_reservations_status_check;

ALTER TABLE public.table_reservations
ADD CONSTRAINT table_reservations_status_check
CHECK (status IN ('active', 'seated', 'expired', 'no_show', 'completed', 'cancelled'));
```

### Issue 2: "Function fn_expire_stale_reservations not found"

**Cause:** SQL file partial execution, function not created  
**Solution:**

- Run entire SQL file again from beginning
- Check for any error messages during execution
- Verify function exists: `SELECT proname FROM pg_proc WHERE proname = 'fn_expire_stale_reservations';`

### Issue 3: Tables not being freed after expiry

**Cause 1:** Function ran but table still 'reserved'  
**Solution:** Check if condition in UPDATE was too strict

```sql
-- Verify freed_at is set
SELECT table_id, status, freed_at, freed_by_system
FROM restaurant_tables
WHERE freed_by_system = 'reservation_expiry'
ORDER BY freed_at DESC LIMIT 10;
```

**Cause 2:** Expiry function never called  
**Solution:** Check background service logs, verify \_expireStaleReservations() being called

### Issue 4: Reservations showing "Expired" but should show "No Show"

**Cause:** Both 'expired' and 'no_show' now possible - need to distinguish  
**Solution:** Check app version, use statusLabel to display correct icon:

```dart
// Should show:
// 'expired' → ⏰ Expired (automatic)
// 'no_show' → 👻 No Show (manual staff action)
```

### Issue 5: Old "expired" status values in database

**Cause:** Previous attempts may have set invalid 'expired' values before constraint added  
**Solution:**

```sql
-- Safely clean up any problematic data
UPDATE table_reservations
SET status = 'no_show'
WHERE status NOT IN ('active', 'seated', 'expired', 'no_show', 'completed', 'cancelled');
```

---

## 📋 Summary: Before & After

### Before Fix

```
Reservation Timeline:
2:00 PM - Reserved slot time
2:15 PM - Grace period ends
2:20 PM - Guest still hasn't arrived
2:30 PM - Still shows "active"! ❌
2:45 PM - Still shows "active"! ❌
Next day - Finally showing "no_show" (manual review)

Table Status:
- Stuck as "reserved" for hours ❌
- Not available for new bookings ❌
- May show as occupied if there was any check-in attempt ❌
```

### After Fix

```
Reservation Timeline:
2:00 PM - Reserved slot time
2:15 PM - Grace period ends
2:16 PM - Background service runs
2:16 PM - Change to "expired" ✅
2:16 PM - Table freed ✅
2:16 PM - All seats freed ✅
2:16 PM - Available for immediate rebooking ✅

Table Status:
- Automatically changed to "available" ✅
- Seats all cleared ✅
- Staff notified ✅
- Audit trail recorded ✅
```

---

## 📞 Support & Questions

**For Issues:**

1. Check logs: `[Expiry]` keyword
2. Run verification queries from "Testing Checklist"
3. Review "Troubleshooting" section above
4. Backup and restore if needed

**Key Contacts:**

- Database: Supabase support
- App: Flutter team
- Reservations: System admin

---

## ✨ Complete!

The auto-expiry system is now **production-ready** with:

- ✅ Proper 'expired' status distinct from 'completed'
- ✅ Atomic transactions (no partial state)
- ✅ Immediate table & seat release
- ✅ Comprehensive audit trail
- ✅ Fallback mechanisms
- ✅ Test procedures
- ✅ Troubleshooting guide

**Next Steps:**

1. ✅ Deploy SQL to production database
2. ✅ Deploy Flutter app with updated code
3. ✅ Run test scenarios from checklist
4. ✅ Monitor for 48 hours
5. ✅ Document any issues found
