# POS Application - Comprehensive Flowchart

## Overview
This document contains detailed flowcharts representing the complete POS (Point of Sale) Flutter application architecture, including all modules, features, user flows, data interactions, and system-level processes.

---

## 1. APPLICATION LIFECYCLE & INITIALIZATION

```mermaid
graph TD
    A["🚀 App Start<br/>main.dart"] -->|Initialize| B["⚙️ System Initialization"]
    B --> C["🔥 Firebase Init"]
    B --> D["🟢 Supabase Init"]
    B --> E["📱 Local Database Init<br/>SQLite"]
    B --> F["📡 Connectivity Service Init"]
    B --> G["🔔 Notification Service Init"]
    
    C --> H["✅ Multi-Framework Ready"]
    D --> H
    E --> H
    F --> H
    G --> H
    
    H -->|Load UI| I["🎨 App Theme & Screen Utils"]
    I --> J["📦 Multi-Provider Setup"]
    J --> K["🎯 Navigate to Splash Screen"]
    
    K --> L{App<br/>State?}
    L -->|First Time| M["🎬 Onboarding Screen"]
    L -->|Logged Out| N["🔐 Login Screen"]
    L -->|Logged In &<br/>Valid Session| O["📊 Dashboard"]
    L -->|Subscription<br/>Expired| P["⚠️ Subscription Expired Screen"]
    
    M --> N
    N -->|Authentication| Q["✅ Session Valid?"]
    Q -->|No| N
    Q -->|Yes| O
    
    style A fill:#FF6B6B
    style H fill:#51CF66
    style O fill:#339AF0
    style P fill:#FFD93D
```

---

## 2. AUTHENTICATION SYSTEM

```mermaid
graph TD
    A["🔐 Login Screen"] --> B{Login<br/>Method?}
    
    B -->|Email & Password| C["📧 Email Login Flow"]
    B -->|Phone OTP| D["📱 Phone OTP Flow"]
    B -->|Google Sign-In| E["🔵 Google OAuth"]
    
    C --> F["🔍 Validate Credentials"]
    D --> G["📨 Send OTP"]
    E --> H["🔗 Google Token Exchange"]
    
    F --> I{User<br/>Found?}
    I -->|No| J["❌ Email Not Found"]
    I -->|Yes| K{Password<br/>Correct?}
    
    K -->|No| L["❌ Wrong Password"]
    K -->|Yes| M["✅ Credentials Valid"]
    
    G --> N["👤 User Enters OTP"]
    N --> O{OTP<br/>Valid?}
    O -->|No| P["❌ Invalid OTP<br/>Resend?"]
    P -->|Yes| G
    O -->|Yes| M
    
    H --> Q{Google<br/>Account<br/>Exists?}
    Q -->|No| R["🆕 Account Created"]
    Q -->|Yes| M
    
    R --> M
    M --> S["🔎 Check User Status"]
    
    S --> T{Account<br/>Active?}
    T -->|Deactivated| U["⚠️ Account Deactivated<br/>Contact Admin"]
    T -->|Active| V["💳 Check Subscription"]
    
    V --> W{Subscription<br/>Valid?}
    W -->|Expired| X["⚠️ Subscription Expired Screen"]
    W -->|Active| Y["📦 Fetch User Data<br/>& Preferences"]
    
    Y --> Z["🛡️ Create Secure Session"]
    Z --> AA["📲 Store Session Token"]
    AA --> BB["🎯 Navigate to Dashboard"]
    
    U --> CC["🔐 Logout & Return to Login"]
    X --> CC
    
    L --> J
    style A fill:#FF6B6B
    style BB fill:#51CF66
    style CC fill:#FFD93D
    style U fill:#FF6B6B
    style X fill:#FFD93D
```

---

## 3. ROLE-BASED ACCESS CONTROL & NAVIGATION

```mermaid
graph TD
    A["✅ User Logged In"] --> B["🔎 Fetch User Role"]
    
    B --> C{User<br/>Role?}
    
    C -->|Owner| D["👑 Owner Portal"]
    C -->|Manager| E["👨‍💼 Manager Portal"]
    C -->|Admin| F["🔧 Admin Portal"]
    C -->|Staff| G["👥 Staff Portal"]
    C -->|System| H["⚙️ System Admin Portal"]
    
    D --> D1["📊 Dashboard<br/>🗂️ All Menus<br/>📦 Inventory<br/>👥 Employees<br/>📅 Tables<br/>📋 Reports<br/>⚙️ Settings"]
    
    E --> E1["📊 Dashboard<br/>🗂️ All Menus<br/>📦 Inventory<br/>👥 Employees<br/>📅 Tables<br/>📋 Reports"]
    
    F --> F1["📊 Dashboard<br/>🗂️ All Menus<br/>📦 Inventory<br/>⚠️ Restricted: Employees"]
    
    G --> G1["📋 Orders<br/>🗂️ Menu View<br/>📅 Tables<br/>⚠️ Restricted: Inventory<br/>⚠️ Restricted: Reports"]
    
    H --> H1["🔧 Full System Access<br/>All Features<br/>All Roles<br/>All Data"]
    
    D1 --> I["💾 Store Role in<br/>Local Preferences"]
    E1 --> I
    F1 --> I
    G1 --> I
    H1 --> I
    
    I --> J["🎯 Load Role-Specific<br/>Navigation"]
    J --> K["📱 Render Bottom<br/>Navigation Bar"]
    K --> L["✅ User Can Now Access<br/>Permitted Modules"]
    
    style D fill:#51CF66
    style E fill:#339AF0
    style F fill:#FFD93D
    style G fill:#FFA500
    style H fill:#EB5757
    style L fill:#51CF66
```

---

## 4. MAIN APPLICATION NAVIGATION STRUCTURE

```mermaid
graph TD
    A["📊 Dashboard<br/>Main Hub"] --> B{Navigation<br/>Selection}
    
    B -->|Tab 1| C["📊 Dashboard/Analytics"]
    B -->|Tab 2| D["📋 Orders Screen"]
    B -->|Tab 3| E["📅 Tables & Reservations"]
    B -->|Tab 4| F["🗂️ Menu Management"]
    B -->|Tab 5| G["📦 Inventory<br/>Role-Gated"]
    
    H["⚙️ Floating Menu"] -->|Settings| I["⚙️ Profile & Settings"]
    H -->|Reports| J["📊 Reports Screen"]
    H -->|Employees| K["👥 Employee Management<br/>Role-Gated"]
    H -->|Suppliers| L["🏭 Supplier Management<br/>Part of Inventory"]
    
    I --> M["👤 Profile Screen<br/>Edit Name/Email<br/>Change Password<br/>Theme Settings<br/>Dark Mode Toggle"]
    
    C --> C1["📈 Revenue Analytics<br/>Weekly/Monthly/Yearly<br/>Top Items<br/>Staff Performance<br/>Table Stats"]
    
    D --> D1["📦 Active Orders"]
    D1 --> D2{Order<br/>Status?}
    D2 -->|Pending| D3["⏳ Pending Orders"]
    D2 -->|Preparing| D4["👨‍🍳 Preparing Orders"]
    D2 -->|Ready| D5["✅ Ready Orders<br/>→ Collect Payment"]
    D2 -->|Completed| D6["💚 Completed Orders"]
    D2 -->|Cancelled| D7["❌ Cancelled Orders"]
    
    D3 --> D8["Add Item Menu<br/>→ Create New Order<br/>Table Selection<br/>Item Selection<br/>Quantity/Options<br/>Special Notes"]
    
    E --> E1["🏢 Floor View<br/>Visual Table Layout<br/>Real-time Status"]
    E --> E2["📅 Calendar View<br/>Upcoming Reservations<br/>Date Selection"]
    E --> E3["📜 History View<br/>Past Reservations"]
    
    E1 --> E4{Action?}
    E4 -->|Seat Guests| E5["👥 Assign Guests to Seats<br/>Generate Session ID<br/>Load Menu"]
    E4 -->|Reserve Table| E6["📅 Make Reservation<br/>Date/Time Selection<br/>Guest Info<br/>Special Requests"]
    E4 -->|View/Edit| E7["👁️ Table Details<br/>Current Status<br/>Guest Info<br/>Session Duration"]
    
    F --> F1["🗂️ Categories<br/>Manage Categories<br/>View/Edit/Delete<br/>Reorder"]
    F --> F2["🍽️ Menu Items<br/>View All Items<br/>Filter by Category<br/>Search Items<br/>Offline Sync Widget"]
    
    F1 --> F3{Admin<br/>Action?}
    F3 -->|Add| F4["➕ Add Category<br/>Name/Description<br/>Color Selection<br/>Upload Image"]
    F3 -->|Edit| F5["✏️ Edit Category<br/>Update Details<br/>Change Image"]
    F3 -->|Delete| F6["🗑️ Delete Category<br/>Confirmation"]
    
    F2 --> F7{Admin<br/>Action?}
    F7 -->|Add| F8["➕ Add Menu Item<br/>Name/Price<br/>Description<br/>Category Selection<br/>Dietary Info<br/>Upload Images<br/>Tags & Allergens"]
    F7 -->|Edit| F9["✏️ Edit Menu Item<br/>Update All Fields<br/>Change Availability"]
    F7 -->|Delete| F10["🗑️ Delete Menu Item<br/>Confirmation"]
    
    G --> G1["📦 Stock View<br/>Items by Status<br/>Stock Levels<br/>Alerts"]
    G1 --> G2{Filter?}
    G2 -->|All| G3["All Inventory Items"]
    G2 -->|In Stock| G4["✅ In Stock Items"]
    G2 -->|Low Stock| G5["⚠️ Low Stock Items"]
    G2 -->|Critical| G6["🔴 Critical Stock"]
    G2 -->|Out of Stock| G7["❌ Out of Stock"]
    
    G3 --> G8{Action?}
    G8 -->|Add| G9["➕ Add Inventory Item<br/>Name/Category<br/>Stock Level<br/>Unit/Cost<br/>Supplier<br/>Reorder Level"]
    G8 -->|Update| G10["🔄 Update Stock<br/>Manual Adjustment<br/>Stock In/Out<br/>Waste Recording"]
    G8 -->|Delete| G11["🗑️ Delete Item<br/>Confirmation"]
    
    L --> L1["🏭 Suppliers Management<br/>View Suppliers<br/>Payment History<br/>Delivery Tracking<br/>Sync with Inventory"]
    
    J --> J1["📊 Reports Dashboard<br/>Customizable Date Range<br/>Multiple Report Types"]
    J1 --> J2{Report<br/>Type?}
    J2 -->|Sales| J3["💰 Sales Report<br/>Daily/Weekly/Monthly<br/>Revenue Analytics<br/>Order Count"]
    J2 -->|Inventory| J4["📦 Inventory Report<br/>Stock Levels<br/>Reorder Analysis<br/>Supplier Summary"]
    J2 -->|Staff| J5["👥 Staff Performance<br/>Orders Per Staff<br/>Revenue per Staff<br/>Efficiency Metrics"]
    J2 -->|Table| J6["📅 Table Analytics<br/>Occupancy Rates<br/>Reservation Summary<br/>Peak Hours"]
    
    K --> K1["👥 Employees List<br/>Add/Edit/Delete<br/>Assign Roles<br/>View Activity<br/>Deactivate Accounts"]
    
    style A fill:#339AF0
    style C fill:#51CF66
    style D fill:#51CF66
    style E fill:#51CF66
    style F fill:#51CF66
    style G fill:#51CF66
    style I fill:#FFD93D
    style J fill:#FFD93D
    style K fill:#FFD93D
```

