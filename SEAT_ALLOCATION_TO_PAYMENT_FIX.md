# Seat-Level Table Management - Complete Integration Guide
## From Allocation to Payment (2026-03-25)

---

## ✅ ISSUES FIXED

### 1. **Missing _AllocationDisplayBanner Widget** ✅ FIXED
- **Problem**: The new_order_screen.dart referenced `_AllocationDisplayBanner` widget on line 1082, but the widget class was not defined
- **Solution**: Created complete `_AllocationDisplayBanner` widget that displays:
  - ✅ Table number prominently
  - ✅ Seat details when a specific seat is selected
  - ✅ Visual indication of allocated status
  - ✅ Real-time updates when seats/tables are selected

### 2. **Seat Information in Order Creation** ✅ WORKING
- **Status**: OrdersProvider and OrdersRepository already correctly pass `tableSeatId` and `seatLabel`
- **Flow**: 
  ```
  new_order_screen.dart → OrdersProvider.createOrder() → OrdersRepository.createOrder()
  ↓
  Includes: tableId, tableNumber, tableSeatId, seatLabel
  ```

### 3. **Order Model Seat Support** ✅ COMPLETE
- Fields already present in Order model:
  - `tableId`: String? 
  - `tableNumber`: int?
  - `tableSeatId`: String?
  - `seatLabel`: String?
  - Helper methods: `tableDisplayName`, `seatDisplayLabel`, `tableAndSeatLabel`

---

## 📋 IMPLEMENTATION CHECKLIST

### Phase 1: Order Creation (COMPLETE)
- [x] Table selection on new_order_screen.dart
- [x] Seat selection with visual feedback
- [x] _AllocationDisplayBanner widget showing allocated table/seat
- [x] Order model captures table + seat info
- [x] OrdersProvider passes seat details to repository

### Phase 2: Order Display Throughout Flow
- [ ] **Bill Screen**: Display table number and seat(s)
  - Location: `lib/screens/billing_screen.dart` or order summary
  - Show: Table {number}, Seat(s): {seatLabel}

- [ ] **Payment Screen**: Display table and seat info
  - Location: `lib/screens/payment_screen.dart`
  - Show: Full table/seat allocation details

- [ ] **Order Summary**: Include seat allocation
  - Location: After order placed confirmation
  - Show: Order {id} for Table {number}, Seat(s): {seatLabel}

### Phase 3: Seat Clearing (CRITICAL)
- [ ] **Payment Completion Handler**:
  - When order is paid, call `seatRepository.clearSeat(seatId)`
  - ONLY clear the seat(s) linked to this order
  - Do NOT clear entire table
  - Update seat status to 'available' in real-time

- [ ] **Single Seat vs Whole Table Logic**:
  - If `order.tableSeatId != null`: Clear only that seat
  - If `order.tableSeatId == null`: Order for whole table (all seats remain available)

### Phase 4: Real-Time Updates
- [ ] Seat status provider updates when payment completes
- [ ] UI refreshes to show seat as available
- [ ] Other staff see updated seat status immediately

### Phase 5: Offline Support
- [ ] Offline sync queue includes:
  - Order creation with seat info
  - Seat clearing operations
  - Sync when online

---

## 🔧 TECHNICAL DETAILS

### _AllocationDisplayBanner Widget
**Location**: `lib/screens/new_order_screen.dart` (lines 1626-1805)

**Features**:
```dart
_AllocationDisplayBanner(
  tableId: selectedTableId,        // Required
  tables: tables,                  // RestaurantTable list
  seatId: selectedSeatId,          // Optional
)
```

**Displays**:
- Table number with status indicator
- Seat details if seat is selected
- Visual confirmation of allocation
- Updates when table/seat selection changes

### Order Flow: Table → Seat → Order
```
1. Staff taps table in cart view
   ↓ _CartView.onTableSelected() → setState(selectedTableId)
   ↓
2. _AllocationDisplayBanner appears showing "Table 1"
   ↓
3. Staff optionally selects seat (or whole table)
   ↓ onSeatSelected() → setState(selectedSeatId)
   ↓
4. _AllocationDisplayBanner updates to show "Table 1, Seat A"
   ↓
5. Staff adds items and clicks "Place Order"
   ↓ _placeOrder() calls OrdersProvider.createOrder()
   ↓
6. Order saved with:
   - tableId, tableNumber
   - tableSeatId, seatLabel
```

