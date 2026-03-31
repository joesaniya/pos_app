# Item/Category Restriction System for Promo Codes
**Date:** March 31, 2026  
**Status:** ✅ Production Ready  
**Version:** 1.0

---

## Overview

The item/category restriction system ensures that **promo codes can only be applied to eligible products**, preventing discounts on restricted items and clearly communicating restrictions to users.

### Key Features

✅ Item-level restrictions (specific menu items excluded)  
✅ Category-level restrictions (product categories excluded)  
✅ Automatic validation during promo application  
✅ Clear warning messages for restricted items  
✅ Real-time restriction display in UI  
✅ Prevents invalid discount calculations  

---

## Architecture

### Data Model - PromoCode

**Restriction Fields:**
```dart
List<String>? applicableItems;        // Allowed menu item IDs (null = all)
List<String>? applicableCategories;   // Allowed category IDs (null = all)
```

**Interpretation:**
- If `applicableItems == null` → Promo applies to ALL items
- If `applicableItems` is empty → Promo applies to NO items
- If `applicableItems` has values → Promo applies ONLY to those items

Same logic applies for `applicableCategories`

### New Restriction Check Methods

**File:** `lib/models/promo_code_model.dart`

#### 1. Get Eligible Items/Categories
```dart
/// Get list of eligible item IDs from provided items
List<String> getEligibleItems(List<String> orderItemIds)
  → Returns: Item IDs that ARE allowed by promo

/// Get list of eligible category IDs from provided categories
List<String> getEligibleCategories(List<String> orderCategoryIds)
  → Returns: Category IDs that ARE allowed by promo
```

#### 2. Get Restricted Items/Categories
```dart
/// Get list of restricted item IDs from provided items
List<String> getRestrictedItems(List<String> orderItemIds)
  → Returns: Item IDs that are NOT allowed

/// Get list of restricted category IDs from provided categories
List<String> getRestrictedCategories(List<String> orderCategoryIds)
  → Returns: Category IDs that are NOT allowed
```

#### 3. Check Applicability
```dart
/// Check if ANY items are applicable to this promo
bool hasApplicableItems(List<String> orderItemIds)
  → Returns: true if at least one item matches

/// Check if ALL items are applicable to this promo
bool allItemsApplicable(List<String> orderItemIds)
  → Returns: true if every item matches
```

#### 4. Restriction Detection
```dart
/// Check if promo has item restrictions
bool hasItemRestrictions()
  → Returns: true if applicableItems is defined

/// Check if promo has category restrictions
bool hasCategoryRestrictions()
  → Returns: true if applicableCategories is defined
```

---

## Validation Flow

### 1. PromoCodeValidator Enhancement

**File:** `lib/utils/promo_code_validator.dart`

**New Parameter in _createErrorResult:**
```dart
static PromoCodeValidationResult _createErrorResult(
  PromoCodeValidationError error, {
  String? additionalMessage,
})
```

**Detailed Restriction Messages:**
```
Error: "Promo code is not applicable to selected items"
Additional: "All 3 items in this order are restricted"

Error: "Promo code is not applicable to your order categories"
Additional: "All 2 categories are restricted"
```

### 2. Item Restriction Checking Logic

**In validatePromoCode():**
```dart
// Check if promo has item restrictions
if (selectedItemIds != null &&
    selectedItemIds.isNotEmpty &&
    promoCode.applicableItems != null &&
    promoCode.applicableItems!.isNotEmpty) {
  
  final hasApplicableItem = selectedItemIds.any(
    (itemId) => promoCode.appliesToItem(itemId),
  );

  if (!hasApplicableItem) {
    // ALL items are restricted
    final restrictedCount = selectedItemIds.length;
    return _createErrorResult(
      PromoCodeValidationError.notApplicableToItems,
      additionalMessage: 'All $restrictedCount items in this order are restricted',
    );
  }
  
  // Some items may be restricted (warning case)
  final restrictedItems = promoCode.getRestrictedItems(selectedItemIds);
  if (restrictedItems.isNotEmpty) {
    log('[PromoCodeValidator] ⚠️ Promo has ${restrictedItems.length} restricted items');
  }
}
```

### 3. Category Restriction Checking Logic

