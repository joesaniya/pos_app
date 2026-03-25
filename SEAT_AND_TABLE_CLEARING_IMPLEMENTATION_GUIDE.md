## ✅ SEAT & TABLE CLEARING IMPLEMENTATION GUIDE

## Complete Production-Ready Solution

This guide explains how to integrate flexible seat and table clearing into your POS app with real-time synchronization between local database and Supabase backend.

---

## 📋 ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter UI Layer                        │
│  (ClearSeatButton, ClearTableButton, ClearingStatusIndicator)│
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  ClearingProvider                           │
│  (State Management, Real-time Stream Listening)             │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                ClearingRepository                           │
│  (Backend RPC calls + Local DB updates)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴───────────────────┬────────────────┐
│                                            │                │
▼                                            ▼                ▼
Supabase RPC Functions              Local SQLite DB      Real-time Subscriptions
(fn_clear_seat)                     (restaurant_tables,  (PostgREST triggers)
(fn_clear_table_complete)            table_seats, orders)
```

---

## 🔧 STEP 1: Deploy SQL Functions to Supabase

### 1.1 Execute the SQL Migration

1. Go to **Supabase Dashboard** → Your Project → **SQL Editor**
2. Create a new query and paste the entire content from:
   - `SEAT_AND_TABLE_CLEAR_FUNCTIONS.sql`
3. Click **Run** to execute
4. Wait for successful execution (should see no errors)

### 1.2 Verify Functions Created

In SQL Editor, run:

```sql
SELECT proname FROM pg_proc
WHERE proname IN ('fn_clear_seat', 'fn_clear_table_complete', 'fn_get_seat_details', 'fn_get_table_seat_summaries');
```

You should see 4 rows returned. If not, check for errors in the SQL execution.

---

## 🎯 STEP 2: Add Files to Your Flutter Project

### 2.1 Create New Repository

Copy the following file to your project:

```
lib/repositories/clearing_repository.dart
```

### 2.2 Create New Provider

Copy the following file to your project:

```
lib/providers/clearing_provider.dart
```

### 2.3 Create New UI Widgets

Copy the following file to your project:

```
lib/widgets/clearing_ui_widgets.dart
```

---

## 📱 STEP 3: Register Provider in Main App

### 3.1 Update Your Main.dart or App Configuration

Find where you initialize your providers (usually in `main.dart` or a providers setup file):

```dart
import 'package:pos_app/providers/clearing_provider.dart';

// Add to your MultiProvider or ChangeNotifierProvider setup:
ChangeNotifierProvider(
  create: (_) => ClearingProvider(),
),
```

### 3.2 Example Full Setup

If you're using `MultiProvider`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => TablesProvider()),
    ChangeNotifierProvider(create: (_) => OrdersProvider()),
    ChangeNotifierProvider(create: (_) => ClearingProvider()), // ← Add this
    // ... other providers
  ],
  child: MaterialApp(
    home: YourApp(),
  ),
);
```

---

## 🎨 STEP 4: Use Widgets in Your UI

### 4.1 Clear Individual Seat (Option A: Button)

In your table/seat UI:

```dart
import 'package:pos_app/widgets/clearing_ui_widgets.dart';

// In your seat widget:
ClearSeatButton(
  tableId: table.id,
  seatId: seat.id,
  seatLabel: seat.label,  // e.g., "Seat A"
  businessId: businessId,
  onClearingStarted: () {
    // Optional: Show loading UI
    print('Clearing started');
  },
  onClearingCompleted: () {
    // Optional: Refresh table view
    refreshTableData();
  },
  onClearingFailed: (error) {
    // Optional: Handle error
    print('Error: $error');
  },
)
```

### 4.2 Clear Entire Table (Option B: Button)

```dart
ClearTableButton(
  tableId: table.id,
  tableNumber: table.tableNumber.toString(),
  businessId: businessId,
  onClearingCompleted: () {
    // Refresh or navigate
    Navigator.pop(context);
  },
)
```

### 4.3 Seat Selection Menu (Option C: Full Menu)

```dart
// Push a new screen with seat options
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SeatClearingMenu(
      tableId: table.id,
      seats: table.seats,  // List of seat data
      businessId: businessId,
      onSeatCleared: () {
        // Refresh updates
        Provider.of<TablesProvider>(context, listen: false).refreshTables();
      },
    ),
  ),
);
```

### 4.4 Real-time Status Display

Add this anywhere in your app to show clearing operation status:

