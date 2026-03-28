# Table-First Order Creation Workflow
## Complete User Journey & Technical Implementation Guide

**Implementation Date**: March 28, 2026
**Version**: 1.0
**Status**: ✅ Production Ready

---

## 📋 Workflow Overview

The POS system now enforces a strict **table-first** approach to order creation, ensuring users cannot access the menu until a table (and appropriate seat) is selected and confirmed.

### User Journey Flow

```
┌─────────────────────┐
│  START NEW ORDER    │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ STEP 1: TABLE SELECTION (Mandatory Entry Point)         │
│                                                          │
│ ❌ Menu NOT shown during table selection                │
│ ✅ User must select a table                             │
│ ✅ All tables with status displayed                     │
│ ✅ Tables show occupancy information                    │
│                                                          │
│ Table Status Indicators:                               │
│ • ✅ Green   = Available (0/4 occupied)                │
│ • 🍽️  Blue   = Occupied (Full Table)                    │
│ • ⚡ Amber  = Partial (2/4 occupied)                   │
│ • 📅 Red    = Reserved                                 │
│ • 🧹 Orange = Cleaning (Cannot Select)                │
└──────────┬───────────────────────────────────────────────┘
           │
           │ [Table Selected & Confirmed]
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ STEP 2: SEAT CONFIRMATION (Auto-Selection)              │
│                                                          │
│ System analyzes table occupancy and auto-selects:       │
│                                                          │
│ IF Fully Occupied (100%):                              │
│   • Auto-select entire table                           │
│   • Message: "Table fully occupied. New order for      │
│     entire table."                                     │
│   • User: Reviews & Confirms                          │
│                                                          │
│ IF Partially Occupied:                                  │
│   • Auto-select first occupied seat                    │
│   • Message: "Table partially occupied. Auto-selected  │
│     first occupied seat."                              │
│   • User: Can modify selection or confirm              │
│                                                          │
│ IF Available:                                           │
│   • No auto-selection                                  │
│   • Message: "Table available. Choose seats or entire  │
│     table."                                            │
│   • User: Selects seats or confirms whole table        │
│                                                          │
│ ✅ Seat confirmation required to proceed               │
│ ✅ Option to change table selection provided           │
└──────────┬───────────────────────────────────────────────┘
           │
           │ [Seats Confirmed]
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ STEP 3: MENU SELECTION (Browse & Build Order)           │
│                                                          │
│ ✅ Menu now accessible with confirmed table/seat       │
│ ✅ Header shows: "Step 3: Browse Menu"                 │
│ ✅ Chip shows: "Table T5 • Seat 2"                     │
│ ✅ User adds items to cart                             │
│ ✅ Cart shows item quantities and totals               │
│                                                          │
│ Actions:                                                │
│ • Add/Remove items                                     │
│ • Change quantities                                    │
│ • View cart total                                      │
│ • Proceed to Delivery Timing (when cart not empty)    │
└──────────┬───────────────────────────────────────────────┘
           │
           │ [Items Added to Cart]
           │ [User Clicks "Proceed to Delivery Timing"]
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ STEP 4: DELIVERY/ORDER TIMING SELECTION                 │
│                                                          │
│ ✅ Header shows: "Step 4: Order Timing"                │
│ ✅ User selects timing preference                       │
│                                                          │
│ Options (Expandable):                                   │
│ • ⚡ PREPARE NOW (immediate)                           │
│ • 🕐 [Future: Schedule for later]                      │
│                                                          │
│ ✅ Timing selection required to proceed                │
│ ✅ Button disabled until timing selected              │
└──────────┬───────────────────────────────────────────────┘
           │
           │ [Timing Selected]
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ STEP 5: ORDER PREVIEW (Review & Confirm)               │
│                                                          │
│ ✅ Header shows: "Step 5: Review Order"                │
│ ✅ Complete order summary displayed:                    │
│    • Table: T5                                         │
│    • Seat: Seat 2                                      │
│    • Items: [All items with quantities]               │
│    • Subtotal: ₹XXX                                   │
│    • Tax: ₹XX                                         │
│    • Total: ₹XXXX                                     │
│                                                          │
│ ✅ Customer details (Optional):                         │
│    • Name                                              │
│    • Phone number                                      │
│                                                          │
│ ✅ Special notes field available                        │
│                                                          │
│ Actions:                                                │
│ • Back: Return to delivery timing                      │
│ • Place Order: Submit to kitchen                       │
└──────────┬───────────────────────────────────────────────┘
           │
           │ [Order Placed]
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ ✅ ORDER CONFIRMATION                                    │
│                                                          │
│ • Order number generated                               │
│ • Sent to kitchen                                      │
│ • Inventory deducted                                   │
│ • Receipt printed/displayed                            │
│ • Return to main screen                                │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 Back Navigation (How Users Can Go Back)

Users can navigate backwards through the workflow with all state preserved:

```
Step 1 (Table Selection)
    ↕ [Go Back]
    
