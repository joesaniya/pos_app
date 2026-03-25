# Reservation Visibility & Expiration Fix - Quick Start (2026-03-26)

## What Was Broken ❌

```
2:43 PM - Restaurant reservation for Table 12
Expected: Table shows "Reserved" in app
Actual: Table still shows "Available"

After 2:58 PM (no customer arrival)
Expected: Reservation marked as "no_show", table freed
Actual: Reservation stays "active", table remains locked
```

## What's Fixed ✅

1. **Buffer Window Enforcement** - Tables marked reserved 30 min before reservation time
2. **Automatic Expiration** - No-show reservations auto-expire after 15-min grace period
3. **Table Status Accuracy** - Proper state transitions based on reservation timing
4. **Visibility in App** - Reservation data now consistently visible for reserved tables

---

## Deployment Checklist

### ✅ Step 1: Apply Database Migration

**Time**: 2 minutes  
**File**: `FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql`  
**Action**: Run entire file in Supabase SQL Editor  
**Expected**: No errors, "NOTIFY pgrst, 'reload schema'" executes

```sql
-- If needed, verify first:
SELECT fn_update_table_statuses_for_slots('TEST_BUSINESS_ID');
-- Should return JSON with 'success': true
```

### ✅ Step 2: Verify Prerequisites (If Not Done Yet)

**File**: `FIX_RESERVATION_DATA_VIEW_2026_03_26.sql`  
**Action**: Run if `vw_tables_with_reservation` view doesn't have `reservation_data` column

```sql
-- Check:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'vw_tables_with_reservation'
AND column_name = 'reservation_data';
-- If no row: Run the dependency SQL file above
```

### ✅ Step 3: Restart Flutter App

**Time**: 30 seconds  
**Action**: Close and reopen app (or hot restart in IDE)  
**Expected**:

- App reconnects to Supabase
- `_updateSlotStatuses()` starts running automatically every minute
- No errors in console

### ✅ Step 4: Verify Working

**Time**: 2 minutes  
**Test**: Create test reservation for 5-10 minutes from now

```sql
-- Insert test reservation
INSERT INTO public.table_reservations (
  id, business_id, table_id, customer_name, reserved_for, status,
  check_in, check_out, created_at, updated_at, check_in_name
) VALUES (
  'test_' || gen_random_uuid()::text,
  'YOUR_BUSINESS_ID',
  'TABLE_1',
  'TEST CUSTOMER',
  NOW() + INTERVAL '5 min',
  'active',
  NULL,
  NULL,
  NOW(),
  NOW(),
  'System'
);
```

Then:

1. **Before 5 min**: Table should show "Available" ✅
2. **During next periodic check (max 1 min wait)**: Table should show "Reserved" ✅
3. **After 20 min (5 min reservation + 15 min grace)**: Reservation auto-expires to "no_show" ✅
4. **After expiry**: Table shows "Available" ✅

---

## How It Works - Timeline Example

```
Table 12 reserved for 2:43 PM (capacity: 4, now: 2:05 PM)

2:13 PM (30 min before) ← BUFFER WINDOW STARTS
  └─ fn_update_table_statuses_for_slots() runs
  └─ restaurant_tables SET status='reserved'
  └─ Flutter: Table 12 appears as "Reserved"
  └─ Staff cannot seat walk-ins at this table

2:43 PM (reservation time)
  └─ Table still "reserved"
  └─ Staff taps "Check In" button
  └─ fn_seat_guest_v2() called
  └─ table_reservations SET status='seated', check_in=NOW()
  └─ restaurant_tables SET status='occupied'
  └─ Flutter: Table shows customer name + duration

2:58 PM (15 min grace period ends)
  └─ If check_in IS NULL (no customer arrived):
     └─ fn_update_table_statuses_for_slots() expires reservation
     └─ table_reservations SET status='no_show'
     └─ restaurant_tables SET status='available'
     └─ Flutter: Table shows "Available" with expiry notification
  └─ If check_in IS NOT NULL (already seated):
     └─ No expiry - reservation status='seated'
     └─ Expiry skipped - customer is there!
```

---

## Troubleshooting

### ❌ "Schema cache error PGRST204/PGRST205"

**Solution**: Reload schema in Supabase

```sql
NOTIFY pgrst, 'reload schema';
-- Then restart Flutter app
```

### ❌ "Function fn_update_table_statuses_for_slots not found"

**Solution**: Function didn't apply correctly

```sql
SELECT fn_update_table_statuses_for_slots('BUSINESS_ID');
-- If error: Run FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql again
```

### ❌ Tables not marking as reserved

**Solution**: Check reservation data in view

```sql
SELECT id, table_number, status
FROM vw_tables_with_reservation
WHERE business_id = 'BUSINESS_ID'
AND (status = 'reserved' OR reservation_data IS NOT NULL)
ORDER BY table_number;
```

### ❌ Reservations not auto-expiring

**Solution**: Verify reservation fields

```sql
SELECT id, customer_name, reserved_for, check_in, status
FROM public.table_reservations
WHERE business_id = 'BUSINESS_ID'
AND status = 'active'
AND check_in IS NULL
ORDER BY reserved_for;

-- Then manually trigger expiry:
SELECT fn_update_table_statuses_for_slots('BUSINESS_ID');

-- Check if status changed:
SELECT id, status FROM public.table_reservations WHERE id = 'RESERVATION_ID';
```

---

## Rollback (If Issues)

```sql
-- Revert to previous expiry logic
DROP FUNCTION IF EXISTS public.fn_update_table_statuses_for_slots(TEXT) CASCADE;

-- Old expiry function only checks if reservation is past time window
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
  RETURN jsonb_build_object('expired_count', v_count, 'success', true);
END;
$$;

NOTIFY pgrst, 'reload schema';
-- Restart Flutter app
```

---

## Success Indicators ✅

After deployment, you should see:

1. **Tables in buffer window**: Show "Reserved" status
2. **Walk-in prevention**: Cannot seat guest at 'reserved' table
3. **Reservation notifications**: Staff sees incoming reservation warnings
4. **Auto-expiry notifications**: Staff notified when no-show reservation expires
5. **Table freed automatically**: Table becomes available after expiration
6. **No schema errors**: All queries work, no PGRST errors
7. **No UI crashes**: App handles inconsistent states gracefully

---

## Files Involved

| File                                                    | Purpose                      | Action        |
| ------------------------------------------------------- | ---------------------------- | ------------- |
| `FIX_RESERVATION_VISIBILITY_AND_EXPIRY_2026_03_26.sql`  | Main fix - Functions & views | **RUN THIS**  |
| `FIX_RESERVATION_DATA_VIEW_2026_03_26.sql`              | View with reservation data   | Run if needed |
| `FIX_RESERVATION_SESSION_MANAGEMENT_2026_03_26.sql`     | Session handling             | Already done  |
| `DEPLOYMENT_GUIDE_RESERVATION_VISIBILITY_2026_03_26.md` | Detailed guide               | Reference     |

---

## Questions?

See full guide: `DEPLOYMENT_GUIDE_RESERVATION_VISIBILITY_2026_03_26.md`

Run verification queries in "Troubleshooting" section above.
