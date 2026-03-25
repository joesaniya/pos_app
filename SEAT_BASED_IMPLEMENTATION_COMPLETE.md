# 🎯 SEAT-BASED TABLE MANAGEMENT - COMPLETE IMPLEMENTATION GUIDE

## Overview

This guide provides complete implementation for a production-ready seat-based table management system with full online and offline support.

---

## 📋 Database Layer (PostgreSQL)

### Key Changes

**File**: `SEAT_BASED_WORKFLOW_COMPLETE_FIX.sql`

Running this file will:

1. **Auto-Seat Generation** - Trigger `trg_generate_seats` automatically creates seats when tables are added

   ```
   Table Capacity = 4 → Auto-creates seats: A, B, C, D
   ```

2. **New Table**: `seat_session_history` - Tracks guest visits
   - Tracks check-in, check-out, duration, customer name
   - Maintains history for analytics

3. **Enhanced Functions**:
   - `fn_seat_guest_v2()` - Seat guests at specific seats
   - `fn_clear_seat()` - Clear individual seats independently
   - `fn_get_seat_bill()` - Total bill for a seat
   - `fn_get_seat_duration()` - Time guest has been seated
   - `fn_get_seat_orders()` - All orders for a seat

4. **New View**: `vw_seat_occupancy_summary` - Real-time seat status

### Prerequisites

- Supabase project with PostgreSQL
- Tables: `restaurant_tables`, `table_seats`, `orders`, `order_items`
- Columns in `orders`: `table_id` (TEXT), `table_seat_id` (UUID), `session_id` (UUID)

### Execution

```sql
-- 1. Apply schema changes
psql -h [HOST] -U [USER] -d [DB] -f SEAT_BASED_WORKFLOW_COMPLETE_FIX.sql

-- 2. Verify functions exist
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE 'fn_%seat%';
```

---

## 📱 Flutter/Dart Layer Implementation

### 1. Create Seat Repository

**File**: `lib/repositories/seat_repository.dart`

```dart
// Initialize in your app
final seatRepo = SeatRepository.instance;

// Key methods:
- seatGuest()              // Seat guest at specific seats
- getSeatBill()            // Get total bill for a seat
- getSeatDuration()        // Get time seated
- clearSeat()              // Clear individual seat
- getSeatSessionHistory()  // Get guest visit history
```

### 2. Update Orders Repository

**File**: `lib/repositories/orders_repository_seat_integration.dart`

Add these methods to existing `orders_repository.dart`:

```dart
- createSeatOrder()        // Create order for specific seat
- getSeatOrders()          // Get all orders for seat
- completeSeatOrders()     // Mark seat orders as paid/complete
- getSeatSummary()         // Complete bill + duration + items
- syncPendingSeatOrders()  // Offline sync support
```

### 3. Update Tables Repository

In `lib/repositories/tables_repository.dart`, update `seatGuests()`:

```dart
Future<SeatResult> seatGuests(
  String tableId,
  String customerName, {
  required String businessId,
  bool isWalkIn = false,
  List<String>? seatIds,  // NEW: specific seats
  String? staffUid,
  String? staffName,
}) async {
  // Use SeatRepository.instance.seatGuest()
  // This will handle both online and offline
}
```

### 4. Update Models

In `lib/models/table_modal.dart`, RestaurantTable already has:

- `seats: List<TableSeat>` ✅
- `sessionId: String?` ✅

TableSeat already has:

- `occupiedSince: DateTime?` ✅
- `sessionId: UUID` ✅
- `occupiedDuration` ✅

---

## 🔄 Workflow Implementation

### Scenario 1: Walk-In Guest (Seat-Based)