---

## 5. ORDERS MODULE - DETAILED FLOW

```mermaid
graph TD
    A["📱 Orders Screen"] --> B["🔄 Load Today's Orders<br/>From Local + Remote"]
    
    B --> C["📊 Display Orders by Status"]
    
    C --> C1["⏳ Pending"]
    C --> C2["👨‍🍳 Preparing"]
    C --> C3["✅ Ready<br/>Payment Gateway"]
    C --> C4["💚 Completed"]
    C --> C5["❌ Cancelled"]
    
    D["➕ Create New Order"] --> D1{Order<br/>Type?}
    D1 -->|Table Order| D2["📅 Select Table"]
    D1 -->|QR Code Order| D3["📱 Scan QR Code<br/>Get Table Info"]
    
    D2 --> D4["🗂️ Display Menu<br/>Categories<br/>Items<br/>Search/Filter"]
    D3 --> D4
    
    D4 --> D5["➕ Add Items<br/>Select Quantity<br/>Customize Options<br/>Add Special Notes"]
    
    D5 --> D6["🔢 Select Quantity<br/>Min: 1"]
    D6 --> D7["⚙️ Item Options<br/>Size/Spice Level<br/>Modifications"]
    D7 --> D8["📝 Special Instructions"]
    
    D8 --> D9["💰 Calculate Total<br/>Item Price × Qty<br/>+ Tax"]
    
    D9 --> D10{Review<br/>Order?}
    D10 -->|Add More| D5
    D10 -->|Proceed| D11["📤 Submit Order<br/>to Backend"]
    
    D11 --> D12{Online?}
    D12 -->|Yes| D13["⬆️ Send to Supabase<br/>Generate UUID<br/>Store Session ID"]
    D12 -->|No| D14["💾 Store Locally<br/>Mark as Pending<br/>Queue for Sync"]
    
    D13 --> D15["✅ Order Confirmed<br/>Created at Current Time<br/>Session Active"]
    D14 --> D15
    
    D15 --> D16["📢 Notify Kitchen<br/>Local Notification<br/>Realtime Alert"]
    
    E["🔄 Order Status Update"] --> E1["📡 Realtime Listener<br/>Supabase Channel"]
    E1 --> E2{Status<br/>Change?}
    
    E2 -->|Pending→Preparing| E3["👨‍🍳 Kitchen Started<br/>Notify Staff"]
    E2 -->|Preparing→Ready| E4["✅ Order Ready<br/>Display 'Collect Payment'<br/>Notify Table/Staff"]
    E2 -->|Ready→Completed| E5["💚 Order Completed<br/>Payment Confirmed<br/>Remove from Active View<br/>Add to History"]
    E2 -->|Any→Cancelled| E6["❌ Order Cancelled<br/>Remove from View<br/>Notify Stakeholders"]
    
    E3 --> E7["⏱️ Track Preparation<br/>Time Remaining"]
    E4 --> E8{Payment<br/>Status?}
    
    E8 -->|No Payment Yet| E9["💳 Open Payment Sheet<br/>Select Payment Method<br/>Cash/Card/UPI/Wallet"]
    E8 -->|Already Paid| E5
    
    E9 --> E10{Payment<br/>Confirmed?}
    E10 -->|Yes| E11["✅ Mark as Paid<br/>Update Status to Completed"]
    E10 -->|No| E12["⚠️ Payment Failed<br/>Show Error<br/>Retry"]
    
    E11 --> E5
    E12 --> E9
    
    F["🔍 View Order Details"] --> F1["📋 Full Order Info<br/>Items List<br/>Quantities<br/>Prices<br/>Special Notes<br/>Preparation Time<br/>Staff Assigned"]
    
    F1 --> F2["💾 Show Bill Preview<br/>Itemized List<br/>Subtotal<br/>Tax<br/>Total<br/>Print Bill<br/>Download PDF"]
    
    G["🗑️ Cancel Order"] --> G1{Cancellation<br/>Stage?}
    G1 -->|Pending| G2["⚠️ Confirm Cancellation<br/>Notify Kitchen<br/>Update Status"]
    G1 -->|Preparing| G3["⚠️ Order in Progress<br/>Confirm Force Cancel?<br/>Notify Kitchen"]
    G1 -->|Ready/Completed| G4["❌ Cannot Cancel<br/>Order Already Served"]
    
    G2 --> G5["📤 Send Update<br/>to Supabase"]
    G3 --> G5
    
    G5 --> G6["✅ Cancellation<br/>Complete"]
    
    H["📡 Offline Sync"] --> H1{Online<br/>Status?}
    H1 -->|Goes Online| H2["🔄 Sync Pending Orders<br/>From Local Queue"]
    H2 --> H3["🔍 Check Conflicts<br/>Validate Session ID"]
    H3 --> H4{Validation<br/>Pass?}
    H4 -->|Yes| H5["✅ Sync Success<br/>Mark Local as Synced<br/>Update with Server ID"]
    H4 -->|No| H6["❌ Sync Failed<br/>Log Error<br/>Retry Later"]
    
    style A fill:#FFA500
    style D11 fill:#51CF66
    style D15 fill:#51CF66
    style E15 fill:#51CF66
    style H5 fill:#51CF66
    style H6 fill:#FF6B6B
```

---

## 6. TABLES & RESERVATIONS MODULE - DETAILED FLOW