```dart
Padding(
  padding: EdgeInsets.all(16),
  child: ClearingStatusIndicator(
    displayDuration: Duration(seconds: 5),  // Auto-hide after 5 seconds
  ),
)
```

---

## 🔄 STEP 5: Integrate with Existing Table Provider

### 5.1 Connect ClearingProvider to TablesProvider

In your table screen, after clearing:

```dart
final clearingProvider = context.read<ClearingProvider>();

// Listen to clearing events
clearingProvider.clearingStream.listen((event) {
  // Refresh table data when a seat is cleared
  // This ensures your UI always shows latest data
  final tablesProvider = context.read<TablesProvider>();
  tablesProvider.refreshTables();
});
```

### 5.2 Option: Manual Refresh in Tab View

```dart
// In your tables view
ClearSeatButton(
  tableId: table.id,
  seatId: seat.id,
  seatLabel: seat.label,
  businessId: businessId,
  onClearingCompleted: () {
    // Force refresh the table
    Provider.of<TablesProvider>(context, listen: false)
        .refreshTables(selectedBusinessId);

    // Also refresh orders
    Provider.of<OrdersProvider>(context, listen: false)
        .fetchTableOrders(table.id);
  },
)
```

---

## 📊 REAL-TIME SYNC BEHAVIOR

### What Happens When You Clear a Seat:

1. **User clicks "Clear Seat"** → Shows confirmation dialog with:
   - Customer name
   - Number of active orders
   - Total bill
   - Seat status

2. **User confirms** → Backend (Supabase):
   - Marks seat as `status = 'available'`
   - Marks all orders for that seat as `status = 'completed'`
   - Checks if any other seats are occupied
   - If all seats are free → Marks table as `status = 'available'`

3. **Simultaneously, Local Database**:
   - Updates seat status to `available`
   - Updates orders to `completed`
   - Updates table status if needed

4. **Real-time Updates**:
   - Stream event fires → `ClearingStatusIndicator` shows success message
   - Providers notifyListeners() → UI refreshes automatically
   - All subscribed widgets rebuild with new data

5. **User sees**:
   - Seat disappears from "occupied" list
   - Seat shows as "available" (green/neutral color)
   - Bill is settled
   - Table ready for new guests (if all seats cleared)

---

## 🛡️ KEY FEATURES IMPLEMENTED

### ✅ Seat-Level Clearing

- Clear only one seat without affecting other seats in the table
- Orders associated with that seat are automatically marked complete
- Real-time UI update shows seat as available
- Customer name and session are cleared

### ✅ Table-Level Clearing

- Clear entire table at once
- All seats marked as available
- All orders marked as completed
- Session information cleared
- Table ready for new guests

### ✅ Real-Time Synchronization

- Changes reflected instantly in UI
- Backend and local DB are kept in sync
- No data inconsistencies or delays
- Stream-based updates trigger automatic refreshes

### ✅ Data Validation

- Seat must exist
- Orders are fetched before clearing (shown in dialog)
- Total bill is displayed for confirmation
- Error messages are user-friendly

### ✅ Offline Support (Ready)

- Local database operations happen immediately
- When online, changes sync to Supabase
- When offline, changes queue for later sync
- No data loss

---

## 🐛 TROUBLESHOOTING

### Problem: "Function not found" error

**Solution**:

- Verify all SQL functions were deployed to Supabase
- Run the verification query in Step 1.2
- Check Supabase project logs for deployment errors

### Problem: Seat not clearing in UI

**Solution**:

- Check local database is updating (add logging)
- Verify ClearingProvider is registered in MultiProvider
- Force refresh table data after clearing
- Check for stream subscription issues

### Problem: Real-time updates not appearing

**Solution**:

- Verify `ClearingStatusIndicator` is added to UI
- Check ClearingProvider is not disposed prematurely
- Confirm stream subscription is active
- Check browser console for JS errors (if web)

### Problem: Orders not marked as completed

**Solution**:

- Verify order_items are properly linked to seats
- Check `table_seat_id` is populated in orders table
- Run this query to verify:
  ```sql
  SELECT * FROM orders WHERE table_seat_id = 'your-seat-id' LIMIT 5;
  ```

### Problem: Manual testing in development

**Solution**:
Enable debug logging:

```dart
// In clearing_provider.dart, if-block shows detailed logs
// Check Flutter console (verbose logging)
// Example manual flow:
// 1. Create order for seat
// 2. Click "Clear Seat" button
// 3. Confirm in dialog
// 4. Check console for: "✅ Seat cleared successfully"
// 5. Verify seat status changed to "available" in local DB
// 6. Verify orders status changed to "completed"
```