```dart
// 1. Load table and auto-created seats
final table = await tablesRepo.fetchTables('business_id');
// table.seats = [A, B, C, D] (all available initially)

// 2. User selects available seat B for walk-in guest
final seatIds = ['seat-uuid-B'];
final result = await seatRepo.seatGuest(
  tableId: 'table-1',
  customerName: 'John Doe',
  businessId: 'business_id',
  seatIds: seatIds,  // Specific seat
  staffName: 'Alice',
);
// Returns: session_id

// 3. Create order for this specific seat
final order = await ordersRepo.createSeatOrder(
  tableId: 'table-1',
  seatId: 'seat-uuid-B',
  businessId: 'business_id',
  createdByUid: 'staff-uid',
  createdByName: 'Alice',
  items: {
    'items': [
      {'item_name': 'Biryani', 'quantity': 2, 'item_price': 250},
    ]
  },
);

// 4. Display seat status
final bill = await seatRepo.getSeatBill('seat-uuid-B');
// bill.total_bill = 500
// bill.active_orders = 1

final duration = await seatRepo.getSeatDuration('seat-uuid-B');
// duration.duration_display = "15m"
// duration.customer_name = "John Doe"

// 5. When guest pays (clear seat B only)
final cleared = await seatRepo.clearSeat(
  tableId: 'table-1',
  seatId: 'seat-uuid-B',
  businessId: 'business_id',
);
// Seat B → Available
// Other seats (A, C, D) → unaffected
```

### Scenario 2: Full Table Seating (Fill All Seats)

```dart
// 1. Seat all available seats with same customer name
final result = await seatRepo.seatGuest(
  tableId: 'table-1',
  customerName: 'Family Party',
  businessId: 'business_id',
  seatIds: null,  // NULL = all available seats
);

// 2. All seats A, B, C, D → occupied

// 3. Create orders can be done seat-by-seat or combined
// ...orders can be per seat for accuracy

// 4. When PARTIAL payment (clear only seat A):
await seatRepo.clearSeat(
  tableId: 'table-1',
  seatId: 'seat-uuid-A',
);
// Seat A → Available
// Seats B, C, D → still occupied

// 5. Or clear entire table at once
await chartsRepo.clearTable('table-1', 'business_id');
// All seats → available
// Table → available
```

### Scenario 3: Offline Operation

```dart
// ALL seat operations work offline automatically

// 1. Offline: Seat guest
final result = await seatRepo.seatGuest(
  tableId: 'table-1',
  customerName: 'John',
  seatIds: ['seat-uuid-B'],
  // ... works with local database
);

// 2. Offline: Create order for seat
final order = await ordersRepo.createSeatOrder(
  tableId: 'table-1',
  seatId: 'seat-uuid-B',
  // ... queued locally
);

// 3. User pays at seat
await seatRepo.clearSeat(...);
// Completed locally

// 4. Come back online → Automatic sync
// All pending operations sync to Supabase
// Using OfflineSyncService
```

---

## 🎨 UI Implementation

### Display Seat Status

```dart
// Show all seats with individual status
SeatAvailabilityHeader(
  tableId: 'table-1',
  totalSeats: 4,
);
// Shows: Total=4 | Occupied=2 | Available=2 | 50%

SeatGridWidget(
  tableId: 'table-1',
  onSeatSelected: (SeatStatusInfo seat) {
    // User selected seat
    showSeatDetailsSheet(seat);
  },
);
// Each card shows:
// - Seat label (A, B, C, D)
// - Status (Available/Occupied)
// - Customer name (if occupied)
// - Duration (e.g., "15m")
// - Tap to see bill
```

### Seat Details Sheet

```dart
class SeatDetailsSheet extends StatelessWidget {
  final SeatStatusInfo seat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: Seat label, customer name
        Text('Seat ${seat.seatLabel} • ${seat.customerName}'),

        // Duration
        Text('Seated for: ${seat.durationDisplay}'),

        // Bill breakdown
        SeatBillDisplay(
          totalBill: bill['total_bill'],
          activeOrders: bill['active_orders'],
          completedOrders: bill['completed_orders'],
        ),

        // Action buttons
        if (seat.isOccupied) ...[
          ElevatedButton(
            onPressed: () async {
              await ordersRepo.createSeatOrder(...);
              // Add more items
            },
            child: Text('Add Items'),
          ),
          ElevatedButton(
            onPressed: () async {
              await seatRepo.clearSeat(...);
              // Mark as paid and clear
            },
            child: Text('Payment Complete'),
          ),
        ],
      ],
    );
  }
}
```