Step 2 (Seat Confirmation)
    ↕ [Go Back - Clears Seat Selection]
    
Step 3 (Menu Selection)
    ↕ [Go Back - Keeps Cart Items]
    
Step 4 (Delivery Timing)
    ↕ [Go Back - Keeps Timing Selection]
    
Step 5 (Order Preview)
    ↕ [Go Back - Returns to Timing]
    
[Place Order]
```

**Exception**: Pressing back on Step 1 exits the order creation screen.

---

## 🎯 Table Status Logic & Auto-Selection

### Table Status Detection

The system reads occupancy data from `table_seats` array:

```dart
final occupiedSeats = seats.where((s) => s['status'] == 'occupied').toList();
final totalSeats = seats.length;

if (occupiedSeats.length == totalSeats) {
  // FULLY OCCUPIED
  displayStatus = "Fully Occupied"
  autoSelectSeats = null // Entire table
}
else if (occupiedSeats.length > 0) {
  // PARTIALLY OCCUPIED
  displayStatus = "Partial ($occupied/$total occupied)"
  autoSelectSeats = firstOccupiedSeat.id
}
else {
  // AVAILABLE
  displayStatus = "Available"
  autoSelectSeats = none
}
```

### Auto-Selection Rules

| Table State | Seats Status | Auto-Selected | User Can Modify |
|-------------|-------------|---|---|
| Fully Occupied (4/4) | All occupied | Entire table (null) | ✓ Can select individual seats |
| Partially Occupied (2/4) | Some occupied | First occupied seat | ✓ Can select different seat |
| Available (0/4) | All available | None | ✓ Must select (whole table or seat) |
| No Seats Defined | N/A | Entire table (null) | N/A |

---

## 💾 Data Flow

### State Variables Involved

```dart
// Current workflow step
OrderWorkflowStep _currentStep = OrderWorkflowStep.tableSelection;

// Table & Seat Selection
String? _selectedTableId;              // UUID of selected table
int? _selectedTableNumber;             // Table number (T1, T2, etc.)
String? _selectedSeatId;               // UUID of selected seat (null = whole table)
bool _tableAutoSelectedSeats = false;   // Flag: were seats auto-selected?

// Delivery Timing
String? _selectedDeliveryTiming = 'now'; // 'now' or future timestamp

// Cart & Order
Map<String, CartItem> _cart = {};     // Items in order
OrderType _orderType = OrderType.dineIn

// Customer Details
TextEditingController _customerCtrl;   // Customer name
TextEditingController _phoneCtrl;      // Phone number
TextEditingController _noteCtrl;       // Special notes
```

### Data Persistence

- **Cart Items**: Preserved across all workflow steps
- **Table/Seat Selection**: Preserved until user explicitly changes
- **Delivery Timing**: Preserved from selection until order placed
- **Customer Details**: Preserved across workflow

---

## 🎨 UI Components & Step Headers

### Step 1: Table Selection
```
┌─────────────────────────────────┐
│ 📍 Step 1: Select Table         │
│             [Mandatory] [Red]   │
└─────────────────────────────────┘

[Table Grid: T1, T2, T3, T4, ...]
[Confirm & Select Seats Button]
```

### Step 2: Seat Confirmation
```
┌─────────────────────────────────┐
│ 🧑 Step 2: Confirm Seat         │
│            [Table T5]           │
└─────────────────────────────────┘

[Status Message Box]
[Selected Seats Display]
[Change Table Option]
[Confirm & Browse Menu Button]
```

### Step 3: Menu Selection
```
┌─────────────────────────────────┐
│ 🍽️ Step 3: Browse Menu          │
│ [Table T5 • Seat 2] Badge       │
└─────────────────────────────────┘

[Categories | Search]
[Menu Items List]
[Cart View or Menu Items]
```

### Step 4: Delivery Timing
```
┌─────────────────────────────────┐
│ ⏰ Step 4: Order Timing         │
│            [Select] [Green]    │
└─────────────────────────────────┘

[  ⚡ PREPARE NOW  ]
[   Immediate preparation   ]

[Review Order Button]
```

### Step 5: Order Preview
```
┌─────────────────────────────────┐
│ ✅ Step 5: Review Order        │
└─────────────────────────────────┘

[Table & Seat Info]
[Items Summary]
[Subtotal / Tax / Total]
[Customer Details]
[Special Notes]
[Place Order Button]
```

---

## 🔧 Technical Implementation Details

### Workflow Enum (6 Steps)

```dart
enum OrderWorkflowStep {
  tableSelection,   // Step 1: Select table
  seatConfirmation, // Step 2: Confirm seats (auto-selected)
  menuSelection,    // Step 3: Browse & add items
  deliveryTiming,   // Step 4: Select timing
  orderPreview,     // Step 5: Review & place
  orderPlacement,   // Step 6: Processing
}
```

### Key Methods

```dart
// Workflow Navigation
_proceedToSeatConfirmation()    // Table → Seat
_proceedToMenuSelection()       // Seat → Menu
_proceedToDeliveryTiming()      // Menu → Timing
_proceedToOrderPreview()        // Timing → Preview