---

## 📝 EXAMPLE COMPLETE INTEGRATION

Here's a complete example of integrating seat clearing into a table view:

```dart
// your_table_screen.dart
import 'package:provider/provider.dart';
import 'package:pos_app/providers/clearing_provider.dart';
import 'package:pos_app/widgets/clearing_ui_widgets.dart';

class TableDetailScreen extends StatefulWidget {
  final String tableId;
  const TableDetailScreen({required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Table Details')),
      body: Column(
        children: [
          // Status indicator for real-time updates
          ClearingStatusIndicator(),

          // Seat list with clear buttons
          Expanded(
            child: ListView.builder(
              itemCount: table.seats.length,
              itemBuilder: (context, index) {
                final seat = table.seats[index];
                return Card(
                  child: ListTile(
                    title: Text('${seat.label} - ${seat.customerName}'),
                    subtitle: Text('${seat.status} • ${seat.occupiedOrders} orders'),
                    trailing: seat.status == 'occupied'
                        ? ClearSeatButton(
                            tableId: table.id,
                            seatId: seat.id,
                            seatLabel: seat.label,
                            businessId: widget.businessId,
                            onClearingCompleted: () {
                              // Refresh table data
                              setState(() {});
                            },
                          )
                        : Icon(Icons.check_circle, color: Colors.green),
                  ),
                );
              },
            ),
          ),

          // Table-level clear button
          Padding(
            padding: EdgeInsets.all(16),
            child: ClearTableButton(
              tableId: table.id,
              tableNumber: table.tableNumber.toString(),
              businessId: widget.businessId,
              onClearingCompleted: () {
                // Navigate back
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] SQL functions deployed to Supabase
- [ ] clearing_repository.dart added to lib/repositories/
- [ ] clearing_provider.dart added to lib/providers/
- [ ] clearing_ui_widgets.dart added to lib/widgets/
- [ ] ClearingProvider registered in MultiProvider
- [ ] UI widgets added to relevant screens
- [ ] Manual testing performed:
  - [ ] Seat level clearing works
  - [ ] Table level clearing works
  - [ ] Real-time UI updates appear
  - [ ] Local DB is updated
  - [ ] Supabase backend shows changes
- [ ] Error handling tested
- [ ] Offline mode tested (optional)

---

## 🚀 PRODUCTION DEPLOYMENT

1. **Test in Staging**: Deploy all changes to a staging environment first
2. **Backup Database**: Create a backup of production database before deployment
3. **Verify SQL Functions**: Run verification query in production Supabase
4. **Monitor Logs**: Watch for errors in Flutter logs and Supabase monitoring
5. **Gradual Rollout**: Roll out to users gradually (10% → 50% → 100%)
6. **Support Ready**: Have support team ready for any issues

---

## 📚 ADDITIONAL RESOURCES

### Files Reference

- SQL: `SEAT_AND_TABLE_CLEAR_FUNCTIONS.sql` - Backend functions
- Repository: `lib/repositories/clearing_repository.dart` - Backend calls
- Provider: `lib/providers/clearing_provider.dart` - State management
- Widgets: `lib/widgets/clearing_ui_widgets.dart` - UI components

### Key Functions

- `fn_clear_seat(tableId, seatId)` - Clear single seat
- `fn_clear_table_complete(tableId)` - Clear entire table
- `fn_get_seat_details(seatId)` - Get seat info for preview
- `fn_get_table_seat_summaries(tableId)` - Get all seats summary

### Key Classes

- `ClearingRepository` - Handles RPC & local DB operations
- `ClearingProvider` - Manages state & real-time updates
- `ClearSeatButton` - UI button for seat clearing
- `ClearTableButton` - UI button for table clearing
- `SeatClearingMenu` - Full menu for selecting seats to clear

---

## 💡 TIPS & BEST PRACTICES

1. **Always fetch seat details before showing confirmation** - Shows user exactly what will be cleared
2. **Use real-time status indicator** - Shows users clearing is in progress
3. **Refresh table data after clearing** - Ensures UI shows latest state
4. **Handle errors gracefully** - Show snackbars or dialogs for failures
5. **Test offline mode** - Ensure changes queue properly when offline
6. **Add logging in production** - Help debug any issues in production
7. **Monitor database consistency** - Periodically check no orphaned records exist

---

**✨ You now have a complete, production-ready seat and table clearing system with real-time synchronization!**