```mermaid
graph TD
    A["📅 Tables & Reservations"] --> B["🏪 Three View Modes"]
    
    B --> B1["🏢 Floor View<br/>Visual Table Layout"]
    B --> B2["📆 Calendar View<br/>Upcoming Reservations"]
    B --> B3["📜 History View<br/>Past Reservations"]
    
    B1 --> C["🏭 Load All Tables<br/>by Section & Status"]
    C --> C1["AC Hall"]
    C --> C2["Non-AC"]
    C --> C3["Rooftop"]
    C --> C4["Garden"]
    C --> C5["Private Room"]
    
    C1 --> D["📊 Display Table Card<br/>Table Number<br/>Capacity<br/>Current Status<br/>Reservation Badge"]
    C2 --> D
    C3 --> D
    C4 --> D
    C5 --> D
    
    D --> E{Table<br/>Status?}
    E -->|Available<br/>Green| F["✅ No Guest"]
    E -->|Occupied<br/>Red| G["🍽️ Seated <br/>with Session"]
    E -->|Reserved<br/>Blue| H["📅 Reservation<br/>Upcoming"]
    E -->|Cleaning<br/>Yellow| I["🧹 Being Cleaned"]
    
    J["📅 Seat Guests"] --> K["📋 Select Table"]
    K --> L["👥 Seat How Many?<br/>Select Specific Seats<br/>Auto-assign Seats<br/>Custom Seating"]
    
    L --> M["🔀 Generate Session ID<br/>UUID v4"]
    M --> N["🍽️ Mark Seats as Occupied<br/>Update Table Status"]
    N --> O["📱 Load Menu for Table<br/>Display QR Code<br/>Show Table Number"]
    
    O --> P["✅ Guest Seated<br/>Session Active<br/>Ready for Orders"]
    
    Q["📅 Make Reservation"] --> R["📆 Select Date & Time<br/>Calendar Picker<br/>From-To Selection"]
    
    R --> S["👤 Guest Information<br/>Name<br/>Phone Number<br/>Email<br/>Number of Guests"]
    
    S --> T["📝 Special Requests<br/>High Chair Needed?<br/>Dietary Restrictions<br/>Occasion Notes"]
    
    T --> U["📤 Submit Reservation<br/>Check Table Availability"]
    
    U --> U1{Table<br/>Available?}
    U1 -->|Yes| U2["✅ Reservation Created<br/>Send Confirmation<br/>Email/SMS<br/>Add to Calendar"]
    U1 -->|No| U3["❌ No Available Tables<br/>Suggest Alternative Times<br/>Back to Selection"]
    
    U3 --> R
    
    U2 --> U4["🔔 Notification Timeline<br/>30min before: Check-in<br/>20min before: Check-in<br/>15min before: Check-in<br/>5min before: Reminder<br/>Slot Passed: Auto-Expiry<br/>30min after: No-Show"]
    
    V["📅 Reservation Management"] --> V1["👁️ View Reservation<br/>Guest Info<br/>Reservation Time<br/>Table Info<br/>Special Notes<br/>Reservation Status"]
    
    V1 --> V2{Action?}
    V2 -->|Check In| V3["✅ Check In Guest<br/>Mark as Active<br/>Seat at Table"]
    V2 -->|Edit| V4["✏️ Edit Reservation<br/>Change Time/Guests<br/>Update Notes"]
    V2 -->|Cancel| V5["❌ Cancel Reservation<br/>Free Up Table<br/>Send Notification"]
    V2 -->|No Show| V6["⏭️ Mark as No-Show<br/>Table Becomes Available<br/>Log History"]
    
    V3 --> V7["🔀 Generate Session ID<br/>Link Reservation to Session"]
    V7 --> P
    V4 --> U
    
    W["📊 Reservation Auto-Expiry"] --> W1["⏰ Check Slot Status<br/>Current Time vs Slot Time"]
    
    W1 --> W2{Time<br/>Status?}
    W2 -->|Before Slot| W3["⏳ Waiting for Guest<br/>Notifications Active"]
    W2 -->|Slot Passed <br/>No Check-in| W4["❌ Reservation Expired<br/>Auto-status: Expired<br/>Table Released<br/>Send Late Notification"]
    W2 -->|Checked In| W5["✅ Active Session<br/>Order Taking Active<br/>Session Duration Track"]
    
    X["🔐 Session Management"] --> X1["🔀 Active Session<br/>Table Seated<br/>Guest Count<br/>Seating Time<br/>Current Orders"]
    
    X1 --> X2["🕐 Track Duration<br/>Alerts at 2hrs<br/>Alerts at 3hrs<br/>Auto-suggest Checkout"]
    
    X2 --> X3{Session<br/>Complete?}
    X3 -->|Manual Checkout| X4["🧹 End Session<br/>Finalize Bill<br/>Clear Table<br/>Update Occupancy"]
    X3 -->|Auto After 4hrs| X5["⏰ Auto-Checkout<br/>Session Timeout<br/>Table Cleaning Mode"]
    
    X4 --> X6["📤 Clear Orders<br/>Archive Session Data<br/>Log in History"]
    X5 --> X6
    
    X6 --> X7["🧹 Table Status<br/>→ Cleaning"]
    X7 --> X8{Cleaning<br/>Complete?}
    X8 -->|Manual Mark| X9["✅ Table Available<br/>Status Reset"]
    X8 -->|Timeout 30min| X9
    
    Y["📡 Offline Sync"] --> Y1["💾 Local Cache<br/>All Tables<br/>All Reservations<br/>Session Data"]
    
    Y1 --> Y2{Online?}
    Y2 -->|Goes Online| Y3["🔄 Sync Changes<br/>New Reservations<br/>Status Updates<br/>Checkouts"]
    Y3 --> Y4["✅ Sync Complete<br/>Update Local Cache"]
    
    style A fill:#FFA500
    style P fill:#51CF66
    style U2 fill:#51CF66
    style X9 fill:#51CF66
    style Y4 fill:#51CF66
    style U3 fill:#FFD93D
    style W4 fill:#FF6B6B
```

---

## 7. INVENTORY & SUPPLIER MANAGEMENT - DETAILED FLOW

```mermaid
graph TD
    A["📦 Inventory Module<br/>Role-Gated:<br/>Owner/Manager/Admin Only"] --> B["📊 Inventory Dashboard<br/>Total Items<br/>Low Stock Count<br/>Out of Stock Count<br/>Total Inventory Value"]
    
    B --> C["🔍 Search & Filter<br/>By Category<br/>By Status<br/>By Unit<br/>Sort by: Name/Stock/Date"]
    
    C --> D["📊 Display Inventory Items<br/>Item Card<br/>Stock Level Bar<br/>Status Badge<br/>Quick Actions"]
    
    D --> E{Item<br/>Status?}
    E -->|In Stock| E1["✅ Green<br/>Stock OK"]
    E -->|Low Stock| E2["⚠️ Yellow<br/>Below Reorder Level"]
    E -->|Critical| E3["🔴 Red<br/>Very Low<br/>Urgent Reorder"]
    E -->|Out of Stock| E4["❌ Gray<br/>No Stock<br/>Unavailable"]
    
    F["➕ Add Inventory Item"] --> F1["📝 Item Details<br/>Name<br/>Category<br/>Description<br/>SKU<br/>Unit of Measure<br/>Cost Price<br/>Selling Price"]
    
    F1 --> F2["📊 Stock Settings<br/>Current Stock Level<br/>Reorder Level<br/>Min Stock<br/>Max Stock<br/>Lead Time Days"]
    
    F2 --> F3["🏭 Supplier Info<br/>Select Supplier<br/>Supplier SKU<br/>Packaging Size"]
    
    F3 --> F4["📸 Attachments<br/>Upload Image<br/>Storage Location<br/>Barcode"]
    
    F4 --> F5["💾 Save Item<br/>Generate UUID<br/>Set Timestamps<br/>Add to Local DB"]
    
    F5 --> F6{Online?}
    F6 -->|Yes| F7["📤 Sync to Supabase<br/>Immediately"]
    F6 -->|No| F8["💾 Queue for Sync<br/>When Online"]
    
    F7 --> F9["✅ Item Created"]
    F8 --> F9
    
    G["✏️ Update Stock"] --> G1{Update<br/>Type?}
    G1 -->|Stock IN| G2["⬆️ Stock Received<br/>From Supplier<br/>Enter Quantity<br/>Supplier Name<br/>Cost<br/>Receipt Date"]
    G1 -->|Stock OUT| G3["⬇️ Stock Used<br/>For Cooking<br/>Enter Quantity<br/>Usage Date"]
    G1 -->|Adjustment| G4["🔄 Manual Adjustment<br/>Reason<br/>Quantity Change<br/>Adjustment Date"]
    G1 -->|Waste| G5["🗑️ Record Waste<br/>Quantity Wasted<br/>Reason<br/>Waste Date"]
    
    G2 --> G6["📊 Create Transaction<br/>Stock Transaction ID<br/>Previous Stock<br/>New Stock<br/>Timestamp<br/>Created By"]
    G3 --> G6
    G4 --> G6
    G5 --> G6
    
    G6 --> G7["💾 Save Transaction<br/>Update Item Stock<br/>Log in History"]
    
    G7 --> G8{Stock<br/>Level<br/>Below<br/>Reorder?}
    G8 -->|Yes| G9["🔔 Send Notification<br/>Type: Low Stock<br/>Recommend Reorder"]
    G8 -->|No| G10["✅ Continue"]
    
    G9 --> G10
    
    H["🏭 Supplier Management"] --> H1["📋 Suppliers List<br/>Supplier Name<br/>Contact Info<br/>Total Orders<br/>Payment Status"]
    
    H1 --> H2{Action?}
    H2 -->|View| H3["👁️ Supplier Details<br/>Company Info<br/>Contact Person<br/>Phone/Email<br/>Address<br/>Bank Details"]
    H2 -->|Add Order| H4["📦 Create Supplier Order<br/>Select Items<br/>Quantities<br/>Expected Delivery<br/>Special Terms"]
    H2 -->|Payment| H5["💳 Supplier Payment<br/>View Outstanding<br/>Record Payment<br/>Payment Method<br/>Amount<br/>Date"]
    H2 -->|Delivery| H6["🚚 Track Delivery<br/>Expected Date<br/>Status<br/>Items Received"]
    
    H3 --> H7["✏️ Edit Supplier<br/>Update Info"]
    H4 --> H8["📤 Place Order<br/>Generate Order ID"]
    H5 --> H9["✅ Record Payment"]
    H6 --> H10["✅ Mark Delivered<br/>Update Stock"]
    
    I["📊 Inventory Reports"] --> I1["📈 Stock Analytics<br/>by Category<br/>by Status<br/>by Supplier<br/>Inventory Value"]
    
    I1 --> I2["📋 Reorder Report<br/>Items Below Reorder Level<br/>Recommended Quantity<br/>Supplier<br/>Estimated Cost"]
    
    I2 --> I3["📉 Usage Analytics<br/>Daily Usage<br/>Trending Items<br/>Waste Tracking<br/>Cost Analysis"]
    
    J["📡 Offline Sync"] --> J1["💾 Local Cache<br/>Inventory Items<br/>Suppliers<br/>Transactions"]
    
    J1 --> J2{Online?}
    J2 -->|Offline| J3["💾 Queue Changes<br/>New Items<br/>Stock Updates<br/>Transactions"]
    J2 -->|Online| J4["🔄 Sync All Changes<br/>UUID Validation<br/>Conflict Resolution"]
    
    J4 --> J5["✅ Sync Complete<br/>Inventory Updated"]
    
    style A fill:#FFA500
    style E1 fill:#51CF66
    style E2 fill:#FFD93D
    style E3 fill:#FF6B6B
    style E4 fill:#999999
    style F9 fill:#51CF66
    style J5 fill:#51CF66
```

---

## 8. MENU MANAGEMENT - DETAILED FLOW