// Auto-Selection
_autoSelectSeatsForTable()      // Analyzes occupancy & selects

// Building UI
_buildTableSelectionStep()      // Table selection UI
_buildSeatConfirmationStep()    // Seat confirmation UI
_buildMenuSelectionStep()       // Menu browsing UI
_buildDeliveryTimingStep()      // Timing selection UI
_buildOrderPreviewStep()        // Review & order UI

// Back Navigation
_stepBack()                     // Handles back button logic
```

### Step Content Builder

```dart
Widget _buildStepContent() {
  switch (_currentStep) {
    case OrderWorkflowStep.tableSelection:
      return _buildTableSelectionStep();
    case OrderWorkflowStep.seatConfirmation:
      return _buildSeatConfirmationStep();
    case OrderWorkflowStep.menuSelection:
      return _buildMenuSelectionStep();
    case OrderWorkflowStep.deliveryTiming:
      return _buildDeliveryTimingStep();
    case OrderWorkflowStep.orderPreview:
      return _buildOrderPreviewStep();
    case OrderWorkflowStep.orderPlacement:
      return CircularProgressIndicator();
  }
}
```

---

## 📱 Screen Transitions

### Normal Flow Path

```
NewOrderScreen initialized
  └─ _currentStep = tableSelection
    └─ User selects table
      └─ _proceedToSeatConfirmation()
        └─ _currentStep = seatConfirmation
          └─ Seats auto-selected based on occupancy
            └─ User confirms
              └─ _proceedToMenuSelection()
                └─ _currentStep = menuSelection
                  └─ User adds items
                    └─ _proceedToDeliveryTiming()
                      └─ _currentStep = deliveryTiming
                        └─ User selects timing
                          └─ _proceedToOrderPreview()
                            └─ _currentStep = orderPreview
                              └─ User places order
                                └─ _placeOrder()
                                  └─ Order sent to kitchen
                                    └─ Navigator.pop()
```

### Back Navigation Path

```
orderPreview [Back]
  ↓
  _stepBack()
  ↓
  _currentStep = deliveryTiming
  ↓
  setState() triggers rebuild
  ↓
  _buildDeliveryTimingStep() displayed

(Can repeat from any step)
```

---

## 🧪 Testing Scenarios

### Scenario 1: Fully Occupied Table
1. Open new order
2. Select table with 4/4 seats occupied
3. Proceed to seat confirmation
4. Verify: Entire table auto-selected
5. Verify message: "Table is fully occupied..."
6. Confirm and proceed to menu
7. Verify table/seat info in header

### Scenario 2: Partially Occupied Table  
1. Open new order
2. Select table with 2/4 seats occupied
3. Proceed to seat confirmation
4. Verify: First occupied seat auto-selected
5. Verify message: "Table is partially occupied..."
6. Option to change seat
7. Confirm and proceed to menu

### Scenario 3: Available Table
1. Open new order
2. Select empty table (0/4 seats)
3. Proceed to seat confirmation
4. Verify: No auto-selection
5. Verify message: "Table is available..."
6. User can select specific seat or whole table
7. Complete workflow

### Scenario 4: Back Navigation
1. Go through full workflow to delivery timing
2. Click back button
3. Verify: Returns to menu  selection
4. Items should still be in cart
5. Continue workflow

### Scenario 5: Table Change
1. At seat confirmation, click "Change table selection"
2. Verify: Returns to table selection
3. Select different table
4. Verify: New table seats auto-selected
5. Continue workflow

---

## 🎯 Key Benefits

1. **User Safety**: Prevents accidental menu access without table context
2. **Smart Defaults**: Auto-selects appropriate seats based on occupancy
3. **Clear Journey**: Numbered steps guide user through process
4. **Flexible**: Users can modify auto-selections at confirmation step
5. **Information Timing**: Combines delivery timing with order details early
6. **State Preservation**: Cart and preferences maintained through navigation

---

## 📝 Notes

- **Offline Support**: All steps work offline with local database
- **Real-Time Updates**: Table occupancy updates via realtime listeners
- **Scalability**: Works with 1 to 1000+ tables
- **Mobile Optimized**: Responsive layout for tablet/phone
- **Error Handling**: Graceful fallbacks for edge cases

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-28 | Initial implementation of table-first workflow with auto-seat selection |

---

**Document**: TABLE_FIRST_WORKFLOW_GUIDE.md
**File**: lib/screens/new_order_screen.dart
**Class**: NewOrderScreen & _NewOrderScreenState