### Key Methods in Order Model
```dart
// Display helpers
order.tableDisplayName        // "Table 01"
order.seatDisplayLabel        // "A" or "Seat ID: abc123"
order.tableAndSeatLabel       // "Table 01 - Seat A"

// Check if seat-specific
bool hasSpecificSeat = order.tableSeatId != null;
```

---

## 🛠️ REQUIRED FIXES (TO DO)

### 1. Billing Screen Integration
**File**: `lib/screens/billing_screen.dart` (or order summary)

**Add to bill display**:
```dart
// Header section
Text('Table: ${order.tableDisplayName}'),
if (order.tableSeatId != null)
  Text('Seat(s): ${order.seatDisplayLabel}'),

// Or use helper
Text(order.tableAndSeatLabel),
```

### 2. Payment Screen Integration
**File**: `lib/screens/payment_screen.dart`

**Add seat info confirmation**:
```dart
// Before payment confirmation
if (order.tableSeatId != null) {
  showDialog(
    title: 'Seat Clearing',
    message: 'After payment, only Seat ${order.seatDisplayLabel} '
             'will be cleared.',
  );
}
```

### 3. Seat Clearing Handler
**File**: `lib/repositories/seat_repository.dart` or new method in orders_repository

**Add to payment completion**:
```dart
// After payment is SUCCESSFUL
if (order.tableSeatId != null) {
  await seatRepository.clearSeat(
    tableId: order.tableId!,
    seatId: order.tableSeatId!,
  );
}

// Update seat status to 'available'
// Notify SeatStatusProvider for real-time UI update
```

### 4. Offline Sync Integration
**File**: `lib/services/offline_sync_service.dart`

**Add seat operations to sync queue**:
```dart
// When connecting to internet, sync:
- Order creation with seat info
- Seat clearing operations
- Verify order-seat linkage
```

---

## 📊 DATABASE & REPOSITORIES

### Order Record (Already Correct)
```json
{
  "id": "ord_123",
  "table_id": "tbl_1",
  "table_number": 1,
  "table_seat_id": "st_abc123",    // Links to specific seat
  "seat_label": "A",                // Human-readable label
  ...
}
```

### Seat Operations Needed
```dart
// In SeatRepository:
Future<void> clearSeat(
  String tableId,
  String seatId,
) async {
  // 1. Update seat status to 'available'
  // 2. Clear guest info
  // 3. Update sit duration
  // 4. Post to seat_session_history
  // 5. Notify providers
}
```

---

## 🚀 TESTING CHECKLIST

### Scenario 1: Walk-in to Single Seat
- [ ] Create table with 4 seats (A, B, C, D)
- [ ] Select Table 1, then Seat A
- [ ] _AllocationDisplayBanner shows "Table 1" with "Selected Seat: A"
- [ ] Add items and place order
- [ ] Order created with seatId linked
- [ ] Complete payment
  - Only Seat A clears
  - Seats B, C, D remain unchanged (if occupied)

### Scenario 2: Whole Table Order
- [ ] Select Table 1, NO specific seat
- [ ] _AllocationDisplayBanner shows "Table 1" with "Order for Whole Table"
- [ ] Add items and place order
- [ ] Order created with seatId = NULL
- [ ] Complete payment
  - All seats remain in their current state

### Scenario 3: Real-Time Updates
- [ ] Staff A seats guest at Table 1, Seat A
- [ ] Staff B opens new order screen
- [ ] Seat A shows as 'occupied' immediately
- [ ] Payment completed by Staff A
- [ ] Staff B sees Seat A as 'available' in real-time

### Scenario 4: Offline Operations
- [ ] Go offline
- [ ] Create order with seat selection
- [ ] Assign seat to guest
- [ ] Complete payment
- [ ] Go back online
- [ ] All operations sync correctly

---

## 🔗 RELATED FILES

### Core Order Flow
- `lib/screens/new_order_screen.dart` - Order creation (✅ FIXED - banner added)
- `lib/models/order_modal.dart` - Order model (✅ Complete)
- `lib/providers/orders_provider.dart` - Order provider (✅ Correct)
- `lib/repositories/orders_repository.dart` - Order creation

