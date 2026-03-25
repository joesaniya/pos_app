// SEAT MANAGEMENT SYSTEM - QUICK INTEGRATION CHECKLIST
// ══════════════════════════════════════════════════════════════════════════════

## 📋 QUICK INTEGRATION CHECKLIST

### Phase 1: File Setup (5 minutes)

- [ ] Copy lib/providers/seat_status_provider.dart to project
- [ ] Copy lib/widgets/seat_management_widgets.dart to project
- [ ] Copy lib/services/seat_management_service.dart to project
- [ ] Copy lib/utils/seat_utils.dart to project
- [ ] Verify no import errors in each file

### Phase 2: Provider Registration (2 minutes)

- [ ] Open lib/main.dart (or provider setup file)
- [ ] Find MultiProvider section
- [ ] Add: `ChangeNotifierProvider(create: (_) => SeatStatusProvider(),)`
- [ ] Save and verify app still builds

### Phase 3: TablesProvider Integration (5 minutes)

- [ ] Open lib/providers/tables_provider.dart
- [ ] Find the method that loads tables (likely loadTables() or fetchTables())
- [ ] After setting `_tables = tables;` add:
  ```dart
  // Update seat status provider
  try {
    final seatProvider = context.read<SeatStatusProvider>();
    for (final table in tables) {
      seatProvider.updateTableSeats(table);
    }
  } catch (e) {
    log('[TablesProvider] Error updating seat status: $e');
  }
  ```
- [ ] Save and verify no errors

### Phase 4: Table Detail UI Integration (10 minutes)

- [ ] Open lib/screens/tables_screen/sheet/table_detail_sheet.dart
- [ ] Import seat widgets at top:
  ```dart
  import 'package:pos_app/widgets/seat_management_widgets.dart';
  ```
- [ ] Find the table detail header area (where table number/status shown)
- [ ] After title section, add SeatAvailabilityHeader:
  ```dart
  SeatAvailabilityHeader(
    tableId: table.id,
    totalSeats: table.capacity,
  ),
  SizedBox(height: 12),
  ```
- [ ] Add seat grid below (adjust height as needed):
  ```dart
  SizedBox(
    height: 250,
    child: SeatGridWidget(
      tableId: table.id,
      onSeatSelected: (seat) {
        // Optional: handle seat selection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: ${seat.seatLabel}')),
        );
      },
    ),
  ),
  ```
- [ ] Save and test table detail screen

### Phase 5: Order Creation Integration (5 minutes)

- [ ] Open lib/repositories/orders_repository.dart
- [ ] Import seat service at top:
  ```dart
  import 'package:pos_app/services/seat_management_service.dart';
  ```
- [ ] Find the createOrder() method
- [ ] After order is successfully created, add:
  ```dart
  // Mark seat as ordered if seat-level order
  if (tableSeatId != null && tableId != null) {
    try {
      await SeatManagementService.instance.markSeatOrdered(
        tableId: tableId,
        seatId: tableSeatId,
      );
    } catch (e) {
      log('[OrdersRepo] Warning: Could not mark seat: $e');
    }
  }
  ```
- [ ] Save and verify no errors

### Phase 6: Clearing Operations Integration (5 minutes)

- [ ] Open lib/providers/clearing_provider.dart
- [ ] Import seat status provider at top:
  ```dart
  import 'package:pos_app/providers/seat_status_provider.dart';
  ```
- [ ] Find clearSeat() method
- [ ] After successful clear (result['success'] == true), add:
  ```dart
  // Update seat status provider
  try {
    context.read<SeatStatusProvider>().clearSeat(tableId, seatId);
  } catch (e) {
    log('[ClearingProvider] Error updating seat status: $e');
  }
  ```
- [ ] Also in clearEntireTable(), after success, add:
  ```dart
  // Clear all seats from provider
  try {
    context.read<SeatStatusProvider>().clearAllSeats(tableId);
  } catch (e) {
    log('[ClearingProvider] Error clearing seats: $e');
  }
  ```
- [ ] Save and verify

### Phase 7: Table Card Enhancement (Optional - 5 minutes)

- [ ] Open lib/screens/tables_screen/widgets/table_card_widgets.dart (or similar)
- [ ] Import:
  ```dart
  import 'package:pos_app/widgets/seat_management_widgets.dart';
  ```
- [ ] Find where table card displays status/info
- [ ] Add occupancy indicator:
  ```dart
  OccupancyIndicator(
    tableId: table.id,
    size: 50,
    showPercentage: true,
  ),
  ```
- [ ] This shows circular progress on table card

### Phase 8: Testing (20 minutes)

#### Test 1: Display

- [ ] Open app and navigate to tables
- [ ] Tap on a table to see detail sheet
- [ ] Verify SeatAvailabilityHeader shows: "Total: X | Occupied: 0 | Available: X"
- [ ] Verify seat grid displays all seats
- [ ] Verify all seats show "Available" (green checkmark)

#### Test 2: Seating Guest