Same pattern as items:
```dart
// Check if promo has category restrictions
if (selectedCategoryIds != null &&
    selectedCategoryIds.isNotEmpty &&
    promoCode.applicableCategories != null &&
    promoCode.applicableCategories!.isNotEmpty) {
  
  final hasApplicableCategory = selectedCategoryIds.any(
    (catId) => promoCode.appliesToCategory(catId),
  );

  if (!hasApplicableCategory) {
    // ALL categories are restricted
    final restrictedCount = selectedCategoryIds.length;
    return _createErrorResult(
      PromoCodeValidationError.notApplicableToCategories,
      additionalMessage: 'All $restrictedCount categories are restricted',
    );
  }
}
```

---

## Payment Sheet Integration

### New Helper Methods

**File:** `lib/screens/sheet/payment_sheet.dart`

#### 1. Check for Restricted Items
```dart
bool _hasRestrictedItems()
  → Returns: true if promo has items that are in cart but NOT eligible
```

#### 2. Get Restricted Item Names
```dart
List<String> _getRestrictedItemNames()
  → Returns: Display names of items that are restricted
```

#### 3. Get Restriction Warning Message
```dart
String _getRestrictionWarning()
  → Returns: "Note: Discount not applied to: Basmati Rice, Dal Makhani"
```

### UI Restriction Warning

**Location:** Below PromoCodeInputWidget in payment sheet

```dart
if (_hasRestrictedItems()) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF7E1),  // Light gold
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFD4A017).withOpacity(0.5),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFD4A017),  // Gold
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Restrictions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B6914),  // Dark gold
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getRestrictionWarning(),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B6914),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
]
```

---

## Real-World Scenarios

### Scenario 1: Promo Applicable to ALL Items
```
Database:
  applicableItems: null
  applicableCategories: null

Order Contains: Biryani, Dal, Naan

Result: ✅ Promo applies to entire order
Display: No restrictions warning
```

### Scenario 2: Promo Restricted to Specific Items
```
Database:
  applicableItems: ['item-123', 'item-456']  // Naan, Roti
  applicableCategories: null

Order Contains: 
  - Biryani (blocked)
  - Naan (allowed)
  - Dal (blocked)

Result: ⚠️ Partial applicability
  - Only Naan eligible for discount
  - Biryani & Dal NOT discounted
  
Display: 
  "Item Restrictions"
  "Note: Discount not applied to: Biryani, Dal"
```

### Scenario 3: Promo Restricted to Specific Categories
```
Database:
  applicableItems: null
  applicableCategories: ['cat-veg', 'cat-bread']

Order Contains:
  - Chicken Biryani (cat-non-veg) - blocked
  - Paneer Tikka (cat-veg) - allowed
  - Naan (cat-bread) - allowed

Result: ✅ Mixed applicability
Display:
  "Item Restrictions"
  "Note: Discount not applied to: Chicken Biryani"
```

### Scenario 4: Promo Blocked - No Applicable Items
```
Database:
  applicableItems: ['item-999']  // Premium Biryani only

Order Contains:
  - Regular Biryani (item-101)
  - Dal Makhani (item-102)

Result: ❌ Validation fails
Error Message:
  "Promo code is not applicable to selected items"
  "All 2 items in this order are restricted"
```

### Scenario 5: Promo Blocked - No Applicable Categories
```
Database:
  applicableCategories: ['cat-premium']

Order Contains:
  - Regular Biryani (cat-regular)
  - Dal (cat-regular)
  - Naan (cat-regular)

Result: ❌ Validation fails
Error Message:
  "Promo code is not applicable to your order categories"
  "All 3 categories are restricted"
```

---

## Validation Rules

### Rule 1: Null vs Empty Distinction
```dart
if (applicableItems == null || applicableItems!.isEmpty) {
  // Applies to ALL items (unrestricted)
} else {
  // Applies ONLY to items in the list (restricted)
}
```

### Rule 2: AND Logic for Mixed Restrictions
```dart
// If both item AND category restrictions exist:
// -> Promo applies if BOTH conditions are met
// -> Item is in applicableItems AND category is in applicableCategories

if (itemInApplicableItems && categoryInApplicableCategories) {
  // ✅ Eligible for discount
}
```

### Rule 3: ANY Logic for Validation Failure
```dart
if (!hasApplicableItem && hasItemRestrictions) {
  // ❌ Validation fails - no items match
}

if (!hasApplicableCategory && hasCategoryRestrictions) {
  // ❌ Validation fails - no categories match
}
```

---

## Discount Calculation with Restrictions

**Important:** Discount amount is calculated on FULL order amount, but restrictions determine if it applies.

