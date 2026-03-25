# Technical Architecture: Reservation Session Lifecycle

## Session Lifecycle State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                    TABLE RESERVATION LIFECYCLE                    │
└─────────────────────────────────────────────────────────────────┘

[CREATE RESERVATION]
         ↓
    STATUS: 'active'
    table status: 'reserved' (if within 15 min window)
    check_in: NULL
    actual_check_out: NULL
         ↓
[WAIT FOR GUEST ARRIVAL]
    (Duration: reserved_for time varies)
    (State: Waiting/Upcoming)
         ↓
[GUEST ARRIVES & IS SEATED]
    → fn_seat_guest_v2() called
    → UPDATE reservation: status='seated', check_in=NOW()
    → UPDATE table: status='occupied', occupied_since=NOW()
    → Generate: fresh session_id (UUID)
    → Clear: any previous session's orders
         ↓
    STATUS: 'seated'
    table status: 'occupied'
    occupied_since: 2:43 PM (exact seating time)
    session_id: abc123-xyz...
    duration_timer: [RUNNING] 0m → 1m → 2m...
         ↓
[GUEST DINING]
    (Duration: variable, customer decides)
    (Orders: placed, prepared, served)
    (Bill: accumulates)
         ↓
[GUEST FINISHES & CHECKS OUT]
    → fn_checkout_v2() or fn_clear_seat() called
    → UPDATE reservation: status='completed', actual_check_out=NOW()
    → UPDATE table: status='available', occupied_since=NULL
    → UPDATE seats: status='available', occupied_since=NULL
    → Complete: all active orders
    → Clear: all session data
         ↓
    STATUS: 'completed'
    table status: 'available'
    occupied_since: NULL ← CRITICAL: Timer stopped
    session_id: NULL ← CRITICAL: Session ended
    orders: all 'completed'
    duration_timer: [STOPPED]
         ↓
[NEXT CUSTOMER ARRIVES]
    → fn_seat_guest_v2() called with NEW customer name
    → UPDATE table: occupied_since=NOW() ← FRESH START
    → Generate: brand new session_id ← NEW SESSION
         ↓
    STATUS: 'occupied' (or 'seated' if new reservation)
    table status: 'occupied'
    occupied_since: 2:50 PM (new seating time) ← NO CARRYOVER
    session_id: def456-uvw... ← COMPLETELY DIFFERENT
    duration_timer: [RUNNING] 0m → 1m → 2m... ← FRESH COUNT


CRITICAL GUARANTEES:
✅ occupied_since ALWAYS set to NOW() at seating (never carried forward)
✅ session_id is ALWAYS a fresh UUID for each customer
✅ Previous orders are ALWAYS marked completed before new seating
✅ Customer can see duration ONLY for their own session
✅ Bill shows ONLY current session amounts
```

---

## Data Model

### Reservation Record

```
table_reservations:
  id: UUID (unique)
  table_id: TEXT (foreign key)
  customer_name: TEXT
  phone: TEXT (optional)
  guest_count: INT
  reserved_for: TIMESTAMPTZ (booking time)
  check_in: TIMESTAMPTZ (when guest actually arrived - NULL until seated)
  actual_check_out: TIMESTAMPTZ (when guest left - NULL until checkout)
  status: TEXT ('active', 'seated', 'completed', 'no_show', 'cancelled')
  created_at: TIMESTAMPTZ
  created_by_name: TEXT

STATE TRANSITIONS:
  active → seated (when fn_seat_guest_v2 called)
  active → no_show (auto-expire if time passes without check_in)
  active → cancelled (staff cancels reservation)
  seated → completed (when fn_checkout_v2 called)
```

### Table Record

```
restaurant_tables:
  id: TEXT (primary key)
  business_id: TEXT
  table_number: INT
  section: TEXT
  status: TEXT ('available', 'reserved', 'occupied', 'cleaning')
  session_id: UUID (current session - NULL if not occupied)
  current_customer_name: TEXT (current guest - NULL if available)
  occupied_since: TIMESTAMPTZ (seating time for duration calculation)
  current_order_id: UUID (for quick access)
  current_order_total: NUMERIC (cached bill total)

CRITICAL FIELDS FOR SESSION ISOLATION:
  occupied_since: SET=NOW() on seating, NULL on clear (duration timer)
  session_id: FRESH UUID on seating, NULL on clear (session scope)
  current_customer_name: NEW NAME on seating, NULL on clear (guest identity)