- [ ] In table detail, manually seat a guest using existing UI
- [ ] Wait 2-3 seconds
- [ ] Verify SeatAvailabilityHeader updates to "Occupied: 1 | Available: X-1"
- [ ] Verify seat card shows duration ("1m", "2m", etc.)
- [ ] Wait another 30 seconds and verify duration incremented

#### Test 3: Creating Order

- [ ] Create an order for occupied seat
- [ ] Verify order appears in system
- [ ] (If integrated) Verify seat shows "Ordered" status

#### Test 4: Clearing Seat

- [ ] Use existing clear seat functionality
- [ ] Verify SeatAvailabilityHeader updates immediately
- [ ] Verify seat shows "Available" again
- [ ] Verify duration/customer name cleared

#### Test 5: Multiple Guests

- [ ] Seat guests at multiple seats
- [ ] Verify correct count displayed
- [ ] Verify each seat shows independent duration
- [ ] Create orders at different seats
- [ ] Clear different seats
- [ ] Verify UI reflects all changes correctly

### Phase 9: Deployment

#### Pre-Deployment Checklist

- [ ] All 4 new files copied and no import errors
- [ ] App builds successfully without errors
- [ ] No console warnings related to seat system
- [ ] Manual testing all 5 test scenarios passed
- [ ] Verified real-time duration updates work
- [ ] Verified seat clearing works
- [ ] Verified multi-guest scenarios work

#### Deploy to Staging

- [ ] Build APK/iOS build for staging
- [ ] Deploy to beta testers or QA
- [ ] Gather feedback for 2-3 days

#### Production Deployment

- [ ] Address any staging feedback
- [ ] Create release build
- [ ] Deploy to production
- [ ] Monitor logs for any errors
- [ ] Gather user feedback

## 🔍 VERIFICATION COMMANDS

After each phase, run these to verify:

```bash
# Check for import errors
grep -r "SeatStatusProvider\|SeatGridWidget\|SeatManagementService\|SeatUtils" lib/ | grep "import"

# Check file locations
ls -la lib/providers/seat_status_provider.dart
ls -la lib/widgets/seat_management_widgets.dart
ls -la lib/services/seat_management_service.dart
ls -la lib/utils/seat_utils.dart

# Build and verify
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```

## ⏱️ TIME ESTIMATES

- Phase 1 (File Setup): 5 minutes
- Phase 2 (Provider): 2 minutes
- Phase 3 (TablesProvider): 5 minutes
- Phase 4 (UI Integration): 10 minutes
- Phase 5 (Orders): 5 minutes
- Phase 6 (Clearing): 5 minutes
- Phase 7 (Optional): 5 minutes
- Phase 8 (Testing): 20 minutes

**Total: ~57 minutes to full integration**

## 🚨 TROUBLESHOOTING

### Build Fails - Import Not Found

**Problem**: `SeatStatusProvider not found`
**Solution**:

1. Verify file is at: `lib/providers/seat_status_provider.dart`
2. Run `flutter clean && flutter pub get`
3. Restart IDE

### App Crashes on Launch

**Problem**: `Provider not registered`
**Solution**:

1. Verify you added ChangeNotifierProvider in MultiProvider
2. Verify import is at top of main.dart
3. Run `flutter clean`

### Seat Grid Shows Blank

**Problem**: `No seats displayed`
**Solution**:

1. Verify updateTableSeats() is called from TablesProvider
2. Add logging: `print('Table seats: ${provider.getTableSeats(tableId)}')`
3. Verify table has seated guests (occupancy > 0)

### Duration Not Updating

**Problem**: `Seat duration stays at "0m"`
**Solution**:

1. Verify timer is started in \_startDurationTimer()
2. Check DateTime.now() is being called
3. Add logging in timer callback
4. Verify dispose() is called on app exit

### Orders Not Showing Correct Seat

**Problem**: `Orders not associated with seats`
**Solution**:

1. Verify tableSeatId is passed when creating order
2. Verify markSeatOrdered() is called in order creation
3. Check database shows table_seat_id in orders table

## 📞 QUICK REFERENCE

### Common Code Snippets

#### Get seat availability

```dart
final provider = context.read<SeatStatusProvider>();
final summary = provider.getTableSeats(tableId);
print('${summary?.occupiedSeats}/${summary?.totalSeats}');
```

#### Seat a guest

```dart
await SeatManagementService.instance.seatGuestAtSeat(
  tableId: tableId,
  seatId: seatId,
  customerName: customerName,
);
```

#### Clear a seat

```dart
await SeatManagementService.instance.clearSeat(
  tableId: tableId,
  seatId: seatId,
);
```

#### Display occupancy

```dart
OccupancyIndicator(tableId: tableId, size: 60)
```

## ✅ COMPLETION CHECKLIST

- [ ] All 4 files copied to project
- [ ] Provider registered in MultiProvider
- [ ] TablesProvider updated with updateTableSeats()
- [ ] Table detail UI shows SeatAvailabilityHeader and SeatGridWidget
- [ ] Orders mark seats as ordered
- [ ] Clearing updates seat status
- [ ] All 5 test scenarios verified
- [ ] No console errors
- [ ] Ready for deployment

**Status: Ready for Integration** ✅
