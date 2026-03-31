<!-- PROMO CODE & DISCOUNT MANAGEMENT - IMPLEMENTATION GUIDE
     Complete guide for integrating the promo code system into the POS app
     Date: March 31, 2026
-->

# 🎟️ PROMO CODE & DISCOUNT MANAGEMENT SYSTEM
## Complete Implementation Guide for POS App

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Database Schema](#database-schema)
3. [Model Layer](#model-layer)
4. [Repository Layer](#repository-layer)
5. [Provider Layer](#provider-layer)
6. [Service Layer](#service-layer)
7. [UI Components](#ui-components)
8. [Payment Sheet Integration](#payment-sheet-integration)
9. [Admin Management Screen](#admin-management-screen)
10. [Role-Based Access Control](#role-based-access-control)
11. [Validation Logic](#validation-logic)
12. [Testing Guide](#testing-guide)
13. [Deployment Steps](#deployment-steps)

---

## 🎯 SYSTEM OVERVIEW

### Feature Set
✅ Create and manage promo codes (Admin/Manager/Owner only)
✅ Percentage-based and fixed-amount discounts
✅ Minimum order value requirements
✅ Time-based validity periods
✅ Company-specific promo codes
✅ Customer-specific promo codes
✅ Real-time validation and application in checkout
✅ Promo code usage tracking
✅ Expired code automatic deactivation

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Database Schema** | Promo codes table & functions | `PROMO_CODE_SCHEMA_2026_03_31.sql` |
| **Model** | Promo code data class | `lib/models/promo_code_model.dart` |
| **Repository** | DB access layer | `lib/repositories/promo_code_repository.dart` |
| **Provider** | State management | `lib/providers/promo_code_provider.dart` |
| **Service** | Business logic | `lib/services/promo_code_service.dart` |
| **Validator** | Validation logic | `lib/utils/promo_code_validator.dart` |
| **Input Widget** | Promo code input | `lib/widgets/promo_code_input_widget.dart` |
| **Management Screen** | Admin UI | `lib/screens/promo_code_management_screen.dart` |

---

## 💾 DATABASE SCHEMA

### Tables Created

#### 1. `promo_codes` Table
Stores all promo code configurations
```sql
CREATE TABLE public.promo_codes (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  code TEXT NOT NULL,
  discount_type TEXT NOT NULL,  -- 'percentage' | 'fixed'
  discount_value NUMERIC NOT NULL,
  min_order_value NUMERIC DEFAULT 0,
  start_date TIMESTAMPTZ NOT NULL,
  expiry_date TIMESTAMPTZ NOT NULL,
  applicable_items JSONB DEFAULT NULL,
  applicable_categories JSONB DEFAULT NULL,
  customer_id TEXT DEFAULT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(business_id, code)
);
```

#### 2. `promo_code_usage` Table
Tracks promo code usage on orders
```sql
CREATE TABLE public.promo_code_usage (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  promo_code_id TEXT NOT NULL REFERENCES promo_codes(id),
  order_id TEXT NOT NULL REFERENCES orders(id),
  customer_id TEXT DEFAULT NULL,
  discount_amount NUMERIC NOT NULL,
  used_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Database Functions

#### `fn_validate_promo_code()`
Validates promo code against all requirements
```sql
-- Usage in validation flow
SELECT * FROM fn_validate_promo_code(
  p_code => 'SAVE20',
  p_business_id => 'biz-123',
  p_customer_id => 'cust-456',
  p_order_amount => 1500
);
```

#### `fn_calculate_discount_amount()`
Calculates actual discount based on type and value
```sql
-- Usage for amount calculation
SELECT fn_calculate_discount_amount(
  p_discount_type => 'percentage',
  p_discount_value => 20,
  p_order_amount => 1000
);  -- Returns: 200
```

### Deployment SQL
Execute in Supabase SQL Editor:
```bash
-- Run PROMO_CODE_SCHEMA_2026_03_31.sql
```

---

## 📦 MODEL LAYER

### PromoCode Class
Location: `lib/models/promo_code_model.dart`

**Key Fields:**
```dart
class PromoCode {
  final String id;
  final String businessId;
  final String code;                    // Unique code per business
  final DiscountType discountType;      // percentage | fixed
  final double discountValue;           // 20 or 100 (depending on type)
  final double minOrderValue;           // Minimum order ₹
  final DateTime startDate;             // Validity start
  final DateTime expiryDate;            // Validity end
  final List<String>? applicableItems;  // Menu item IDs
  final List<String>? applicableCategories; // Category IDs
  final String? customerId;             // Customer-specific
  final bool isActive;                  // Active/Inactive status
  // ... more fields
}
```

**Key Methods:**
```dart
// Validity checks
bool get isValid                    // Check if currently valid
bool appliesToItem(String itemId)   // Check item eligibility
bool appliesToCategory(String cat)  // Check category eligibility
bool isCustomerSpecific(String cid) // Check customer match

// Discount calculation
double calculateDiscount(double amount) // Calculate discount amount
bool meetsMinimumOrderValue(amount)  // Check min order requirement

// Display
String get displayText              // "20% off" or "₹100 off"
String get validityMessage          // User-friendly message
```

---

## 🗄️ REPOSITORY LAYER

### PromoCodeRepository Class
Location: `lib/repositories/promo_code_repository.dart`

**Singleton Pattern:**
```dart
final repo = PromoCodeRepository.instance;
```

**Main Methods:**

```dart
// Create
Future<PromoCode> createPromoCode({...}) -> PromoCode

// Read
Future<PromoCode?> getPromoCode(String id)
Future<PromoCode?> getPromoCodeByCode(String code, String businessId)
Future<List<PromoCode>> listPromoCodesByBusiness(String businessId)

// Update
Future<PromoCode?> updatePromoCode(String id, Map updates)
Future<bool> togglePromoCodeStatus(String id, bool isActive)

// Delete
Future<bool> deletePromoCode(String id)

// Validation
Future<PromoCodeValidationResult> validatePromoCode({
  required String code,
  required String businessId,
  String? customerId,
  double orderAmount
}) -> PromoCodeValidationResult

// Discount calculation
Future<double> calculateDiscountAmount({
  required String discountType,
  required double discountValue,
  required double orderAmount
}) -> double

// Usage tracking
Future<bool> recordPromoCodeUsage({
  required String businessId,
  required String promoCodeId,
  required String orderId,
  String? customerId,
  double discountAmount
})

// Batch operations
Future<int> deactivateExpiredPromoCodes(String businessId)
```

---

## 🏗️ PROVIDER LAYER

### PromoCodeProvider Class
Location: `lib/providers/promo_code_provider.dart`

**Usage in UI:**
```dart
// Read provider
final provider = context.read<PromoCodeProvider>();

// Watch provider
final provider = context.watch<PromoCodeProvider>();

// Listen to changes
context.listen<PromoCodeProvider>(
  (provider) => // React to changes
);
```

**Main Methods:**

```dart
// Data loading
Future<void> loadPromoCodesByBusiness(String businessId)
Future<void> loadPromoCode(String promoCodeId)

// CRUD operations
Future<PromoCode?> createPromoCode({...})
Future<bool> updatePromoCode(String id, Map updates)
Future<bool> togglePromoCodeStatus(String id, bool isActive)
Future<bool> deletePromoCode(String id)

// Validation
Future<PromoCodeValidationResult> validatePromoCode({...})

// Search & filter
List<PromoCode> filterBySearchTerm(String term)
List<PromoCode> filterByDiscountType(DiscountType type)
List<PromoCode> getCustomerSpecificPromoCodes(String customerId)

// State management
void selectPromoCode(PromoCode?)
void clearError()
void reset()
```

**State Variables:**
```dart
List<PromoCode> promoCodes           // All promo codes
PromoCode? selectedPromoCode         // Currently selected
bool isLoading                       // Loading state
String? error                        // Error message
List<PromoCode> activePromoCodes     // Getter for active only
```

---

## 🔧 SERVICE LAYER

### PromoCodeService Class
Location: `lib/services/promo_code_service.dart`

**Main Purpose:** Business logic and orchestration

**Key Methods:**

```dart
// Apply promo code with full validation
Future<PromoApplicationResult> applyPromoCode({
  required String promoCodeString,
  required String businessId,
  String? customerId,
  double orderAmount,
  List<String> selectedItemIds,
  List<String>? selectedCategoryIds
}) -> PromoApplicationResult

// Apply multiple discounts (promo + regular)
Future<double> applyMultipleDiscounts({
  required String? promoCodeString,
  required double regularDiscountAmount,
  required String businessId,
  // ... other params
}) -> double

// Record usage after payment
Future<bool> recordPromoUsageAfterPayment({
  required String businessId,
  required String promoCodeId,
  required String orderId,
  String? customerId,
  double discountAmount
})

// Validation only
Future<bool> isPromoCodeValid({
  required String promoCodeString,
  required String businessId,
  // ... other params
}) -> bool
```

**Result Class:**
```dart
class PromoApplicationResult {
  final bool success;
  final PromoCode? promoCode;
  final double discountAmount;
  final String? errorMessage;
  final String? warningMessage;
}
```

---

## 🎨 UI COMPONENTS

### 1. PromoCodeInputWidget
Location: `lib/widgets/promo_code_input_widget.dart`

**Usage in Payment Sheet:**
```dart
PromoCodeInputWidget(
  businessId: order.businessId,
  customerId: currentCustomerId,
  orderAmount: _grandTotal,
  selectedItemIds: order.items.map((i) => i.id).toList(),
  selectedCategoryIds: order.items.map((i) => i.categoryId).toList(),
  onPromoApplied: (promoCode, discountAmount) {
    setState(() {
      _appliedPromoCode = promoCode;
      _promoDiscountAmount = discountAmount;
    });
  },
  onPromoRemoved: () {
    setState(() {
      _appliedPromoCode = null;
      _promoDiscountAmount = 0;
    });
  },
  onErrorChanged: (error) {
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  },
)
```

### 2. PromoCodeSummaryWidget
Location: `lib/widgets/promo_code_input_widget.dart`

**Usage in Bill Display:**
```dart
PromoCodeSummaryWidget(
  promoCode: appliedPromoCode,
  discountAmount: promoDiscountAmount,
  showDetails: true,
)
```

---

## 💳 PAYMENT SHEET INTEGRATION

### Integration Steps

#### Step 1: Add State Variables
```dart
class _PaymentSheetState extends State<PaymentSheet> {
  PromoCode? _appliedPromoCode;
  double _promoDiscountAmount = 0;
  
  // Existing variables...
  final _discountCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();
}
```

#### Step 2: Update Discount Calculation
```dart
// OLD - Simple manual discount
double get _discountAmount => double.tryParse(_discountCtrl.text) ?? 0;

// NEW - Include both promo and manual discount
double get _totalDiscountAmount {
  const manualDiscount = double.tryParse(_discountCtrl.text) ?? 0;
  // Use whichever is higher (promo or manual)
  return _promoDiscountAmount > manualDiscount
      ? _promoDiscountAmount
      : manualDiscount;
}

double get _grandTotal =>
    widget.order.subtotal +
    widget.order.taxAmount +
    _tipAmount -
    _totalDiscountAmount;  // Use combined discount
```

#### Step 3: Add PromoCodeInputWidget
```dart
// In build() method, add before tip/discount fields:
const SizedBox(height: 18),
PromoCodeInputWidget(
  businessId: widget.order.businessId,
  customerId: widget.order.customerId,
  orderAmount: widget.order.subtotal + widget.order.taxAmount,
  selectedItemIds: widget.order.items.map((i) => i.id).toList(),
  selectedCategoryIds: widget.order.items.map((i) => i.categoryId).toList(),
  onPromoApplied: (promoCode, discountAmount) {
    setState(() {
      _appliedPromoCode = promoCode;
      _promoDiscountAmount = discountAmount;
    });
  },
  onPromoRemoved: () {
    setState(() {
      _appliedPromoCode = null;
      _promoDiscountAmount = 0;
    });
  },
),
```

#### Step 4: Update Payment Confirmation
```dart
Future<void> _confirmPayment() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final prov = context.read<OrdersProvider>();
    
    // Apply combined discount
    final totalDiscount = _totalDiscountAmount;
    
    final updated = await prov.confirmPayment(
      orderId: widget.order.id,
      mode: _mode,
      paymentRef: _refCtrl.text.trim(),
      tipAmount: _tipAmount,
      discountAmount: totalDiscount,
      promoCodeId: _appliedPromoCode?.id,  // NEW: Add promo code ID
    );

    // Record promo usage if applied
    if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
      final service = PromoCodeService.instance;
      await service.recordPromoUsageAfterPayment(
        businessId: widget.order.businessId,
        promoCodeId: _appliedPromoCode!.id,
        orderId: widget.order.id,
        customerId: widget.order.customerId,
        discountAmount: _promoDiscountAmount,
      );
    }

    // Rest of confirmation logic...
  }
}
```

#### Step 5: Update Bill Summary Display
```dart
// In _BillSummaryCard, add after regular discount line:
if (_appliedPromoCode != null) ...[
  const SizedBox(height: 6),
  PromoCodeSummaryWidget(
    promoCode: _appliedPromoCode,
    discountAmount: _promoDiscountAmount,
    showDetails: true,
  ),
]
```

---

## 👨‍💼 ADMIN MANAGEMENT SCREEN

### Access Control
Only Admin, Manager, Owner roles can access

### Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PromoCodeManagementScreen(
      businessId: businessId,
      userId: currentUserId,
      userRole: currentUserRole,
    ),
  ),
);
```

### Features
✅ List all promo codes
✅ Create new promo codes
✅ Edit existing promo codes
✅ Delete promo codes
✅ Toggle active/inactive status
✅ Filter by active/expired
✅ View promo details

---

## 🔐 ROLE-BASED ACCESS CONTROL

### Permission Matrix

| Role | Create | Edit | Delete | View | Manage Status |
|------|--------|------|--------|------|---------------|
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manager | ✅ | ✅ | ✅ | ✅ | ✅ |
| Owner | ✅ | ✅ | ✅ | ✅ | ✅ |
| Staff | ❌ | ❌ | ❌ | ✅ | ❌ |
| Customer | ❌ | ❌ | ❌ | ❌ | ❌ |

### Implementation in Supabase RLS

Database policies restrict access:
```sql
-- Only Admin/Manager/Owner can manage promo codes
CREATE POLICY promo_codes_manage_policy
  ON public.promo_codes FOR ALL
  USING (
    business_id IN (
      SELECT business_id FROM public.profiles
      WHERE uid = auth.uid()
        AND role IN ('admin', 'manager', 'owner')
    )
  );

-- All authenticated users can read (for validation during checkout)
CREATE POLICY promo_codes_read_policy
  ON public.promo_codes FOR SELECT
  USING (TRUE);
```

---

## ✅ VALIDATION LOGIC

### Validation Flow

```
User enters promo code
         ↓
PromoCodeService.applyPromoCode()
         ↓
[Check 1] Promo code exists? → NO → Error: "Not found"
         ↓ YES
[Check 2] Business matches? → NO → Error: "Invalid for this business"
         ↓ YES
[Check 3] Is active? → NO → Error: "Inactive"
         ↓ YES
[Check 4] Within validity dates? → NO → Error: "Expired"
         ↓ YES
[Check 5] Order meets minimum? → NO → Error: "Min order not met"
         ↓ YES
[Check 6] Customer eligible? → NO → Error: "Not available for you"
         ↓ YES
[Check 7] Items applicable? → NO → Error: "Not applicable to items"
         ↓ YES
[Check 8] Categories applicable? → NO → Error: "Not applicable"
         ↓ YES
Calculate discount amount
         ↓
Return PromoApplicationResult(success: true)
         ↓
Display in UI
```

### Validator Utility
Location: `lib/utils/promo_code_validator.dart`

```dart
// Single validation
bool isValid = PromoCodeValidator.validatePromoCode(
  promoCode: promo,
  businessId: businessId,
  customerId: customerId,
  orderAmount: amount,
);

// Get all errors
List<PromoCodeValidationError> errors = 
    PromoCodeValidator.checkAllValidationErrors(...);

// Calculate discount
double discount = DiscountCalculator.calculateDiscount(
  discountType: DiscountType.percentage,
  discountValue: 20,
  orderAmount: 1000,  // Returns: 200
);
```

---

## 🧪 TESTING GUIDE

### Unit Tests

```dart
void main() {
  group('PromoCode Tests', () {
    test('calculateDiscount - Percentage', () {
      final promo = PromoCode(
        // ... initialize with percentage discount
        discountType: DiscountType.percentage,
        discountValue: 20,
      );
      
      final discount = promo.calculateDiscount(1000);
      expect(discount, 200);
    });

    test('calculateDiscount - Fixed', () {
      final promo = PromoCode(
        discountType: DiscountType.fixed,
        discountValue: 100,
      );
      
      final discount = promo.calculateDiscount(1000);
      expect(discount, 100);
    });

    test('isValid - Expired promo', () {
      final promo = PromoCode(
        // ... initialize with past dates
        startDate: DateTime(2020, 1, 1),
        expiryDate: DateTime(2020, 12, 31),
      );
      
      expect(promo.isValid, false);
    });
  });
}
```

### Integration Tests

1. **Create Promo Code**
   - Admin creates promo code
   - Verify created in database
   - Verify visible in list

2. **Apply Promo Code**
   - Create order
   - Apply valid promo code
   - Verify discount applied
   - Verify payment reduced

3. **Validation Tests**
   - Test expired code rejection
   - Test customer-specific validation
   - Test minimum order requirement
   - Test item applicability

4. **Usage Tracking**
   - Apply promo code to order
   - Complete payment
   - Verify usage recorded

---

## 🚀 DEPLOYMENT STEPS

### Pre-Deployment Checklist

- [ ] Database schema deployed (run SQL file)
- [ ] All models created
- [ ] Repository implemented
- [ ] Provider implemented
- [ ] Validation logic tested
- [ ] UI widgets created
- [ ] Payment sheet integrated
- [ ] Admin screen accessible
- [ ] RLS policies enforced
- [ ] Role-based access verified

### Step 1: Database Setup
```bash
# In Supabase SQL Editor, execute:
# PROMO_CODE_SCHEMA_2026_03_31.sql
```

### Step 2: Provider Registration
Add to `main.dart` or provider setup:
```dart
ChangeNotifierProvider(
  create: (_) => PromoCodeProvider(),
),
```

### Step 3: Navigation Integration
Add route to promo management screen:
```dart
routes: {
  '/promo-codes': (context) => PromoCodeManagementScreen(...),
},
```

### Step 4: Testing
- Test promo code creation
- Test promo code application
- Test validation logic
- Test expiration handling
- Test role-based access

### Step 5: Deployment
```bash
flutter clean
flutter pub get
flutter build apk/ios
```

### Step 6: Post-Deployment
- Monitor error logs
- Test in staging environment
- Verify RLS policies working
- Monitor performance metrics
- Collect user feedback

---

## 🐛 TROUBLESHOOTING

### Issue: Promo code not applying
**Solution:** 
- Check if promo code exists in database
- Verify business_id matches
- Check validity dates
- Verify customer eligibility
- Check item/category applicability

### Issue: Permission denied
**Solution:**
- Verify user role in profiles table
- Check RLS policies enabled
- Verify user is authenticated
- Check business_id in user profile

### Issue: Discount not showing in bill
**Solution:**
- Check if discount amount is > 0
- Verify grand total calculation includes discount
- Check if _totalDiscountAmount is used instead of _discountAmount
- Verify state update triggers UI rebuild

### Issue: Expired codes not deactivated
**Solution:**
- Run deactivateExpiredPromoCodes batch function
- Schedule as background job
- Monitor expiry_date field
- Check is_active flag in database

---

## 📞 SUPPORT & DOCUMENTATION

### Key Files Reference
- **Schema:** `PROMO_CODE_SCHEMA_2026_03_31.sql`
- **Model:** `lib/models/promo_code_model.dart`
- **Repository:** `lib/repositories/promo_code_repository.dart`
- **Provider:** `lib/providers/promo_code_provider.dart`
- **Service:** `lib/services/promo_code_service.dart`
- **Utils:** `lib/utils/promo_code_validator.dart`
- **Widgets:** `lib/widgets/promo_code_input_widget.dart`
- **Screens:** `lib/screens/promo_code_management_screen.dart`

### Version History
- **v1.0** - Initial implementation (2026-03-31)
  - Complete promo code system
  - Admin management screen
  - Real-time validation
  - Usage tracking

---

## ✨ FUTURE ENHANCEMENTS

- [ ] Loyalty points system integration
- [ ] Bulk promo code creation
- [ ] Promo code analytics dashboard
- [ ] Customer targeting by purchase history
- [ ] Seasonal promo code templates
- [ ] SMS/Email promo code notifications
- [ ] Referral code system
- [ ] Integration with inventory system

---

**Last Updated:** March 31, 2026
**Status:** Production Ready ✅