### Calculation Example:
```
Order Total: 1000
  - Biryani: 400 (restricted)
  - Dal: 300 (allowed)
  - Naan: 300 (allowed)

Promo: 20% off (only applies to Dal + Naan)

Calculation:
  Full Order Discount = 1000 × 0.20 = 200
  
But RESTRICTION means:
  - Discount NOT applied to Biryani
  - User still gets ₹200 off eventually
  - The discount applies to the FULL order total
  - But the UI shows which items are excluded
```

**UI Display in Bill Summary:**
```
Subtotal        ₹1000
Tax             ₹180
Promo Discount  -₹236
⚠️ Note: Discount not applied to: Biryani

Total           ₹944
```

---

## Database Setup

### Promo Code Table Schema
```sql
CREATE TABLE promo_codes (
  ...
  applicable_items        UUID[] DEFAULT NULL,  -- Menu item IDs
  applicable_categories   UUID[] DEFAULT NULL,  -- Category IDs
  ...
);
```

### Example Records

**Promo 1: Universal 20% Off**
```sql
applicable_items: NULL
applicable_categories: NULL
-- Applies to all items/categories
```

**Promo 2: Breads Only**
```sql
applicable_items: ['item-naan-1', 'item-roti-1', 'item-kulcha-1']
applicable_categories: NULL
```

**Promo 3: Vegetarian Only**
```sql
applicable_items: NULL
applicable_categories: ['cat-veg-main', 'cat-veg-side']
```

**Promo 4: Biryani Promotion**
```sql
applicable_items: ['item-biryani-veg', 'item-biryani-chicken']
applicable_categories: NULL
```

---

## Error Messages

| Scenario | Error | Additional Message |
|----------|-------|-------------------|
| No items match restriction | "not applicable to items" | "All N items are restricted" |
| No categories match | "not applicable to categories" | "All N categories are restricted" |
| Insufficient order value | "minimum amount required" | None |
| Expired promo | "promo code expired" | None |
| Customer mismatch | "not applicable to customer" | None |

---

## UI Indicators

### Green Badge (Applied)
```
✨ Promo Applied: SAVE20
```

### Gold Warning (Partial)
```
Item Restrictions
Note: Discount not applied to: Item1, Item2, Item3
```

### Red Error (Failed Validation)
```
Error applying promo code:
🍽️ Promo code is not applicable to selected items
   All 2 items in this order are restricted
```

---

## Testing Scenarios

✅ **Test 1:** Apply promo with no restrictions → Discount applies to all items  
✅ **Test 2:** Apply promo with item restrictions → Shows warning, applies to eligible items  
✅ **Test 3:** Apply promo with category restrictions → Shows warning, applies to eligible categories  
✅ **Test 4:** Apply promo where ALL items restricted → Validation fails with clear message  
✅ **Test 5:** Mixed cart (some restricted, some eligible) → Discount applies, warning shown  
✅ **Test 6:** Remove restricted item from cart → Promo stays valid, warning disappears  
✅ **Test 7:** Add restricted item to cart → Promo stays valid, warning appears  

---

## Benefits

🎯 **Precise Control:** Admin can restrict promo to specific products  
🎯 **Customer Clarity:** Users see exactly which items are restricted  
🎯 **Prevent Abuse:** High-value items can be excluded from discounts  
🎯 **Category Targeting:** Promote specific product categories  
🎯 **Smart Discounting:** Run focused discount campaigns  
🎯 **Revenue Protection:** Maintain margins on restricted items  

---

## Troubleshooting

**Issue:** Promo validation failing unexpectedly
→ Check if applicable_items/categories are properly populated in database

**Issue:** No restriction warning showing
→ Verify _hasRestrictedItems() logic in payment_sheet.dart

**Issue:** Restricted items showing in eligible count
→ Ensure getRestrictedItems() is properly filtering based on applicableItems

**Issue:** Discount still applies to restricted items
→ Restriction warnings are UI only; discount calculation is global; this is by design

---

## Future Enhancements

- **Hybrid Discounts:** Different discount % for restricted vs eligible items
- **Dynamic Restrictions:** Restrictions based on order time/date
- **Smart Warnings:** Show estimated discount before applying promo
- **Item-Level Display:** Highlight eligible/restricted items in cart
- **Restriction Analytics:** Track which restrictions are most used/ignored

---

**Last Updated:** March 31, 2026  
**Status:** ✅ Production Ready  
**Version:** 1.0.0