```

### Seat Record (For Multi-Seat Tables)

```
table_seats:
  id: UUID (unique seat identifier)
  table_id: TEXT (foreign key)
  seat_label: TEXT ('A', 'B', 'C', etc.)
  status: TEXT ('available', 'occupied')
  session_id: UUID (seat's current session)
  customer_name: TEXT (who's sitting here)
  occupied_since: TIMESTAMPTZ (when this seat was taken)

SAME CRITICAL LOGIC:
  occupied_since: FRESH per seating, NULL per clearing
  session_id: UNIQUE per customer, NULL per clearing
```

### Order Record

```
orders:
  id: UUID
  table_id: TEXT (which table)
  table_seat_id: UUID (which seat within table, if multi-seat)
  session_id: UUID (which session the order belongs to)
  status: TEXT ('pending', 'preparing', 'ready', 'completed')
  subtotal: NUMERIC
  tax_amount: NUMERIC
  total_amount: NUMERIC

ON CHECKOUT:
  All orders with status IN ('pending','preparing','ready')
  → Change to status='completed'
  → Orders filtered by: WHERE session_id = current_session_id
  → New session CANNOT see old orders (different session_id)
```

---

## Critical Session Isolation Mechanism

### How Duration Timer Reset Works

```
Customer A Timeline:
─────────────────────────────────────────────────
2:43 PM: fn_seat_guest_v2() called
  occupied_since = 2:43:00 PM ← REFERENCE POINT
  session_id = abc123xyz

2:44 PM: UI shows "1 minute"
  Calculation: NOW() - occupied_since = 1 minute

2:55 PM: UI shows "12 minutes"
  Calculation: NOW() - occupied_since = 12 minutes

3:15 PM: fn_checkout_v2() called
  occupied_since = NULL ← TIMER REFERENCE REMOVED
  session_id = NULL ← SESSION ENDED
  ORDER RECORDS: marked completed

Customer B Timeline:
─────────────────────────────────────────────────
3:20 PM: fn_seat_guest_v2() called
  occupied_since = 3:20:00 PM ← NEW REFERENCE POINT
  session_id = def456uvw ← DIFFERENT UUID

3:21 PM: UI shows "1 minute"
  Calculation: NOW() - occupied_since = 1 minute
  NOT: NOW() - 2:43 PM = 38 minutes ← THIS NEVER HAPPENS

Key insight: occupied_since is timestamp reference,
not "how long table has been used today"
```

### How Order Isolation Works

```
Database Structure:
┌─────────────────────────────────────────┐
│ orders table                            │
├─────────────────────────────────────────┤
│ id    │ session_id │ status │ total    │
├─────────────────────────────────────────┤
│ 001   │ abc123xyz  │ comp   │ 450      │ ← Customer A's burger
│ 002   │ abc123xyz  │ comp   │ 200      │ ← Customer A's coffee
│ 003   │ def456uvw  │ pend   │ 350      │ ← Customer B's salad
└─────────────────────────────────────────┘

When showing current bill:
  WHERE table_id='T12'
    AND session_id=(current active session) ← KEY FILTER
    AND status != 'completed'

Result: Only order 003, ignore 001-002 from previous session

When clearing table:
  UPDATE orders WHERE table_id='T12' AND status IN (...)
  → Completes orders 003
  → Orders 001-002 already completed, untouched
  → New session gets completely clean order list
```

---

## RPC Function Signatures

### fn_seat_guest_v2

```sql
fn_seat_guest_v2(
  p_customer_name TEXT,
  p_seat_ids UUID[],
  p_staff_name TEXT,
  p_staff_uid TEXT,
  p_table_id TEXT
) → JSONB
  {
    success: true,
    session_id: "fresh-uuid",
    reservation_id: "res-id-or-null"
  }

DOES:
  1. Generate fresh session_id
  2. SET ALL occupied_since = NOW() (fresh start)
  3. UPDATE reservation: status='seated', check_in=NOW()
  4. Complete previous session's orders
```

### fn_checkout_v2

```sql
fn_checkout_v2(
  p_table_id TEXT
) → JSONB
  {
    success: true
  }

DOES:
  1. Complete all active orders
  2. NULL occupied_since (stop duration timer)
  3. NULL session_id (end session)
  4. NULL current_customer_name (clear identity)
  5. SET table.status='available'
  6. UPDATE reservation: status='completed', actual_check_out=NOW()
```

### fn_clear_seat

```sql
fn_clear_seat(
  p_table_id TEXT,
  p_seat_id UUID
) → JSONB
  {
    success: true,
    remaining_occupied_seats: 1,
    table_fully_cleared: false
  }

DOES:
  1. NULL occupied_since for this seat only
  2. Set seat.status='available'
  3. Complete orders for this seat only
  4. IF no more occupied seats: reset whole table
```

### fn_clear_table_complete

```sql
fn_clear_table_complete(
  p_table_id TEXT
) → JSONB
  {
    success: true,
    orders_completed: 3,
    seats_cleared: 3
  }

DOES:
  1. Complete ALL table orders
  2. Clear ALL seats (status, session_id, occupied_since)
  3. Reset table (status, session_id, occupied_since)
  4. Mark reservation 'completed'
```

---

## Offline-First Behavior

The Flutter app queues all RPC calls when offline:

```
OFFLINE FLOW:
┌─────────────────────────────────────────┐
│ User seats guest (no internet)          │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Local Update:                           │
│ - occupied_since = NOW()  ← FRESH      │
│ - session_id = new UUID   ← FRESH      │
│ - Store in SQLite cache                │
│ - Queue for sync: [fn_seat_guest_v2]  │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Internet reconnects                     │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Sync RPC calls:                         │
│ 1. fn_seat_guest_v2() → DB updated     │
│ 2. Refresh from remote                 │
│ 3. Merge any conflicts                 │
│ 4. Queue cleared                       │
└─────────────────────────────────────────┘

GUARANTEE: Offline logic uses exact same
TimestampZ values as online, so no inconsistency
```

---

## Implementation Checklist

- [x] Database functions created/updated
- [x] Reservation lifecycle properly defined
- [x] Session reset on checkout
- [x] Duration timer reset implementation
- [x] Order isolation by session
- [x] Clearing repository using correct functions
- [x] Provider refresh after changes
- [x] Offline sync support (already in place)
- [x] UI properly displays status transitions
- [x] Filters "Overdue" from upcoming displays

---

## Testing Verification Matrix

| Test Case           | Input              | Expected Output                              | Status |
| ------------------- | ------------------ | -------------------------------------------- | ------ |
| Seat reserved guest | Active reservation | status='seated', check_in=NOW()              | ✓      |
| Checkout guest      | Occupied table     | status='available', occupied_since=NULL      | ✓      |
| Duration reset      | New customer       | occupied_since=NOW(), duration~0m            | ✓      |
| Order isolation     | Multiple sessions  | Only current orders shown                    | ✓      |
| Multi-seat clear    | One of 3 occupied  | Only that seat cleared, table still occupied | ✓      |
| Offline seating     | No internet        | Same behavior, queued for sync               | ✓      |

---
