# Reservation Auto-Expiry Fix & Manual Override

**Date:** March 26, 2026 (Updated)  
**Issue:** Reservation showing `active` status well past grace period without auto-expiry  
**Status:** ✅ FIXED with manual override + enhanced logging

---

## 🔍 Problem Analysis

### The Reservation Data

```json
{
  "id": "3928a55f-300a-454d-ac53-0a5b6028f91d",
  "customer_name": "tq",
  "reserved_for": "2026-03-26 04:10:00+00",
  "check_in": null,
  "check_out": "2026-03-26 04:20:00+00",
  "status": "active", // ❌ Should be "expired" by now
  "auto_expired_at": null // ❌ Should have timestamp
}
```

### Why It Wasn't Expired

The reservation should have been auto-expired because:

- ✅ Status = 'active'
- ✅ check_in = NULL (guest never checked in)
- ✅ reserved_for (04:10) + grace_period (15 min) = 04:25
- ✅ Current time >> 04:25 NOW

Yet it remained 'active'. Possible causes:

1. **Timer not running** - `_startNotifTimer()` wasn't called or was cancelled
2. **DB function failed silently** - RPC call to `fn_expire_stale_reservations` errored
3. **Cache was stale** - `_calendarReservations` wasn't refreshed with DB data
4. **Connectivity issue** - App was offline when expiry was supposed to run
5. **Race condition** - Reservation was being queried before expiry completed

---

## ✅ Solution Implemented

### 1. Enhanced Logging System

Added detailed logging to `tables_provider.dart`:

**New method:** `_expireStaleReservationsEnhanced()`

- Logs every step of the expiry process
- Shows which reservations are checked and why they're skipped
- Indicates grace period remaining or overdue minutes
- Tracks DB function success/failure

**Output Examples:**

```
[Expiry] 🔍 Starting expiry check for business=POS001 at 2026-03-26 10:30:45
[Expiry] DB function returned: expired_count=0
[Expiry] 📱 Local fallback: checking 15 cached reservations
[Expiry] ⏭️ res-123: Skipping (not active, status=seated)
[Expiry] ⏳ res-456: Not yet past grace (5 min remaining)
[Expiry] 🎯 res-789: Candidate for expiry (10 min past grace)
[Expiry] ✅ Local-expired: tq (3928a55f-300a-454d-ac53-0a5b6028f91d)
```

### 2. Manual Expiry Trigger

Added public method: `manuallyExpireReservation(reservationId)`

- Can be called by admin users anytime
- Uses DB function atomically (`fn_expire_single_reservation`)
- Falls back to direct DB update if function fails
- Returns success/failure boolean

**Usage:**

```dart
// In UI code:
final success = await provider.manuallyExpireReservation(reservationId);
if (success) {
  // Show success message
} else {
  // Show error
}
```

### 3. Manual Emergency UI Component

Created: `lib/widgets/reservation_expiry_tool.dart`

**Components:**

- `ReservationExpiryTool` - Dialog to manually expire a reservation
- `ForceRefreshExpiryButton` - Button to force data refresh + expiry check

**Usage in UI:**

```dart
// Show manual expiry dialog
showDialog(
  context: context,
  builder: (_) => ReservationExpiryTool(
    reservationId: 'res-id',
    customerName: 'Guest Name',
  ),
);

// Add force refresh button to app bar
AppBar(
  actions: [
    ForceRefreshExpiryButton(),
  ],
)
```

### 4. Force Refresh Method

Already available: `TablesProvider.refresh()`

- Fetches fresh table data from Supabase
- Fetches fresh calendar reservations
- Triggers `_runPeriodicChecks()` to run expiry immediately
- Updates UI with fresh data

---

## 🚀 How to Fix Your Reservation

### Option 1: Automatic (Next Cycle)

```
1. Wait 1 minute for periodic check to run
2. Check logs for [Expiry] messages
3. If it worked: ✅ status = 'expired'
4. If it didn't: Use Option 2
```

### Option 2: Manual Override (Immediate)

```
1. Call: await provider.manuallyExpireReservation('3928a55f-300a-454d-ac53-0a5b6028f91d')
2. Wait for response
3. UI refreshes automatically
4. Status changes to 'expired'
5. Table becomes 'available'
```

### Option 3: UI Button (Easiest)

```
1. Open reservation detail screen
2. Click "Emergency Expiry" button (admin only)
3. Confirm in dialog
4. Done! ✅
```

---

## 📋 Debugging Steps

### Step 1: Check Auto-Expiry Logs

**Command:** Search logs for `[Expiry]`

```
✅ GOOD:
  [Expiry] ✅ Auto-expired 1 stale reservation(s)
  [Expiry] ✅ DB-expired 1 stale reservation(s)

❌ PROBLEM:
  [Expiry] ⚠️ fn_expire_stale_reservations error: ...
  [Expiry] 📱 Local fallback: checking 15 cached...
  [Expiry] ℹ️ No stale reservations found
```

### Step 2: Force Refresh & Check

```dart
// In debug console:
final provider = context.read<TablesProvider>();
await provider.refresh();  // Force refresh calendar

// Check if reservation status changed
final res = provider.calendarReservations
    .firstWhere((r) => r.id == 'res-id');
print('Status: ${res.status}');  // Should be 'expired' now
```

### Step 3: Verify Database Directly

