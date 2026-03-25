// SEAT-BASED TABLE MANAGEMENT SYSTEM - Integration Guide
// ══════════════════════════════════════════════════════════════════════════════
//
// This guide explains how to integrate the new seat-based table management
// system into your POS app for real-time seat tracking, occupancy display,
// and partial-table ordering support.
//
// ══════════════════════════════════════════════════════════════════════════════

## ✅ COMPLETE SYSTEM FEATURES

### 1. Real-Time Seat Availability Display

- ✅ Total seats, occupied seats, available seats counts
- ✅ Live occupancy percentage (0-100%)
- ✅ Dynamic color-coded status indicators
- ✅ Instant updates as seats are occupied/cleared

### 2. Dynamic Duration Tracking

- ✅ Automatic timer for each occupied seat
- ✅ Real-time updates every second
- ✅ Display format: "2h 35m", "45m", or "30s"
- ✅ Multiple formats for different UI contexts

### 3. Comprehensive Seat Status Tracking

- Available: No guest, ready to accept
- Occupied: Guest present, no orders yet
- Ordered: Guest has active orders
- Completed: Guest finished (temporary state)

### 4. Partial and Full-Table Ordering

- ✅ Support orders when table is partially occupied
- ✅ Automatically handle full-table ordering when all seats occupied
- ✅ Seat-level order association
- ✅ Mixed ordering at same table (some seats ordered, some not)

### 5. Seamless Seat Reuse

- ✅ Individual seat clearing without affecting others
- ✅ Immediate availability after clearing
- ✅ Automatic table status management
- ✅ Session isolation per guest

## 📁 FILES CREATED/MODIFIED

### NEW FILES

1. `lib/providers/seat_status_provider.dart` (140 lines)
   - Real-time seat status tracking
   - Duration calculation and updates
   - Occupancy summaries

2. `lib/widgets/seat_management_widgets.dart` (320 lines)
   - SeatAvailabilityHeader - Shows total/occupied/available
   - SeatGridWidget - Grid display of all seats
   - SeatListWidget - List display of seats
   - OccupancyIndicator - Circular progress indicator
   - Multiple helper components

3. `lib/services/seat_management_service.dart` (230 lines)
   - Seat operations (seat, clear, sync)
   - Backend RPC integration
   - Real-time subscriptions
   - Occupancy queries

### MODIFIED FILES (Future Integration)

Will need updates to:

- `lib/providers/tables_provider.dart` - Add SeatStatusProvider integration
- `lib/screens/tables_screen/sheet/table_detail_sheet.dart` - Add seat widgets to UI
- `lib/repositories/orders_repository.dart` - Mark seats as 'ordered' when creating orders
- `lib/providers/clearing_provider.dart` - Integrate with seat status updates

## 🚀 STEP-BY-STEP INTEGRATION

### Step 1: Register Providers in MultiProvider

```dart
// In your main.dart or app_provider_setup.dart
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(
      create: (_) => SeatStatusProvider(),
    ),
    // ... other providers
  ],
  // ...
)
```

### Step 2: Initialize SeatStatusProvider in TablesProvider

```dart
// In tables_provider.dart, after fetching tables:
Future<void> loadTables() async {
  // ... existing code

  final tables = await _repository.fetchTables(...);

  // Update seat status for each table
  if (mounted) {
    for (final table in tables) {
      context.read<SeatStatusProvider>().updateTableSeats(table);
    }
  }

  // ... rest of code
}
```

### Step 3: Add Seat Availability Display to Table Detail Sheet

```dart
// In table_detail_sheet.dart, at the top of the sheet:
SizedBox(
  width: MediaQuery.of(context).size.width,
  child: SeatAvailabilityHeader(
    tableId: table.id,
    totalSeats: table.capacity,
  ),
),
SizedBox(height: 16),

// Then add seat grid or list:
SizedBox(
  height: 300,
  child: SeatGridWidget(
    tableId: table.id,
    onSeatSelected: (seatInfo) {
      // Handle seat selection
      print('Seat selected: ${seatInfo.seatLabel}');
    },
  ),
),
```