```mermaid
graph TD
    A["🗂️ Menu Management<br/>Role-Gated:<br/>Owner/Manager/Admin/System"] --> B["📋 Menu Structure<br/>Categories<br/>Sub-Categories<br/>Items"]
    
    B --> B1["🗂️ Categories View<br/>All Categories<br/>Item Count<br/>Status<br/>Color/Image"]
    B --> B2["🍽️ Menu Items View<br/>All Items<br/>Filter by Category<br/>Search Items<br/>Status Badges"]
    
    B1 --> C["➕ Add Category"]
    C --> C1["📝 Category Details<br/>Name<br/>Description<br/>Color Hex<br/>Sort Order"]
    
    C1 --> C2["📸 Upload Image<br/>Category Icon<br/>Display Image<br/>Firebase Storage"]
    
    C2 --> C3["💾 Save Category<br/>Generate ID<br/>Set Timestamps<br/>Created By"]
    
    C3 --> C4{Online?}
    C4 -->|Yes| C5["📤 Sync to Supabase"]
    C4 -->|No| C6["💾 Queue for Sync"]
    
    C5 --> C7["✅ Category Created"]
    C6 --> C7
    
    D["✏️ Update Category"] --> D1["📝 Edit Details<br/>Name/Description<br/>Color<br/>Order"]
    
    D1 --> D2["📸 Change Image<br/>Upload New<br/>Delete Current"]
    
    D2 --> D3["💾 Save Changes<br/>Update Timestamps"]
    
    D3 --> D4["📤 Sync if Online"]
    
    D4 --> D5["✅ Category Updated"]
    
    E["🗑️ Delete Category"] --> E1["⚠️ Confirmation<br/>Items in Category?<br/>Reassign or Delete?"]
    
    E1 --> E2{Items<br/>Exist?}
    E2 -->|Yes| E3["🔄 Reassign Items<br/>Select New Category<br/>or Delete Items"]
    E2 -->|No| E4["🗑️ Delete Category<br/>Immediately"]
    
    E3 --> E4
    E4 --> E5["📤 Sync Deletion"]
    E5 --> E6["✅ Category Deleted"]
    
    F["🍽️ Menu Items Management"] --> F1["➕ Add Menu Item"]
    
    F1 --> F2["📝 Basic Info<br/>Name<br/>Category<br/>Subcategory<br/>Description<br/>Price<br/>Discount Price"]
    
    F2 --> F3["🏷️ Item Attributes<br/>Vegetarian<br/>Vegan<br/>Spicy Level<br/>Prepared Time<br/>Calories<br/>Protein/Carbs/Fat<br/>Allergens"]
    
    F3 --> F4["🎯 Availability<br/>Available<br/>Discontinued<br/>Seasonal<br/>Featured Status<br/>Best Seller<br/>New Arrival"]
    
    F4 --> F5["📸 Images<br/>Item Photos<br/>Main Image<br/>Multiple Views<br/>Firebase Storage"]
    
    F5 --> F6["🏷️ Tags & Info<br/>Tags for Search<br/>Ingredients List<br/>Serving Size"]
    
    F6 --> F7["💾 Create Item<br/>Generate UUID<br/>Set Timestamps<br/>Created By"]
    
    F7 --> F8{Valid<br/>UUID?}
    F8 -->|Yes| F9["📤 Save Locally<br/>Add to Cache"]
    F8 -->|No| F10["❌ Validation Error<br/>Regenerate"]
    
    F10 --> F9
    F9 --> F11["🔄 Sync if Online"]
    F11 --> F12["✅ Item Created"]
    
    G["✏️ Edit Menu Item"] --> G1["📝 Update Fields<br/>Name/Price<br/>Description<br/>Category<br/>Attributes"]
    
    G1 --> G2["📸 Update Images<br/>Replace/Add<br/>Remove Images"]
    
    G2 --> G3["💾 Save Changes<br/>Update Timestamps<br/>Audit Trail"]
    
    G3 --> G4["🔄 Sync Changes"]
    
    G4 --> G5["✅ Item Updated<br/>Reflect in Orders<br/>Update Menu Cache"]
    
    H["🗑️ Delete Menu Item"] --> H1["⚠️ Confirmation<br/>Item in Active Orders?<br/>Cancel Orders?"]
    
    H1 --> H2{Active<br/>Orders?}
    H2 -->|Yes| H3["⚠️ Warning<br/>Cancel Associated Orders?"]
    H2 -->|No| H4["🗑️ Safe to Delete"]
    
    H3 --> H5{Confirm?}
    H5 -->|Yes| H6["❌ Cancel Orders<br/>Notify Customers"]
    H5 -->|No| H4
    
    H6 --> H7["🗑️ Delete Item"]
    H4 --> H7
    
    H7 --> H8["📤 Sync Deletion<br/>Mark as Soft Delete"]
    
    H8 --> H9["✅ Item Deleted"]
    
    I["📡 Offline Menu Sync"] --> I1["💾 Local Cache<br/>Categories<br/>Menu Items<br/>Images"]
    
    I1 --> I2["📱 Offline Support<br/>Browse Menu Offline<br/>Create Orders Offline<br/>Sync When Online"]
    
    I2 --> I3{Online<br/>Status?}
    I3 -->|Offline| I4["📱 Show Local Cache<br/>Disable Edits<br/>Queue Changes"]
    I3 -->|Online| I5["🔄 Pull Latest<br/>Sync Changes<br/>Update Cache"]
    
    I5 --> I6["✅ Menu Updated"]
    
    style A fill:#FFA500
    style C7 fill:#51CF66
    style E6 fill:#51CF66
    style F12 fill:#51CF66
    style G5 fill:#51CF66
    style H9 fill:#51CF66
    style I6 fill:#51CF66
```

---

## 9. OFFLINE-FIRST ARCHITECTURE & DATA SYNC

```mermaid
graph TD
    A["📱 Application States"] --> B["🟢 Online"]
    A --> C["🔴 Offline"]
    
    B --> B1["Live Data<br/>Real-time Sync<br/>Supabase<br/>Immediate Updates"]
    
    C --> C1["Local Cache<br/>SQLite<br/>Pending Queue<br/>No Real-time"]
    
    D["💾 Local Database<br/>SQLite: pos_app_offline.db"] --> D1["Tables Created"]
    
    D1 --> D2["offline_queue"]
    D1 --> D3["local_orders"]
    D1 --> D4["local_tables"]
    D1 --> D5["table_seats"]
    D1 --> D6["local_reservations"]
    D1 --> D7["local_menu_items"]
    D1 --> D8["local_menu_categories"]
    D1 --> D9["local_inventory"]
    D1 --> D10["local_suppliers"]
    D1 --> D11["local_profile"]
    D1 --> D12["sync_meta"]
    D1 --> D13["local_seat_history"]
    
    E["📞 Connectivity Service"] --> E1["🔍 Monitor Network"]
    E1 --> E2{Connection<br/>Status?}
    
    E2 -->|Online| E3["✅ Internet Available<br/>DNS Reachable<br/>Supabase Accessible"]
    E2 -->|Offline| E4["❌ No Connection<br/>DNS Unreachable<br/>Switch to Local"]
    
    E3 --> E5["Stream: onConnected<br/>Trigger Sync"]
    E4 --> E6["Stream: onStatusChange<br/>Notify Listeners"]
    
    E5 --> E7["🔄 OfflineSyncService<br/>Start Processing Queue"]
    
    F["🔄 Offline Data Operations"] --> F1{User<br/>Action?}
    
    F1 -->|Create| F2["➕ Create Entity<br/>Generate UUID<br/>Set Timestamps<br/>Save Locally<br/>Add to Queue"]
    
    F1 -->|Update| F3["✏️ Update Entity<br/>Validate Fields<br/>Update Local<br/>Mark as Updated<br/>Add to Queue"]
    
    F1 -->|Delete| F4["🗑️ Delete Entity<br/>Mark as Deleted<br/>Keep in Local<br/>Add to Queue"]
    
    F1 -->|Read| F5["👁️ Read Entity<br/>Fetch from Local<br/>Serve Immediately"]
    
    F2 --> F6["💾 Database Insert<br/>local_orders<br/>local_inventory<br/>local_menu_items<br/>etc"]
    
    F3 --> F6
    F4 --> F6
    
    F6 --> F7["📝 Queue Entry<br/>Entity Type<br/>Action (C/U/D)<br/>Entity ID<br/>Data<br/>Timestamp<br/>Attempt Count"]
    
    F7 --> F8["📤 Online?"]
    F8 -->|Yes| F9["⬆️ Immediate Sync"]
    F8 -->|No| F10["⏳ Pending Sync"]
    
    G["🔄 Sync Process<br/>When Going Online"] --> G1["📡 Connectivity: Online"]
    
    G1 --> G2["🔄 Start OfflineSyncService"]
    G2 --> G3["📋 Read Queue<br/>Get All Pending Entries<br/>Limit 50 at a time"]
    
    G3 --> G4{Queue<br/>Empty?}
    G4 -->|Yes| G5["✅ No Pending Sync<br/>Remote is Latest"]
    G4 -->|No| G6["🔄 Process Entry"]
    
    G6 --> G7{Entity<br/>Type?}
    
    G7 -->|Order| G8["📦 Sync Order"]
    G7 -->|Inventory| G9["📦 Sync Inventory"]
    G7 -->|Menu| G10["📦 Sync Menu"]
    G7 -->|Table| G11["📦 Sync Table"]
    G7 -->|Reservation| G12["📦 Sync Reservation"]
    G7 -->|Other| G13["📦 Sync Generic"]
    
    G8 --> G14{Action?}
    G9 --> G14
    G10 --> G14
    G11 --> G14
    G12 --> G14
    G13 --> G14
    
    G14 -->|Create| G15["⬆️ INSERT to Supabase<br/>POST /rest/v1/table"]
    G14 -->|Update| G16["⬆️ UPDATE to Supabase<br/>PATCH /rest/v1/table"]
    G14 -->|Delete| G17["⬆️ DELETE to Supabase<br/>DELETE /rest/v1/table"]
    
    G15 --> G18["📡 Network Request<br/>Validate UUID<br/>Clean Payload<br/>Remove Internal Fields"]
    G16 --> G18
    G17 --> G18
    
    G18 --> G19{Response<br/>Status?}
    
    G19 -->|2xx Success| G20["✅ Sync Success<br/>Update Local Sync Status<br/>Mark as 'synced'<br/>Remove from Queue<br/>Update Timestamps"]
    
    G19 -->|4xx Client Error| G21["❌ Permanent Error<br/>UUID Invalid<br/>Validation Failed<br/>Mark as 'failed'<br/>Log Error<br/>Move to Dead Letter Queue"]
    
    G19 -->|5xx Server Error| G22["⏳ Temporary Error<br/>Retry Later<br/>Increment Attempt<br/>Re-queue if < 5 attempts<br/>Exponential Backoff"]
    
    G19 -->|Network Error| G22
    
    G20 --> G23["🔄 Next Entry in Queue"]
    G21 --> G24["❌ Skip to Next<br/>Alert User if Critical"]
    G22 --> G24
    
    G23 --> G25{More<br/>Entries?}
    G24 --> G25
    
    G25 -->|Yes| G6
    G25 -->|No| G26["✅ Sync Cycle Complete<br/>Update SyncState<br/>Notify Listeners"]
    
    G26 --> G27["📊 Sync Statistics<br/>Total Synced<br/>Failed Count<br/>Remaining Queue<br/>Last Sync Time"]
    
    H["🔙 Reverse Sync<br/>Remote to Local"] --> H1["📋 Periodic Pull<br/>Every 5 minutes<br/>or on Connect"]
    
    H1 --> H2["⬇️ Fetch Latest<br/>From Supabase<br/>Use Updated_at"]
    
    H2 --> H3["🔄 Merge with Local<br/>Check Conflicts<br/>Local Timestamp vs Remote"]
    
    H3 --> H4{Conflict?}
    H4 -->|Local Newer| H5["📝 Keep Local<br/>Mark for Re-sync"]
    H4 -->|Remote Newer| H6["⬇️ Update Local<br/>Replace with Remote"]
    H4 -->|No Conflict| H6
    
    H6 --> H7["✅ Cache Updated<br/>Notify Providers"]
    
    I["🔔 Sync Status UI"] --> I1["SyncStatusWidget<br/>Shows Current State"]
    I1 --> I2["🟢 In Sync"]
    I1 --> I3["🔄 Syncing"]
    I1 --> I4["⏳ Pending"]
    I1 --> I5["❌ Error"]
    
    I2 --> I6["✅ All Data Synced"]
    I3 --> I6
    I4 --> I7["⚠️ Pending Changes<br/>Queue Count<br/>Retry Button"]
    I5 --> I8["❌ Sync Failed<br/>Error Message<br/>Retry Button"]
    
    style B1 fill:#51CF66
    style C1 fill:#FFD93D
    style G20 fill:#51CF66
    style G21 fill:#FF6B6B
    style G22 fill:#FFD93D
    style G26 fill:#51CF66
    style I2 fill:#51CF66
    style I4 fill:#FFD93D
    style I5 fill:#FF6B6B
```