---

## 🔌 Offline Sync Strategy

### Key Components

**File**: `lib/services/offline_sync_service.dart`

Extends existing sync to handle:

```dart
// 1. Queue seat operations
- Seating guest
- Creating seat orders
- Clearing seats

// 2. Local storage of:
- Seat status changes
- Seat orders (with table_seat_id)
- Session history

// 3. On coming online:
- Sync all pending seat transactions
- Verify seat states match server
- Handle conflicts
```

### Implementation

```dart
class OfflineSyncService {
  // Add to existing sync:

  Future<void> syncSeatOperations() async {
    // 1. Get pending seat operations from queue
    final pending = await _local.getPendingQueue(
      entityType: 'seat', // NEW
    );

    // 2. Sync in order (seating → orders → clearing)
    for (final op in pending) {
      try {
        final result = await _syncOperation(op);
        // Mark as synced
        await _local.markSynced(op.id);
      } catch (e) {
        // Handle conflict
        if (e.toString().contains('seat already occupied')) {
          // Refresh from server
          await tablesRepo.refreshFromRemote();
        }
      }
    }
  }
}
```

---

## ✅ Testing Checklist

### Unit Tests

```dart
// test/repositories/seat_repository_test.dart

test('Auto-generates seats on table creation', () {
  // Create table with capacity 4
  // Verify 4 seats created with labels A, B, C, D
});

test('Seats guest at specific seat', () {
  // Seat guest at seat B
  // Verify: seat B occupied, others available
});

test('Independent seat clearing', () {
  // Seat guests at B, C, D
  // Clear seat B
  // Verify: B available, C & D still occupied
  // Verify: Table still occupied
});

test('Offline seat operations sync', () {
  // Offline: Seat guest, create order, clear seat
  // Come online
  // Verify: All synced to Supabase
});
```

### Integration Tests

```dart
// test/workflows/seat_based_workflow_test.dart

test('Complete walk-in guest workflow', () {
  // 1. Load table with auto-generated seats
  // 2. Seat guest at seat B
  // 3. Create order for seat B
  // 4. Get bill for seat B
  // 5. View bill has correct total
  // 6. Clear seat B
  // 7. Verify O other seats unaffected
  // 8. Verify session history created
});

test('Multiple guests same table', () {
  // Seat 2 guests at different seats
  // Each creates independent orders
  // Each pays separately
  // Each cleared independently
});
```

### Manual Testing

```
SCENARIO 1: Single Seat Payment
1. Create table (4 capacity) → Seats auto-created ✓
2. Seat guest at seat B → Seat B: occupied ✓
3. Create 2 orders for seat B
4. View seat details → shows both orders ✓
5. Pay → Clear seat B ✓
6. Verify table still occupied (other seats?)
7. Other guests still seated ✓

SCENARIO 2: Offline Operation
1. Go offline
2. Seat guest at seat C
3. Create order for seat C
4. Pay and clear seat C
5. Come back online
6. Verify all synced ✓
7. Check seat_session_history for duration ✓

SCENARIO 3: Partial Table Clear
1. Seat all 4 seats
2. Create different orders for each
3. Clear seat A only
4. Verify: A available, B,C,D occupied ✓
5. Clear seats B, C in sequence
6. Verify: D still occupied ✓
7. Clear D → Table becomes available ✓
```

---

## 📊 Dashboard Metrics

Display using `vw_seat_occupancy_summary`:

```dart
// Real-time table metrics
Widget buildTableStatus(String tableId) {
  final summary = seatRepo.getTableOccupancySummary(tableId);

  return Column(
    children: [
      Text('Table ${summary.tableNumber}'),
      Text('${summary.occupiedSeats}/${summary.totalSeats} occupied'),
      GridView(
        children: summary.occupiedSeatDetails.map((seat) {
          return SeatCard(
            label: seat['seat_label'],
            customer: seat['customer_name'],
            duration: seat['duration_minutes'],
            bill: calculateBill(seat['seat_id']),
          );
        }).toList(),
      ),
    ],
  );
}
```