### Step 4: Update Order Creation to Mark Seats

```dart
// In orders_repository.dart, in createOrder():
Future<Order> createOrder({
  // ... existing parameters
  String? tableSeatId,
  // ...
}) async {
  // ... create order

  // Mark seat as 'ordered' if seat-level order
  if (tableSeatId != null && tableId != null) {
    await SeatManagementService.instance.markSeatOrdered(
      tableId: tableId,
      seatId: tableSeatId,
    );

    // Update seat status in provider
    context.read<SeatStatusProvider>().markSeatOrdered(
      tableId,
      tableSeatId,
    );
  }

  // ... return order
}
```

### Step 5: Update Clearing to Clear Seat Status

```dart
// In clearing_provider.dart, after successful seat clear:
if (result['success'] == true) {
  // Clear from seat status provider
  context.read<SeatStatusProvider>().clearSeat(
    tableId,
    seatId,
  );

  // ... existing code
}
```

### Step 6: Display Occupancy Indicator on Table Card

```dart
// In table card widget (table_card_widgets.dart):
OccupancyIndicator(
  tableId: table.id,
  size: 50,
  showPercentage: true,
),
```

## 🗄️ DATABASE REQUIREMENTS

The system requires these backend tables/functions:

### table_seats

```sql
CREATE TABLE IF NOT EXISTS table_seats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_id UUID REFERENCES restaurant_tables(id) ON DELETE CASCADE,
  seat_label TEXT,
  status TEXT DEFAULT 'available'
    CHECK (status IN ('available','occupied','ordered','completed')),
  session_id UUID,
  customer_name TEXT,
  occupied_since TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Required RPC Functions

- `fn_seat_guest(p_table_id, p_customer_name)` - Seat a guest
- `fn_clear_seat(p_table_id, p_seat_id)` - Clear individual seat
- `fn_clear_table_complete(p_table_id)` - Clear entire table

(All included in your SQL schema)

## 💡 USAGE EXAMPLES

### Display Seat Availability

```dart
SeatAvailabilityHeader(
  tableId: tableId,
  totalSeats: table.capacity,
)
```

### Display All Seats in Grid

```dart
SeatGridWidget(
  tableId: tableId,
  onSeatSelected: (seatInfo) {
    print('Seat: ${seatInfo.seatLabel}');
    print('Status: ${seatInfo.status}');
    print('Duration: ${seatInfo.durationDisplay}');
  },
)
```

### Display Seats in List

```dart
SeatListWidget(
  tableId: tableId,
  onSeatSelected: (seatInfo) {
    // Handle seat selection
  },
)
```

### Show Occupancy Indicator

```dart
OccupancyIndicator(
  tableId: tableId,
  size: 60,
  showPercentage: true,
)
```

### Programmatically Get Seat Info

```dart
final seatProvider = context.read<SeatStatusProvider>();
final summary = seatProvider.getTableSeats(tableId);

print('Total: ${summary?.totalSeats}');
print('Occupied: ${summary?.occupiedSeats}');
print('Available: ${summary?.availableSeats}');
```

### Seat a Guest

```dart
final service = SeatManagementService.instance;
final result = await service.seatGuestAtSeat(
  tableId: tableId,
  seatId: seatId,
  customerName: 'John Doe',
);

if (result['success']) {
  // Update UI
  context.read<SeatStatusProvider>().markSeatOccupied(
    tableId,
    seatId,
    'John Doe',
  );
}
```

### Clear a Seat

```dart
final result = await SeatManagementService.instance.clearSeat(
  tableId: tableId,
  seatId: seatId,
);

if (result['success']) {
  context.read<SeatStatusProvider>().clearSeat(tableId, seatId);
}
```

### Clear Entire Table

```dart
final result = await SeatManagementService.instance.clearEntireTable(
  tableId: tableId,
);

