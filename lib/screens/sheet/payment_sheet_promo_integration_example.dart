// lib/screens/sheet/payment_sheet_promo_integration_example.dart
// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT SHEET WITH PROMO CODE INTEGRATION - EXAMPLE
// This file shows how to modify the existing payment_sheet.dart to include
// promo code functionality. Use this as a guide for integration.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/models/promo_code_model.dart'; // NEW IMPORT
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/screens/orders_bill_preview_screen.dart';
import 'package:pos_app/services/promo_code_service.dart'; // NEW IMPORT
import 'package:pos_app/widgets/promo_code_input_widget.dart'; // NEW IMPORT
import 'package:provider/provider.dart';
import 'package:pos_app/providers/qr_code_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PAYMENT SHEET WITH PROMO CODE SUPPORT
// ══════════════════════════════════════════════════════════════════════════════

class PaymentSheetWithPromoSupport extends StatefulWidget {
  final Order order;

  const PaymentSheetWithPromoSupport({super.key, required this.order});

  @override
  State<PaymentSheetWithPromoSupport> createState() =>
      _PaymentSheetWithPromoSupportState();
}

class _PaymentSheetWithPromoSupportState
    extends State<PaymentSheetWithPromoSupport>
    with TickerProviderStateMixin {
  OrderPaymentMode _mode = OrderPaymentMode.cash;
  final _refCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _promoCodeCtrl = TextEditingController(); // NEW: Promo code input

  bool _loading = false;
  String? _error;

  // ═══════════════════════════════════════════════════════════════════════════
  //  NEW: PROMO CODE STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════

  PromoCode? _appliedPromoCode;
  double _promoDiscountAmount = 0;

  late AnimationController _successAnim;

  // Computed
  double get _tipAmount => double.tryParse(_tipCtrl.text) ?? 0;

  // OLD: Simple manual discount
  // double get _discountAmount => double.tryParse(_discountCtrl.text) ?? 0;

  // NEW: Combined discount (promo + manual)
  double get _manualDiscountAmount => double.tryParse(_discountCtrl.text) ?? 0;

  double get _totalDiscountAmount {
    // Use promo discount if available, otherwise use manual discount
    if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
      return _promoDiscountAmount;
    }
    return _manualDiscountAmount;
  }

  double get _grandTotal =>
      widget.order.subtotal +
      widget.order.taxAmount +
      _tipAmount -
      _totalDiscountAmount; // Use combined discount

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrCodeProvider>().fetchQrUrl(widget.order.businessId);
    });
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _tipCtrl.dispose();
    _discountCtrl.dispose();
    _promoCodeCtrl.dispose(); // NEW: Dispose promo controller
    _successAnim.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NEW: PROMO CODE CALLBACK HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onPromoCodeApplied(PromoCode? promoCode, double discountAmount) {
    setState(() {
      _appliedPromoCode = promoCode;
      _promoDiscountAmount = discountAmount;
      // Clear manual discount if promo is applied
      if (promoCode != null) {
        _discountCtrl.clear();
      }
    });
  }

  void _onPromoCodeRemoved() {
    setState(() {
      _appliedPromoCode = null;
      _promoDiscountAmount = 0;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CONFIRM PAYMENT - UPDATED
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmPayment() async {
    if (_mode.requiresRef && _refCtrl.text.trim().isEmpty) {
      setState(
        () => _error = '${_mode.label} requires a transaction reference.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prov = context.read<OrdersProvider>();

      // NEW: Use combined discount amount
      final totalDiscount = _totalDiscountAmount;

      final updated = await prov.confirmPayment(
        orderId: widget.order.id,
        mode: _mode,
        paymentRef: _refCtrl.text.trim(),
        tipAmount: _tipAmount,
        discountAmount: totalDiscount,
      );

      // NEW: Record promo code usage if applied
      if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
        final service = PromoCodeService.instance;
        await service.recordPromoUsageAfterPayment(
          businessId: widget.order.businessId,
          promoCodeId: _appliedPromoCode!.id,
          orderId: widget.order.id,
          customerId: widget.order.customerPhone ?? 'guest',
          discountAmount: _promoDiscountAmount,
        );
      }

      if (!mounted) return;

      // Show success state briefly
      setState(() {
        _loading = false;
      });
      _successAnim.forward();

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      // Close sheet and navigate to bill
      Navigator.pop(context);
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => BillPreviewScreen(order: updated),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final order = widget.order;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Main content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8F3DC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('💰', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collect Payment',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Bill Summary ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Subtotal'),
                            const Spacer(),
                            Text('₹${order.subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        if (order.taxAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Tax'),
                              const Spacer(),
                              Text('₹${order.taxAmount.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ═══════════════════════════════════════════════
                  //  NEW: PROMO CODE INPUT SECTION
                  // ═══════════════════════════════════════════════
                  PromoCodeInputWidget(
                    businessId: widget.order.businessId,
                    customerId: widget.order.customerPhone ?? 'guest',
                    orderAmount:
                        widget.order.subtotal +
                        widget.order.taxAmount, // For validation
                    selectedItemIds: widget.order.items
                        .map((item) => item.id)
                        .toList(),
                    selectedCategoryIds: widget.order.items
                        .map((item) => item.menuItemId)
                        .toList(),
                    controller: _promoCodeCtrl,
                    onPromoApplied: _onPromoCodeApplied,
                    onPromoRemoved: _onPromoCodeRemoved,
                  ),

                  const SizedBox(height: 18),

                  // ── Tip & Manual Discount (Only if no promo) ────
                  if (_appliedPromoCode == null)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tipCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Tip (₹)',
                                  hintText: '0',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.card_giftcard),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _discountCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Discount (₹)',
                                  hintText: '0',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.local_offer),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),

                  // ── Grand Total ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Grand Total',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${_grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Payment Mode ────────────────────────────────
                  const Text(
                    'Payment Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: OrderPaymentMode.values.map((m) {
                      final isSel = _mode == m;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mode = m;
                          _refCtrl.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF1B4332)
                                : const Color(0xFFF2F3F8),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFF1B4332)
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${m.emoji} ${m.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Error message ──────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDC2626)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFA00515)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Confirm Payment Button ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Confirm Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  INTEGRATION NOTES FOR EXISTING PAYMENT_SHEET.DART
//  ═════════════════════════════════════════════════════════════════════════════

/*
STEPS TO INTEGRATE PROMO CODE INTO EXISTING payment_sheet.dart:

1. ADD IMPORTS:
   import 'package:pos_app/models/promo_code_model.dart';
   import 'package:pos_app/services/promo_code_service.dart';
   import 'package:pos_app/widgets/promo_code_input_widget.dart';

2. ADD STATE VARIABLES:
   PromoCode? _appliedPromoCode;
   double _promoDiscountAmount = 0;
   final _promoCodeCtrl = TextEditingController();

3. UPDATE DISCOUNT CALCULATION:
   // Keep the _manualDiscountAmount getter
   double get _manualDiscountAmount => double.tryParse(_discountCtrl.text) ?? 0;
   
   // Add new _totalDiscountAmount getter
   double get _totalDiscountAmount {
     if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
       return _promoDiscountAmount;
     }
     return _manualDiscountAmount;
   }
   
   // Update _grandTotal to use _totalDiscountAmount instead of _discountAmount

4. ADD CALLBACK METHODS:
   void _onPromoCodeApplied(PromoCode? promoCode, double discountAmount) {
     setState(() {
       _appliedPromoCode = promoCode;
       _promoDiscountAmount = discountAmount;
       if (promoCode != null) _discountCtrl.clear();
     });
   }

   void _onPromoCodeRemoved() {
     setState(() {
       _appliedPromoCode = null;
       _promoDiscountAmount = 0;
     });
   }

5. ADD WIDGET TO BUILD:
   PromoCodeInputWidget(
     businessId: widget.order.businessId,
     customerId: widget.order.customerId,
     orderAmount: widget.order.subtotal + widget.order.taxAmount,
     selectedItemIds: widget.order.items.map((i) => i.id).toList(),
     selectedCategoryIds: widget.order.items.map((i) => i.categoryId).toList(),
     onPromoApplied: _onPromoCodeApplied,
     onPromoRemoved: _onPromoCodeRemoved,
   )

6. UPDATE CONFIRM PAYMENT:
   // Use _totalDiscountAmount instead of _discountAmount
   final updated = await prov.confirmPayment(
     orderId: widget.order.id,
     mode: _mode,
     paymentRef: _refCtrl.text.trim(),
     tipAmount: _tipAmount,
     discountAmount: _totalDiscountAmount,  // ← CHANGED
   );
   
   // Add promo usage recording
   if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
     final service = PromoCodeService.instance;
     await service.recordPromoUsageAfterPayment(...);
   }

7. DISPOSE:
   @override
   void dispose() {
     _promoCodeCtrl.dispose();
     // ... rest of disposal
   }
*/