---

## 🚨 Common Issues & Fixes

### Issue 1: Seat IDs Mismatch (UUID vs String)

**Problem**: Function expects UUID array, app sends strings
**Solution**:

```dart
// Convert seat IDs to UUIDs before sending
final seatUuids = seatIds.map((id) {
  try {
    return Uuid.parse(id);
  } catch (e) {
    return id; // Already UUID
  }
}).toList();
```

### Issue 2: Orders Not Associated with Seats

**Problem**: Orders created without `table_seat_id`
**Solution**:

```dart
// Always include @table_seat_id when creating order
await ordersRepo.createSeatOrder(
  seatId: seatId,  // REQUIRED
  // ...
);
```

### Issue 3: Offline Sync Lost Seat Changes

**Problem**: Local seat state not saved before sync
**Solution**:

```dart
// Ensure local cache updated before online operations
await _local.updateSeat(...);
if (online) {
  await syncToServer(); // Only after local updated
}
```

---

## 📚 File Summary

| File                                                       | Purpose                              |
| ---------------------------------------------------------- | ------------------------------------ |
| `SEAT_BASED_WORKFLOW_COMPLETE_FIX.sql`                     | Database schema, triggers, functions |
| `lib/repositories/seat_repository.dart`                    | Seat CRUD + online/offline           |
| `lib/repositories/orders_repository_seat_integration.dart` | Seat-level orders                    |
| `lib/models/table_modal.dart`                              | Already includes seat models ✅      |
| `lib/models/seat_history_model.dart`                       | Session tracking ✅                  |
| `lib/providers/seat_status_provider.dart`                  | Real-time UI updates ✅              |
| `lib/services/offline_sync_service.dart`                   | Sync coordinator (update existing)   |

---

## 🎓 Architecture Diagram

```
[UI Layer]
├─ SeatGridWidget (display seats)
├─ SeatDetailsSheet (interact with seat)
└─ SeatBillDisplay (show bill)
       ↓
[Provider Layer]
├─ SeatStatusProvider (real-time updates)
└─ ClearingProvider (seat clearing state)
       ↓
[Repository Layer]
├─ SeatRepository (seat operations)
├─ OrdersRepository (seat-level orders)
└─ TablesRepository (table management)
       ↓
[Service Layer]
├─ ConnectivityService (online/offline)
└─ OfflineSyncService (sync queue)
       ↓
[Database Layer]
├─ Local DB (SQLite)
│  ├─ table_seats (cached)
│  ├─ orders (with table_seat_id)
│  └─ sync_queue (pending operations)
│
└─ Supabase (PostgreSQL)
   ├─ restaurant_tables
   ├─ table_seats
   ├─ orders
   ├─ seat_session_history (tracking)
   └─ (Functions + Views)
```

---

## 🔑 Key Features Checklist

- [x] Auto-seat generation on table creation
- [x] Walk-in guest assignment to specific seats
- [x] Seat-level order tracking
- [x] Seat duration display
- [x] Bill calculation per seat
- [x] Independent seat clearing
- [x] Session history tracking
- [x] Online/offline support
- [x] Real-time synchronization
- [x] Partial table clearing
- [x] UI components for seat display
- [x] Conflict handling

---

## 🚀 Deployment Steps

```bash
# 1. Apply database changes
psql -h $SUPABASE_HOST -f SEAT_BASED_WORKFLOW_COMPLETE_FIX.sql

# 2. Update Flutter code
cp seat_repository.dart lib/repositories/
# Merge orders_repository_seat_integration.dart into orders_repository.dart
# Update services/offline_sync_service.dart

# 3. Test thoroughly
flutter test test/repositories/seat_repository_test.dart
flutter test test/workflows/seat_based_workflow_test.dart

# 4. Deploy
flutter pub get
flutter run --release
```

---

## 📞 Support

For issues:

1. Check database logs in Supabase
2. Enable debug logging in Flutter
3. Verify seat models match database schema
4. Test offline scenarios thoroughly
5. Check sync queue for stuck operations