if (result['success']) {
  context.read<SeatStatusProvider>().clearAllSeats(tableId);
}
```

## 🎯 KEY BEHAVIORS

### Partial Occupancy

When a 4-seat table has only 2 guests:

- ✅ Show "2/4 seats occupied" (50%)
- ✅ Display 2 occupied seats, 2 available seats
- ✅ Allow orders for occupied seats only
- ✅ Allow seating more guests at available seats
- ✅ Clear each guest independently

### Full Occupancy

When all seats are occupied:

- ✅ Show "4/4 seats occupied" (100%)
- ✅ Display all seats as occupied
- ✅ Handle as single table order or individual seat orders
- ✅ Prevent new guest seating until seat clears
- ✅ Can clear individual seats or entire table

### Duration Display

Real-time updates for each occupied seat:

- "0m" to "59s" → "45m"
- "1m" to "59m" → "35m"
- "1h" and above → "2h 35m"

### Session Isolation

Each guest gets unique session_id:

- ✅ Orders filtered by session_id
- ✅ Old guest's orders don't show after clearing
- ✅ Supports multiple guests at same table
- ✅ Automatic cleanup on seat clear

## ⚠️ IMPORTANT NOTES

1. **Always sync table data** before displaying seat widgets

   ```dart
   await provider.syncTables();
   ```

2. **Dispose of timers properly** - SeatStatusProvider handles this automatically

   ```dart
   // No manual timer management needed
   ```

3. **Provider must be above TablesProvider in tree**
   for context.read() to work

4. **Real-time updates require backend subscriptions**
   - Use SeatManagementService.subscribeToSeatUpdates()
   - Unsubscribe in dispose()

5. **Local database should be kept in sync**
   - After each seat operation, update local DB
   - Use for offline fallback

## 🔍 TESTING CHECKLIST

- [ ] SeatStatusProvider initializes correctly
- [ ] SeatAvailabilityHeader shows correct counts
- [ ] SeatGridWidget displays all seats
- [ ] Duration timer updates every second
- [ ] Seat colors update based on status
- [ ] Occupancy indicator calculates percentage correctly
- [ ] Clearing seat removes it from occupied list
- [ ] Multiple guests can be seated at same table
- [ ] Orders associated with correct seat
- [ ] Session isolation prevents cross-table order bleed
- [ ] Offline functionality works with local DB
- [ ] Real-time updates work when online

## 🚨 TROUBLESHOOTING

### Duration not updating

- Check SeatStatusProvider is in MultiProvider
- Verify timer is started in \_startDurationTimer()
- Ensure DateTime calculations use UTC

### Seat status not reflecting changes

- Call updateTableSeats() after any seat operation
- Verify provider disposed properly
- Check for multiple provider instances

### Orders showing for wrong seat

- Ensure table_seat_id is set when creating order
- Verify session_id isolation in order queries
- Check clearTableOrdersLocally() is called

### Widget showing blank/shimmer

- Verify SeatStatusProvider.getTableSeats() returns non-null
- Check table has seats configured
- Ensure table is in provider's \_tableSeatMap

## 📞 SUPPORT

For issues or questions:

1. Check the examples above
2. Review SQL functions in COMPLETE_STABLE_SCHEMA_FINAL.sql
3. Verify all files are in correct directories
4. Check provider registration in main.dart
5. Review console logs for error messages

## ✨ NEXT STEPS

1. Integrate the 3 new files into your project
2. Register SeatStatusProvider in MultiProvider
3. Update tables_provider.dart to call updateTableSeats()
4. Add seat widgets to table_detail_sheet.dart
5. Update order creation to mark seats
6. Test with multi-guest scenarios
7. Deploy to staging first
8. Monitor logs for any issues
9. Gather user feedback on UI/UX
10. Iterate based on real usage patterns