---

## 10. ANALYTICS & REPORTING SYSTEM

```mermaid
graph TD
    A["📊 Analytics Module<br/>Role-Gated:<br/>Owner/Manager/Admin/System"] --> B["📈 Revenue Analytics"]
    
    B --> B1["📊 Select Time Period"]
    B1 --> B2{Period?}
    B2 -->|Weekly| B3["7 Days<br/>Mon-Sun Current Week"]
    B2 -->|Monthly| B4["Full Month<br/>Day 1 to Current"]
    B2 -->|Yearly| B5["Full Year<br/>Jan-Dec Current Year"]
    
    B3 --> B6["📉 Chart Visualization<br/>Line Chart<br/>Revenue per Bucket<br/>Order Count per Bucket"]
    B4 --> B6
    B5 --> B6
    
    B6 --> B7["🔢 Metrics Calculated<br/>Total Revenue<br/>Average Revenue<br/>Highest Revenue<br/>Growth Rate<br/>Order Count"]
    
    B7 --> B8["📊 Display KPI Cards<br/>Total Revenue (INR)<br/>Avg Revenue per Day/Month<br/>Highest Revenue<br/>Growth %<br/>Total Orders"]
    
    C["🏆 Top Items Report"] --> C1["🍽️ Fetch Completed Orders<br/>Sum by Item<br/>Period: Last 30 Days"]
    
    C1 --> C2["📊 Rank Items<br/>By Order Count<br/>By Revenue<br/>Top 10 Items"]
    
    C2 --> C3["📋 Display<br/>Item Name<br/>Popularity %<br/>Revenue<br/>Chart Visualization"]
    
    D["👥 Staff Performance"] --> D1["🔍 Available Only to<br/>Owner/Manager/Admin/System"]
    
    D1 --> D2["📊 Fetch All Staff Orders<br/>Current Period"]
    
    D2 --> D3["📈 Group by Staff<br/>Calculate Metrics<br/>Total Orders<br/>Total Revenue<br/>Avg Order Value<br/>Efficiency Score"]
    
    D3 --> D4["🥇 Rank Staff<br/>By Orders<br/>By Revenue<br/>By Efficiency"]
    
    D4 --> D5["📋 Display Staff<br/>Staff Name<br/>Orders Count<br/>Revenue Generated<br/>Efficiency %<br/>Ranking Badge"]
    
    E["📅 Table Analytics"] --> E1["🔍 Available Only to<br/>Owner/Manager/Admin/System"]
    
    E1 --> E2["📊 Fetch All Reservations<br/>Current Period"]
    
    E2 --> E3["📈 Calculate Metrics<br/>Total Reservations<br/>Occupancy Rate<br/>Avg Guests/Table<br/>Peak Hours<br/>No-Show Rate"]
    
    E3 --> E4["📋 Display Analytics<br/>Total Bookings<br/>Occupancy %<br/>Peak Hours<br/>Avg Capacity<br/>No-Show Count"]
    
    F["📋 Reports Screen"] --> F1["📊 Report Selection<br/>Sales Report<br/>Inventory Report<br/>Staff Report<br/>Table Report"]
    
    F1 --> F2["📆 Date Range Selection<br/>Start Date<br/>End Date<br/>Preset: This Week<br/>Preset: This Month<br/>Preset: This Year"]
    
    F2 --> F3["📑 Report Generation"]
    
    F3 --> F4{Report<br/>Type?}
    
    F4 -->|Sales Report| F5["📊 Sales Report<br/>Daily/Weekly Totals<br/>Order Summary<br/>Revenue Breakdown<br/>Top Products"]
    
    F4 -->|Inventory Report| F6["📦 Inventory Report<br/>Stock Levels<br/>Reorder Analysis<br/>Low Stock Items<br/>Supplier Summary"]
    
    F4 -->|Staff Report| F7["👥 Staff Report<br/>Orders per Staff<br/>Revenue per Staff<br/>Efficiency Metrics<br/>Performance Ranking"]
    
    F4 -->|Table Report| F8["📅 Table Report<br/>Reservation Summary<br/>Occupancy Analysis<br/>Peak Hours<br/>Revenue per Table"]
    
    F5 --> F9["💾 Export Report"]
    F6 --> F9
    F7 --> F9
    F8 --> F9
    
    F9 --> F10{Format?}
    F10 -->|PDF| F11["📄 Generate PDF<br/>With Logo<br/>With Charts<br/>Email Ready"]
    F10 -->|CSV| F12["📊 Export CSV<br/>Open in Excel<br/>For Analysis"]
    F10 -->|Print| F13["🖨️ Print to Printer<br/>Formatted Layout"]
    
    F11 --> F14["✅ Report Ready<br/>Share/Download<br/>Email/WhatsApp<br/>Print/Archive"]
    F12 --> F14
    F13 --> F14
    
    G["🔐 Access Control<br/>Staff Users"] --> G1["❌ Hide Analytics Tab"]
    G1 --> G2["❌ Cannot View<br/>Revenue Data<br/>Staff Performance<br/>Table Analytics"]
    
    style A fill:#FFA500
    style B8 fill:#51CF66
    style C3 fill:#51CF66
    style D5 fill:#51CF66
    style E4 fill:#51CF66
    style F14 fill:#51CF66
    style G2 fill:#FF6B6B
```

---

## 11. EMPLOYEE MANAGEMENT MODULE