### Seat Management
- `lib/repositories/seat_repository.dart` - Seat operations
- `lib/providers/seat_status_provider.dart` - Seat status
- `lib/widgets/seat_management_widgets.dart` - Seat UI

### Billing & Payment
- `lib/screens/billing_screen.dart` - Bill display (⚠️ Needs seat info)
- `lib/screens/payment_screen.dart` - Payment UI (⚠️ Needs seat info)

### Offline Support
- `lib/services/offline_sync_service.dart` - Sync operations
- `lib/services/storage_service.dart` - Local persistence

---

## 📋 NOTES

### Important Behavior Rules
1. **Only specific seats clear after payment** - Order with seatId links only that seat
2. **Whole table orders don't clear anything** - seatId is NULL, table remains as-is
3. **No table blocking** - Allocated seats don't prevent other operations
4. **Real-time visibility** - All staff see same seat status immediately
5. **Offline-first ensures no data loss** - Operations queue and sync

### Design Decisions
- **seatId field is OPTIONAL** - Allows both "whole table" and "seat-level" orders
- **Seat status independent from table status** - Each seat has its own lifecycle
- **Historical tracking includes seat transitions** - See guest journey per seat
- **Payment and clearing are separate** - Payment completion triggers clearing

---

## 🎯 SUCCESS CRITERIA

✅ **Order Creation**: When Table 1, Seat A is selected, allocation banner shows it
✅ **Order Persistence**: Table and seat IDs saved with order
✅ **Bill Display**: Bill shows "Table 1, Seat A"  
✅ **Payment Confirmation**: Payment summary includes seat info
✅ **Seat Clearing**: After payment, only Seat A becomes available
✅ **Real-Time Update**: UI refreshes immediately (no page reload needed)
✅ **Offline Support**: All operations queue and sync correctly
✅ **No False Clears**: Other seats on table 1 NOT affected by Seat A payment

---

## 📞 INTEGRATION SUMMARY

### What's Done ✅
1. Created `_AllocationDisplayBanner` widget
2. Confirmed Order model has all fields
3. Verified OrdersProvider passes seat info
4. Confirmed new_order_screen displays allocation

### What's Needed ⚠️
1. Update billing screen to show table/seat
2. Update payment screen to show seat clearing impact
3. Implement seat clearing after payment success
4. Add seat clearing to offline sync queue
5. Add real-time seat status updates to UI

### Expected Time to Complete: ~4 hours
- Billing screen: 30 min
- Payment screen: 30 min
- Seat clearing handler: 1 hour
- Offline sync: 1 hour
- Testing & refinement: 1 hour

---

## 🔄 WORKFLOW EXAMPLE

```
SCENARIO: Walk-in customer at Table 1, Seat A

1. NEW ORDER SCREEN
   ├─ Staff selects Table 1
   ├─ _AllocationDisplayBanner shows: "ALLOCATED - Table 1"
   ├─ Staff selects Seat A
   ├─ _AllocationDisplayBanner updates: "ALLOCATED - Table 1 | Selected Seat: A"
   └─ Staff adds items and clicks "Place Order"

2. ORDER SUMMARY (after creation)
   ├─ Shows: Order#1047 for Table 1, Seat A
   ├─ Items: 2x Biryani, 1x Iced Tea
   └─ Total: ₹450

3. BILL SCREEN (when ready)
   ├─ Header: Table 1 | Seat A
   ├─ Items with prices
   └─ Total: ₹450 (with 5% tax)

4. PAYMENT SCREEN
   ├─ Shows: Table 1, Seat A
   ├─ Amount: ₹472.50
   ├─ Note: "Seat A will be cleared after payment"
   ├─ Payment method selection
   └─ Click "Complete Payment"

5. PAYMENT SUCCESS
   ├─ Order marked as PAID
   ├─ Seat A status changed to 'available'
   ├─ SeatStatusProvider notified
   └─ UI refreshes - Seat A shows available to all staff

RESULT:
✅ Table 1 status: Partially occupied (only A cleared)
✅ Seats B, C, D: Remain in their state (occupied or available)
✅ Real-time: All devices show Seat A as available
```

---

Generated: 2026-03-25
Status: READY FOR IMPLEMENTATION