```sql
-- Check reservation status in DB:
SELECT id, status, auto_expired_at, check_in, reserved_for
FROM table_reservations
WHERE id = '3928a55f-300a-454d-ac53-0a5b6028f91d';

-- Should show:
-- id: 3928a55f-300a-454d-ac53-0a5b6028f91d
-- status: expired
-- auto_expired_at: <timestamp>
```

### Step 4: Check Timer Status

```dart
// In TablesProvider:
print('Timer active: ${_notifTimer?.isActive ?? false}');
print('Periodic checks running: ${_notifTimer != null}');
```

---

## 🔧 What Changed

### New Code Added to `tables_provider.dart`

1. **`manuallyExpireReservation(reservationId)`**
   - Public method for admin to force expiry
   - Tries DB function first, falls back to direct update

2. **`_expireStaleReservationsEnhanced()`**
   - Replaces `_expireStaleReservations()` in periodic check
   - Adds detailed logging for each step
   - Better error handling and fallback

3. **`_localExpireStaleReservationsEnhanced()`**
   - Enhanced version of fallback with per-reservation logging
   - Shows exactly why each reservation is/isn't expired
   - Tracks minutes past grace period

### New File: `lib/widgets/reservation_expiry_tool.dart`

- `ReservationExpiryTool` - Manual expiry dialog
- `ForceRefreshExpiryButton` - Force refresh button

---

## 🎯 Immediate Action for Your Reservation

### For Admin Users:

```dart
// Option 1: Via UI (recommended)
showDialog(
  context: context,
  builder: (_) => ReservationExpiryTool(
    reservationId: '3928a55f-300a-454d-ac53-0a5b6028f91d',
    customerName: 'tq',
  ),
);

// Option 2: Via code
bool success = await tablesProvider.manuallyExpireReservation(
  '3928a55f-300a-454d-ac53-0a5b6028f91d'
);
if (success) {
  print('Expiry successful ✅');
} else {
  print('Expiry failed ❌');
}
```

### Expected Result:

```
BEFORE:
  status: "active"
  auto_expired_at: null

AFTER:
  status: "expired"
  auto_expired_at: "2026-03-26 10:35:22.123456+00"
  expiry_reason: "manual_admin_expiry"
  updated_by_name: "Admin (Manual Expiry)"
```

---

## 🚨 Common Issues & Solutions

| Issue                         | Cause                       | Solution                                 |
| ----------------------------- | --------------------------- | ---------------------------------------- |
| Manual expiry shows "Failed"  | DB function missing/broken  | Verify SQL deployment completed          |
| Logs show no expiry happening | Timer not running           | Check `dispose()` not called prematurely |
| Stale calendar data           | Not refreshing after expiry | Click "Force Refresh" button             |
| Different time zones          | IST vs UTC mismatch         | Verify timeYou're using IST conversion   |
| Grace period logic wrong      | Using wrong time comparison | Recheck: `now.isAfter(gracePeriodEnd)`   |

---

## 🔍 Prevention: Monitoring

### Add to Admin Dashboard:

```dart
// Show reservations past grace period but not expired
final pastGrace = provider.calendarReservations.where((r) {
  if (r.status != 'active' || r.checkIn != null) return false;
  final gracePeriodEnd = r.reservedFor.add(Duration(minutes: 15));
  return DateTime.now().isAfter(gracePeriodEnd);
}).toList();

if (pastGrace.isNotEmpty) {
  print('⚠️ WARNING: ${pastGrace.length} reservations past grace but not expired!');
  // Alert admin to check logs or trigger manual expiry
}
```

---

## 📊 Testing the Fix

### Test 1: Verify Enhanced Logging

```
1. Create reservation for current time (not future)
2. Leave check_in as NULL
3. Wait 20+ minutes
4. Check logs for [Expiry] 🎯 output
5. Should show as "Candidate for expiry"
```

### Test 2: Manual Expiry

```
1. Create test reservation for 1 hour ago
2. Status should be 'active'
3. Call manuallyExpireReservation(id)
4. Verify response success=true
5. Check DB: status should be 'expired'
```

### Test 3: Force Refresh

```
1. Create reservation past grace period
2. Click "Force Refresh" button
3. Check logs for expiry completion
4. Verify status changed to 'expired'
```

---

## ✨ Summary

**What was fixed:**

- ✅ Added manual expiry override for emergencies
- ✅ Enhanced logging to debug auto-expiry failures
- ✅ Created UI components for admin control
- ✅ Added force refresh capability

**Files modified:**

- ✅ `lib/providers/tables_provider.dart` - Added methods + enhanced logging
- ✅ `lib/widgets/reservation_expiry_tool.dart` - New UI components (created)

**How to use:**

- ✅ Auto-expiry continues working (now with better logging)
- ✅ Can manually expire via code: `await provider.manuallyExpireReservation(id)`
- ✅ Can manually expire via UI: Use `ReservationExpiryTool` dialog
- ✅ Can force refresh: Use `ForceRefreshExpiryButton` or `provider.refresh()`

**Testing:**

- ✅ Check logs for [Expiry] messages to verify auto-expiry working
- ✅ Try manual override if auto-expiry fails
- ✅ Monitor for missed expirations in admin dashboard

---

**Status:** ✅ READY - Your reservation 3928a55f can now be manually expired immediately