```mermaid
graph TD
    A["👥 Employee Management<br/>Role-Gated:<br/>Owner/Manager/Admin/System"] --> B["👤 Employees List<br/>All Staff<br/>Filter by Role<br/>Search by Name<br/>Sort Options"]
    
    B --> C["🔍 Display Employee<br/>Cards with<br/>Name<br/>Role/Department<br/>Status<br/>Quick Actions"]
    
    C --> D{Action?}
    
    D -->|View| D1["👁️ View Employee Details<br/>Personal Info<br/>Email<br/>Phone<br/>Role<br/>Department<br/>Join Date<br/>Performance Stats"]
    
    D -->|Add| D2["➕ Add New Employee"]
    
    D -->|Edit| D3["✏️ Edit Employee<br/>Update Info<br/>Change Role<br/>Update Department"]
    
    D -->|Deactivate| D4["🚫 Deactivate Account<br/>Confirm Action"]
    
    D1 --> D1A["👤 View Activity<br/>Orders Placed<br/>Revenue Generated<br/>Active Orders<br/>Performance Score"]
    
    D2 --> D2A["📝 Employee Details<br/>First Name<br/>Last Name<br/>Email Address<br/>Phone Number<br/>Date of Birth"]
    
    D2A --> D2B["👔 Role Assignment<br/>Select Role:<br/>Owner<br/>Manager<br/>Admin<br/>Staff<br/>System Admin"]
    
    D2B --> D2C["🏢 Department<br/>Kitchen<br/>Service<br/>Management<br/>Finance<br/>Operations"]
    
    D2C --> D2D["🔐 Access Permissions<br/>Based on Role:<br/>Can Create Orders<br/>Can Manage Inventory<br/>Can View Analytics<br/>Can Manage Menu<br/>Can See Reports"]
    
    D2D --> D2E["💾 Create Account<br/>Send Welcome Email<br/>Set Temporary Password<br/>Login Instructions"]
    
    D2E --> D2F["✅ Employee Created<br/>Active<br/>Can Login<br/>Access Granted"]
    
    D3 --> D3A["✏️ Update Details<br/>Name<br/>Email<br/>Phone<br/>Department"]
    
    D3A --> D3B["👔 Change Role<br/>From Current to New<br/>Update Permissions<br/>Notify Employee"]
    
    D3B --> D3C["💾 Save Changes<br/>Notify via Email<br/>Update in System"]
    
    D3C --> D3D["✅ Employee Updated"]
    
    D4 --> D4A["⚠️ Confirm Deactivation<br/>Employee: X<br/>Cancel/Confirm"]
    
    D4A --> D4B{Confirm?}
    D4B -->|No| D4C["❌ Cancelled"]
    D4B -->|Yes| D4D["🚫 Deactivate Account<br/>Status: Inactive<br/>Revoke Login<br/>Archive Data"]
    
    D4D --> D4E["📧 Send Notification<br/>Account Deactivated<br/>Reason<br/>Contact Support"]
    
    D4E --> D4F["✅ Deactivated<br/>Hidden from Active List<br/>Data Archived"]
    
    E["👔 Role Hierarchy<br/>& Permissions"] --> E1["👑 Owner<br/>✅ All Access<br/>✅ Manage Business<br/>✅ View All Reports<br/>✅ Manage Staff<br/>✅ Change Settings"]
    
    E --> E2["👨‍💼 Manager<br/>✅ Dashboard<br/>✅ Orders<br/>✅ Tables<br/>✅ Menu<br/>✅ Inventory<br/>✅ Reports<br/>❌ Staff Management<br/>❌ Settings"]
    
    E --> E3["🔧 Admin<br/>✅ Dashboard<br/>✅ Orders<br/>✅ Tables<br/>✅ Menu<br/>✅ Inventory<br/>❌ Reports<br/>❌ Staff Management<br/>❌ Settings"]
    
    E --> E4["👥 Staff<br/>✅ Orders<br/>✅ Tables<br/>✅ Menu View<br/>❌ Inventory<br/>❌ Reports<br/>❌ Management<br/>❌ Settings"]
    
    E --> E5["⚙️ System Admin<br/>✅ All Access<br/>✅ Backend Config<br/>✅ Database Access<br/>✅ Full Control<br/>✅ System Settings"]
    
    F["📊 Employee Performance"] --> F1["📈 Track Metrics<br/>Orders Created<br/>Revenue Generated<br/>Avg Order Value<br/>Customer Ratings<br/>Error Rate"]
    
    F1 --> F2["🏆 Performance Score<br/>Based on<br/>Orders/Day<br/>Revenue/Day<br/>Quality/Ratings<br/>Efficiency<br/>Attendance"]
    
    F2 --> F3["🥇 Rankings<br/>Top Performers<br/>Month View<br/>Quarter View<br/>Year View"]
    
    style A fill:#FFA500
    style D2F fill:#51CF66
    style D3D fill:#51CF66
    style D4F fill:#51CF66
    style E1 fill:#51CF66
    style E2 fill:#FFD93D
    style E3 fill:#FFD93D
    style E4 fill:#FFA500
    style E5 fill:#51CF66
```

---

## 12. ERROR HANDLING & RECOVERY SYSTEM

```mermaid
graph TD
    A["⚠️ Error Detection System"] --> B{Error<br/>Type?}
    
    B -->|Network Error| C["🌐 Network Issues<br/>No Internet<br/>Server Unreachable<br/>Timeout"]
    
    B -->|Authentication Error| D["🔐 Auth Issues<br/>Invalid Credentials<br/>Expired Token<br/>Session Invalid"]
    
    B -->|Data Error| E["📊 Data Issues<br/>Invalid UUID<br/>Null Reference<br/>Type Mismatch"]
    
    B -->|Validation Error| F["✓ Validation Issues<br/>Empty Field<br/>Invalid Format<br/>Out of Range"]
    
    B -->|Server Error| G["⚠️ Server Issues<br/>500 Error<br/>Rate Limited<br/>Service Unavailable"]
    
    B -->|Sync Error| H["🔄 Sync Issues<br/>Queue Conflict<br/>Duplicate ID<br/>Lost Transaction"]
    
    C --> C1["🔄 Recovery Strategy<br/>Show Offline Mode<br/>Queue Operations<br/>Retry on Connect<br/>Show Sync Widget"]
    
    D --> D1["🔐 Recovery Strategy<br/>Clear Session<br/>Redirect to Login<br/>Request Re-auth<br/>Show Message"]
    
    E --> E1["📊 Recovery Strategy<br/>Log Error<br/>Regenerate ID<br/>Fallback Value<br/>Show User Warning"]
    
    F --> F1["✓ Recovery Strategy<br/>Show Error Message<br/>Highlight Field<br/>Prevent Submission<br/>Suggest Fix"]
    
    G --> G1["⚠️ Recovery Strategy<br/>Show Error Dialog<br/>Retry Button<br/>Fallback to Local<br/>Queue Sync"]
    
    H --> H1["🔄 Recovery Strategy<br/>Remove Duplicate<br/>Merge Data<br/>Mark for Re-sync<br/>Log Conflict"]
    
    C1 --> I["📱 User Notification"]
    D1 --> I
    E1 --> I
    F1 --> I
    G1 --> I
    H1 --> I
    
    I --> I1{Notification<br/>Level?}
    
    I1 -->|Info| I2["ℹ️ Snackbar/Toast<br/>Non-blocking<br/>Auto-dismiss<br/>Neutral Color"]
    
    I1 -->|Warning| I3["⚠️ Snackbar/Toast<br/>User Action Needed<br/>Yellow/Orange<br/>30sec Display"]
    
    I1 -->|Error| I4["❌ Error Dialog<br/>Modal<br/>User Must Act<br/>Red Color<br/>Explanation Text<br/>Retry/Cancel"]
    
    I1 -->|Critical| I5["🔴 Full Screen Alert<br/>Critical Action<br/>Logging Out<br/>Connection Failed<br/>Data Loss Risk"]
    
    J["🛡️ Crash Management"] --> J1["💥 Uncaught Exception"]
    
    J1 --> J2["📝 Capture Stack Trace<br/>Error Message<br/>Code Location<br/>Device Info<br/>Timestamp"]
    
    J2 --> J3["💾 Log Locally<br/>Save to Device<br/>Upload on Next Online"]
    
    J3 --> J4["📤 Send to Backend<br/>Crash Report<br/>User Info<br/>App Version<br/>Stack Trace"]
    
    J4 --> J5{Critical?}
    J5 -->|No| J6["↩️ Try to Recover<br/>Clear Cache<br/>Reset State<br/>Go to Dashboard"]
    J5 -->|Yes| J7["🛑 Force Close<br/>Show Crash Screen<br/>Contact Support"]
    
    J6 --> J8["✅ App Recovered"]
    
    K["🔔 Error Retry Mechanism"] --> K1["❌ Operation Failed"]
    
    K1 --> K2["⏳ Retry Strategy<br/>Exponential Backoff<br/>Max 5 Attempts"]
    
    K2 --> K3["⏱️ Retry Schedule<br/>Attempt 1: Immediate<br/>Attempt 2: 2s<br/>Attempt 3: 4s<br/>Attempt 4: 8s<br/>Attempt 5: 16s"]
    
    K3 --> K4{Attempt<br/>Limit<br/>Reached?}
    
    K4 -->|No| K5["🔄 Retry Operation"]
    K5 --> K6{Success?}
    K6 -->|Yes| K7["✅ Operation Complete"]
    K6 -->|No| K8["Increment Attempt<br/>Wait for Next Retry"]
    K8 --> K5
    K4 -->|Yes| K9["❌ Max Retries<br/>Show Error<br/>Move to Dead Letter Queue<br/>Manual Intervention"]
    
    style C fill:#FFD93D
    style D fill:#FF6B6B
    style E fill:#FF6B6B
    style F fill:#FFD93D
    style G fill:#FF6B6B
    style H fill:#FFD93D
    style I5 fill:#FF6B6B
    style J7 fill:#FF6B6B
    style K7 fill:#51CF66
    style K9 fill:#FF6B6B
```

---

## 13. NOTIFICATION SYSTEM

```mermaid
graph TD
    A["🔔 Notification System"] --> B{Notification<br/>Type?}
    
    B -->|Order Notifications| C["📦 Order Events"]
    B -->|Reservation Notifications| D["📅 Reservation Events"]
    B -->|Stock Notifications| E["📦 Stock Events"]
    B -->|System Notifications| F["⚙️ System Events"]
    
    C --> C1["🆕 New Order Created<br/>Kitchen Alerts<br/>Staff Notified"]
    C --> C2["🔄 Order Status Changed<br/>Pending→Preparing<br/>Preparing→Ready<br/>Ready→Completed<br/>Any→Cancelled"]
    C --> C3["💳 Payment Required<br/>Ready Order Waiting<br/>Payment Reminder"]
    
    C1 --> C1A["🔔 Create Notification<br/>Type: NewOrder<br/>Kitchen Display<br/>Alert Sound<br/>Vibration<br/>Badge +1"]
    
    C2 --> C2A["🔔 Create Notification<br/>Type: StatusChange<br/>Status-specific message<br/>Update KDS<br/>Notify Staff"]
    
    C3 --> C3A["🔔 Create Notification<br/>Type: PaymentDue<br/>Ready Order Alert<br/>Persistent Until Paid"]
    
    D --> D1["📅 Reservation Check-in<br/>30min before<br/>20min before<br/>15min before<br/>5min before<br/>Final Reminder"]
    
    D --> D2["📅 No-Show Alert<br/>Slot time passed<br/>Guest not seated<br/>Reservation expires"]
    
    D --> D3["📅 Reservation Cancelled<br/>Booking Cancelled<br/>Table Freed<br/>Guest Notified"]
    
    D1 --> D1A["🔔 Local Notification<br/>Scheduled<br/>Check-in time<br/>Configurable<br/>Repeating"]
    
    D2 --> D2A["🔔 Auto-Expiry Alert<br/>Automatic No-Show<br/>Reservation Expired<br/>Status Updated<br/>History Logged"]
    
    E --> E1["⚠️ Low Stock Alert<br/>Item Below Reorder<br/>Suggest Reorder<br/>Show Supplier"]
    
    E --> E2["🔴 Critical Stock Alert<br/>Item Nearly Empty<br/>Urgent Reorder<br/>Suggest Expedited"]
    
    E --> E3["❌ Out of Stock Alert<br/>Item Unavailable<br/>Mark in Menu<br/>Disable Orders"]
    
    E1 --> E1A["🔔 Create Notification<br/>Type: LowStock<br/>⚠️ Yellow Alert<br/>Action Required"]
    
    E2 --> E2A["🔔 Create Notification<br/>Type: CriticalStock<br/>🔴 Red Alert<br/>Urgent Action"]
    
    E3 --> E3A["🔔 Create Notification<br/>Type: OutOfStock<br/>❌ Gray Alert<br/>Update Menu<br/>Disable Orders"]
    
    F --> F1["🔄 Sync Status<br/>Sync Complete<br/>Sync Failed<br/>Sync Pending"]
    
    F --> F2["🔐 Login Notification<br/>New Device Login<br/>Security Alert<br/>Unusual Activity"]
    
    F --> F3["⚠️ Subscription Alert<br/>Expiring Soon<br/>Expired<br/>Renewal Required"]
    
    G["📱 Notification Delivery"] --> G1{Online<br/>Status?}
    
    G1 -->|Online| G2["📲 Send via<br/>Local Notifications<br/>Flutter Plugin<br/>Device Notification<br/>Sound + Vibration<br/>Heads-up Display"]
    
    G1 -->|Offline| G3["💾 Queue in Local<br/>Firebase Cloud<br/>Deliver When Online<br/>Badge Count"]
    
    G2 --> G4["📍 Notification<br/>Display Integration<br/>Top of Screen<br/>Badge Number<br/>Tap to Open<br/>Auto-dismiss"]
    
    G3 --> G5["🔔 Firebase<br/>Cloud Messaging<br/>Server-side Queue<br/>Reliable Delivery"]
    
    H["🎯 Notification Actions"] --> H1{Notification<br/>Tapped?}
    
    H1 -->|Order Notification| H2["🎯 Navigate to<br/>Orders Screen<br/>Show Order Details<br/>Highlight Order"]
    
    H1 -->|Reservation| H3["🎯 Navigate to<br/>Tables Screen<br/>Show Reservation<br/>Quick Actions"]
    
    H1 -->|Stock Alert| H4["🎯 Navigate to<br/>Inventory Screen<br/>Show Item<br/>Suggest Reorder"]
    
    H1 -->|System Alert| H5["🎯 Navigate to<br/>Relevant Screen<br/>Show Details<br/>Take Action"]
    
    I["⏰ Notification Timeline<br/>For Reservations"] --> I1["Reservation Created<br/>📅 Date/Time Set<br/>🔔 Enable All Alerts"]
    
    I --> I2["30min Before<br/>📬 Check-In Alert<br/>Prepare Table"]
    I --> I3["20min Before<br/>📬 Final Check<br/>Contingency Ready"]
    I --> I4["15min Before<br/>📬 Pre-arrival<br/>Staff Standby"]
    I --> I5["5min Before<br/>📬 Guest Arriving<br/>Final Notice"]
    I --> I6["Slot Time<br/>⏰ Reservation Active<br/>🔔 Seat Alert"]
    I --> I7["15min After Slot<br/>⚠️ Late Notice<br/>Wait or Auto-Expiry?"]
    I --> I8["30min After Slot<br/>🔴 Auto-Expiry<br/>Table Released<br/>Reservation Expired"]
    
    style C1A fill:#FFA500
    style C2A fill:#FFA500
    style C3A fill:#FFD93D
    style D1A fill:#FFD93D
    style D2A fill:#FF6B6B
    style E1A fill:#FFD93D
    style E2A fill:#FF6B6B
    style E3A fill:#FF6B6B
    style G4 fill:#51CF66
    style I8 fill:#FF6B6B
```

---

## 14. STATE MANAGEMENT & PROVIDER ARCHITECTURE

```mermaid
graph TD
    A["🎯 Provider-based<br/>State Management"] --> B["📦 MultiProvider Setup<br/>lib/providers/common_provider.dart"]
    
    B --> C["🔐 Core Services"]
    B --> D["📱 Screen Providers"]
    B --> E["🎨 Theme Provider"]
    
    C --> C1["ConnectivityService<br/>Singleton<br/>Monitors Network<br/>Emits Status Stream"]
    
    D --> D1["SplashProvider<br/>App Initialization<br/>Check Auth State<br/>Route Decision"]
    
    D --> D2["AppAuthenticationProvider<br/>Login/Signup<br/>Session Management<br/>User Data"]
    
    D --> D3["PageSwitcherProvider<br/>Navigation State<br/>Selected Tab Index<br/>Role-based Access<br/>Inventory Gate"]
    
    D --> D4["DashboardProvider<br/>KPI Metrics<br/>Revenue Data<br/>Charts<br/>Staff Performance"]
    
    D --> D5["OrdersProvider<br/>Fetch Orders<br/>Create Orders<br/>Update Status<br/>Payment Processing<br/>Realtime Sync"]
    
    D --> D6["TablesProvider<br/>Table Occupancy<br/>Reservations<br/>Session Management<br/>Calendar Data<br/>History Tracking"]
    
    D --> D7["MenuProvider<br/>Menu Items<br/>Categories<br/>Search/Filter<br/>Local Cache"]
    
    D --> D8["SupabaseMenuProvider<br/>Supabase Menu Sync<br/>Remote Menu Fetch<br/>Realtime Updates"]
    
    D --> D9["InventoryProvider<br/>Stock Management<br/>Item Operations<br/>Notifications<br/>Local Cache"]
    
    D --> D10["QrCodeProvider<br/>QR Generation<br/>Scan Processing<br/>Table Lookup"]
    
    D --> D11["AnalyticsProvider<br/>Revenue Analytics<br/>Charts Data<br/>Period Selection<br/>Role-gated"]
    
    D --> D12["ReportProvider<br/>Report Generation<br/>Date Range<br/>Export Options<br/>PDF/CSV"]
    
    D --> D13["EmployeeManagementProvider<br/>Employee List<br/>Role Assignment<br/>Performance Tracking"]
    
    D --> D14["ProfileProvider<br/>User Profile Data<br/>Settings<br/>Preferences<br/>Password Change"]
    
    D --> D15["CreateAccountProvider<br/>Signup Logic<br/>Phone OTP<br/>Email Verification"]
    
    D --> D16["OnboardingProvider<br/>First-time Setup<br/>Intro Screens"]
    
    D --> D17["NetworkSyncProvider<br/>Offline Sync Status<br/>Queue State<br/>Pending Count"]
    
    E --> E1["ThemeProvider<br/>Dark/Light Mode<br/>Theme Settings<br/>Local Persistence"]
    
    F["🔄 Realtime Listeners<br/>Supabase Channels"] --> F1["OrdersChannel<br/>Listen: orders<br/>Events: INSERT/UPDATE/DELETE<br/>Filters: business_id<br/>Triggers: notifyListeners()"]
    
    F --> F2["TablesChannel<br/>Listen: restaurant_tables<br/>Events: INSERT/UPDATE<br/>Status Changes<br/>Occupancy Updates"]
    
    F --> F3["ReservationsChannel<br/>Listen: table_reservations<br/>Events: INSERT/UPDATE<br/>New Bookings<br/>Cancellations"]
    
    F --> F4["MenuChannel<br/>Listen: menu_items<br/>Events: INSERT/UPDATE/DELETE<br/>Item Changes<br/>Availability Updates"]
    
    G["💾 Local State Caching"] --> G1["📦 Orders Cache<br/>In-memory List<br/>Session-filtered<br/>Auto-refresh"]
    
    G --> G2["📦 Tables Cache<br/>Section-organized<br/>Status-filtered<br/>Real-time updates"]
    
    G --> G3["📦 Menu Cache<br/>Categories + Items<br/>Offline support<br/>Search index"]
    
    G --> G4["📦 Inventory Cache<br/>Stock levels<br/>Filter states<br/>Sync metadata"]
    
    H["🔔 Notification Publishing<br/>Change Updates"] --> H1["Call notifyListeners()"]
    
    H1 --> H2["UI Rebuilds<br/>Consumer Widgets<br/>Watch Selected Data<br/>Triggered by<br/>Build Context"]
    
    H2 --> H3["Rebuild Flow<br/>Provider notified<br/>Consumer listens<br/>Widget rebuilds<br/>State reflected"]
    
    I["⚙️ Provider Lifecycle"] --> I1["Init (in constructor<br/>or initState)<br/>Fetch initial data<br/>Subscribe to realtime<br/>Load from cache"]
    
    I --> I2["Update (on user action<br/>or realtime event)<br/>Modify state<br/>notifyListeners()<br/>Queue sync if needed"]
    
    I --> I3["Dispose (on widget<br/>dispose)<br/>Cancel subscriptions<br/>Close channels<br/>Clear timers"]
    
    style A fill:#339AF0
    style B fill:#339AF0
    style C1 fill:#51CF66
    style F1 fill:#FFA500
    style G1 fill:#FFD93D
    style H3 fill:#51CF66
```

---

## 15. COMPLETE DATA FLOW DIAGRAM

```mermaid
graph TD
    A["👤 User Interaction<br/>Tap/Swipe/Input"] --> B["📱 Widget Layer<br/>Consumer<br/>StatelessWidget<br/>TextField<br/>Button"]
    
    B --> C["📢 Event Triggered<br/>onTap()<br/>onChanged()<br/>onSubmit()"]
    
    C --> D["🎯 Provider Method<br/>Create Order<br/>Update Stock<br/>Seat Guests<br/>etc"]
    
    D --> E{Online<br/>Status?}
    
    E -->|Online| E1["⬆️ Direct Remote Update<br/>POST/PATCH to Supabase<br/>Validate UUID<br/>Check Permissions<br/>Execute Query"]
    
    E -->|Offline| E2["💾 Local Save<br/>Insert to SQLite<br/>Add to Queue<br/>Mark as Pending"]
    
    E1 --> E3{Success?}
    E3 -->|Yes| E4["✅ Remote Success<br/>Update Local Cache<br/>Emit Realtime Event"]
    E3 -->|No| E5["❌ Remote Failed<br/>Log Error<br/>Fallback to Local<br/>Queue Sync"]
    
    E2 --> E6["✅ Local Saved<br/>Return Optimistic<br/>Result to UI<br/>Queue for Sync"]
    
    E4 --> F["🔄 Realtime Listener<br/>Supabase Channel<br/>Detects Change<br/>Emits Event"]
    E5 --> F
    E6 --> F
    
    F --> G["📊 State Update<br/>Provider Updates<br/>In-memory Cache<br/>Metadata"]
    
    G --> H["🔔 Notify Listeners<br/>notifyListeners() call<br/>Broadcast to UI<br/>Trigger Rebuilds"]
    
    H --> I["🎨 UI Rebuild<br/>Consumer<br/>Widgets Rebuilds<br/>New Data<br/>Display Updated"]
    
    J["📡 Sync Service<br/>When Online"] --> J1["🔄 Process Queue<br/>Get Pending Entries<br/>Validate Data<br/>Prepare Payload"]
    
    J1 --> J2["⬆️ Send to Supabase<br/>POST/PATCH/DELETE<br/>Wait for Response<br/>Retry on Error"]
    
    J2 --> J3{Status?}
    J3 -->|Success| J4["✅ Mark Synced<br/>Remove from Queue<br/>Update Sync Meta"]
    J3 -->|Failure| J5{Permanent<br/>or<br/>Temporary?}
    
    J5 -->|Permanent| J6["❌ Mark Failed<br/>Move to Dead Letter<br/>Alert User"]
    J5 -->|Temporary| J7["⏳ Requeue<br/>Exponential Backoff<br/>Retry Later"]
    
    K["🔙 Reverse Sync<br/>Periodic Pull"] --> K1["📋 Fetch Latest<br/>From Supabase<br/>By Updated_at<br/>Merge with Local"]
    
    K1 --> K2{Conflict?}
    K2 -->|Remote Newer| K3["⬇️ Update Local<br/>Replace Data<br/>Update Cache"]
    K2 -->|Local Newer| K4["📝 Keep Local<br/>Mark for Re-sync<br/>Update Timestamp"]
    
    K3 --> K5["✅ Merge Complete<br/>Cache Updated<br/>Notify UI"]
    K4 --> K5
    
    style A fill:#FF6B6B
    style E4 fill:#51CF66
    style E6 fill:#FFD93D
    style I fill:#51CF66
    style J4 fill:#51CF66
    style K5 fill:#51CF66
```

---

## Quick Reference: Module Features & Access

| Module | Owner | Manager | Admin | Staff | System | Role-Gated |
|--------|:-----:|:-------:|:-----:|:-----:|:------:|:----------:|
| **Dashboard** | ✅ | ✅ | ✅ | ❌ | ✅ | Yes |
| **Orders** | ✅ | ✅ | ✅ | ✅ | ✅ | No |
| **Tables/Reservations** | ✅ | ✅ | ✅ | ✅ | ✅ | No |
| **Menu** | ✅ | ✅ | ✅ | 👁️ | ✅ | Yes (Edit) |
| **Inventory** | ✅ | ✅ | ✅ | ❌ | ✅ | Yes |
| **Suppliers** | ✅ | ✅ | ✅ | ❌ | ✅ | Yes |
| **Analytics** | ✅ | ✅ | ✅ | ❌ | ✅ | Yes |
| **Reports** | ✅ | ✅ | ✅ | ❌ | ✅ | Yes |
| **Employees** | ✅ | ✅ | ❌ | ❌ | ✅ | Yes |
| **Settings** | ✅ | ❌ | ❌ | ❌ | ✅ | Yes |

**Legend:** ✅ Full Access | ❌ No Access | 👁️ View Only | ⚙️ Limited

---

## System Integrations & External Services

```mermaid
graph LR
    A["🚀 POS App"] -->|Auth| B["🔥 Firebase<br/>Authentication<br/>Google Sign-In<br/>Phone OTP"]
    
    A -->|Backend| C["🟢 Supabase<br/>PostgreSQL<br/>REST API<br/>Realtime"]
    
    A -->|Cloud Storage| D["☁️ Firebase Storage<br/>Images<br/>Documents<br/>Backups"]
    
    A -->|Notifications| E["🔔 FCM<br/>Push Notifications<br/>Remote Alerts<br/>Broadcast"]
    
    A -->|Offline Sync| F["💾 SQLite<br/>Local Data<br/>Queue System<br/>Offline Cache"]
    
    A -->|Payments| G["💳 Payment Gateway<br/>UPI/Card<br/>Cash Log<br/>Digital Wallets"]
    
    A -->|PDF/Print| H["🖨️ Print Services<br/>Bill Printing<br/>Receipt Generation<br/>Reports"]
    
    A -->|QR Code| I["📱 QR Scanner<br/>Table QR<br/>Item QR<br/>Order QR"]
    
    style B fill:#FF6B6B
    style C fill:#51CF66
    style D fill:#FF6B6B
    style E fill:#FFD93D
    style F fill:#339AF0
    style G fill:#51CF66
    style H fill:#FFA500
    style I fill:#339AF0
```

---

## Performance & Optimization Considerations

- **Offline-First Strategy**: All data operations first write to local SQLite, then sync to Supabase
- **Realtime Listeners**: Supabase channels monitor table changes for instant UI updates
- **Provider Caching**: In-memory caches reduce database queries and improve UI responsiveness
- **Pagination**: Large lists (orders, inventory, history) use pagination to reduce memory footprint
- **Image Optimization**: Firebase Storage handles image compression and CDN delivery
- **Session Management**: Table session IDs prevent order bleeding and ensure guest isolation
- **UUID Validation**: All IDs are validated before sync to prevent queue failures
- **Exponential Backoff**: Failed syncs retry with increasing delays to reduce server load
- **Dead Letter Queue**: Failed permanent operations are moved to separate queue for manual review

---

## Development & Deployment Workflow

1. **Local Development**: Use local Firebase emulator and Supabase dev database
2. **Testing**: Run unit/widget tests before commits
3. **CI/CD**: GitHub Actions trigger on pull requests for automated testing
4. **Staging**: Deploy to staging environment for QA testing
5. **Production**: Manual approval required for production deployment
6. **Monitoring**: Error tracking with Sentry, analytics with Firebase Analytics
7. **Rollback Plan**: Keep previous version tagged for quick rollback if needed

---

## Recommended Flowchart Generation & Documentation Tools

### 1. **Mermaid (Current Implementation)**
   - **Why**: Native markdown, version control friendly, no external dependencies
   - **Tools**: [Mermaid.js](https://mermaid.js.org), VS Code Mermaid Preview extension
   - **Usage**: Flowcharts, diagrams, state machines all in markdown

### 2. **Draw.io / Diagrams.net** (Detailed Design)
   - **Why**: Visual editing, professional appearance, export to multiple formats
   - **Usage**: Drag-drop interface design, detailed system architecture diagrams
   - **Export**: PNG, SVG, PDF for presentations

### 3. **Figma** (UI/UX Flows)
   - **Why**: Collaborative design, interactive prototypes, developer handoff
   - **Usage**: App screens, user flows, design system

### 4. **PlantUML** (Technical Documentation)
   - **Why**: Code-driven diagrams, sequence diagrams, component diagrams
   - **Usage**: API interactions, class relationships, deployment diagrams

### 5. **Lucidchart** (Enterprise Documentation)
   - **Why**: Cloud-based, real-time collaboration, extensive template library
   - **Usage**: Process flows, swimlane diagrams, organizational hierarchy

### Automation Scripts

**Generate README from Flowchart:**
```bash
# Use Mermaid CLI
npm install -g @mermaid-js/mermaid-cli
mmdc -i flowchart.md -o flowchart.png
```

**Export to Multiple Formats:**
```bash
# Convert Mermaid to various formats
mermaid --version
mermaid flowchart.md -o output.pdf
mermaid flowchart.md -o output.svg
mermaid flowchart.md -o output.png
```

---

## How to Use This Flowchart

1. **For Developers**: Reference specific sections for implementation details and decision points
2. **For Product Managers**: Use overview diagrams for stakeholder presentations
3. **For QA Teams**: Test scenarios can be derived from error handling and state management flows
4. **For Documentation**: Embed specific diagrams in technical documentation
5. **For Onboarding**: Share with new team members for system architecture understanding
6. **For Investors/Clients**: Use high-level diagrams (sections 1, 3, 4) for demonstrations

---

**Last Updated:** March 26, 2026  
**Version:** 1.0 - Complete  
**Status:** ✅ Production Ready
