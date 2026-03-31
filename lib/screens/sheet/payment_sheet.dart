// lib/screens/orders/payment_sheet.dart
// ══════════════════════════════════════════════════════════════
//  PAYMENT COLLECTION SHEET
//  Called when order status is 'ready' and staff taps "Collect Payment"
//  On success → order auto-completes via DB trigger
//  On success → navigates to BillPreviewScreen
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/order_modal.dart';
import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/screens/orders_bill_preview_screen.dart';
import 'package:pos_app/services/promo_code_service.dart';
import 'package:pos_app/widgets/promo_code_input_widget.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/qr_code_provider.dart';
import 'package:pos_app/widgets/payment_qr_code_display.dart';

// ── Design tokens ─────────────────────────────────────────────
class PC {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F3F8);
  static const border = Color(0xFFE8EAF2);
  static const primary = Color(0xFF1B4332);
  static const primaryLight = Color(0xFFD8F3DC);
  static const accent = Color(0xFF40916C);
  static const gold = Color(0xFFD4A017);
  static const goldLight = Color(0xFFFFF8E1);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEF2F2);
  static const textPri = Color(0xFF0F172A);
  static const textSec = Color(0xFF64748B);
  static const textMute = Color(0xFFABB8CC);
  static const divider = Color(0xFFEEF1F7);
}

// ══════════════════════════════════════════════════════════════
class PaymentSheet extends StatefulWidget {
  final Order order;

  const PaymentSheet({Key? key, required this.order}) : super(key: key);

  static Future<void> show(BuildContext context, Order order) {
    final qrProv = context.read<QrCodeProvider>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<OrdersProvider>()),
          ChangeNotifierProvider.value(value: qrProv),
        ],
        child: PaymentSheet(order: order),
      ),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet>
    with TickerProviderStateMixin {
  OrderPaymentMode _mode = OrderPaymentMode.cash;
  final _refCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _promoCodeCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  // ═══════════════════════════════════════════════════════════
  //  PROMO CODE STATE
  // ═══════════════════════════════════════════════════════════
  PromoCode? _appliedPromoCode;
  double _promoDiscountAmount = 0;

  late AnimationController _successAnim;
  bool _showSuccess = false;

  // Computed
  double get _tipAmount => double.tryParse(_tipCtrl.text) ?? 0;

  /// Get discountable amount (subtotal + tax for full order applicability)
  double get _discountableAmount =>
      widget.order.subtotal + widget.order.taxAmount;

  /// Calculate manual discount amount with validation
  /// Supports both fixed and percentage-based discounts
  double get _manualDiscountAmount {
    final input = _discountCtrl.text.trim();
    if (input.isEmpty) return 0;

    final parsed = double.tryParse(input) ?? 0;
    if (parsed <= 0) return 0;

    // Detect if it's a percentage (assume input > 100 or ends with % would be percentage)
    // For now, treat all manual input as fixed amount
    // Promo codes handle percentage calculation via PromoCodeService
    return parsed.clamp(0, _discountableAmount);
  }

  /// Calculate effective discount amount
  /// Priority: Promo discount (if applicable) > Manual discount
  /// Always validates against discountable amount to prevent over-discounting
  double get _totalDiscountAmount {
    // Promo takes priority when applied
    if (_appliedPromoCode != null && _promoDiscountAmount > 0) {
      return _promoDiscountAmount.clamp(0, _discountableAmount);
    }
    // Fall back to manual discount
    return _manualDiscountAmount;
  }

  /// Calculate the base amount before any discounts (includes tax)
  double get _baseAmount => widget.order.subtotal + widget.order.taxAmount;

  /// Calculate the amount after discount but before tip
  double get _discountedAmount => _baseAmount - _totalDiscountAmount;

  /// Final payable amount: base - discount + tip
  double get _grandTotal => _baseAmount + _tipAmount - _totalDiscountAmount;

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
    _promoCodeCtrl.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  PROMO CODE CALLBACK HANDLERS
  // ═══════════════════════════════════════════════════════════

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

  /// Calculate discount percentage for display
  /// Returns 0 if discount type is not percentage-based
  double _getDiscountPercentage() {
    if (_appliedPromoCode != null &&
        _appliedPromoCode!.discountType == 'percentage' &&
        _baseAmount > 0) {
      return (_promoDiscountAmount / _baseAmount * 100).clamp(0, 100);
    }
    return 0;
  }

  /// Validate discount doesn't exceed discountable amount
  bool _isDiscountValid() {
    return _totalDiscountAmount <= _discountableAmount &&
        _totalDiscountAmount >= 0;
  }

  /// Get discount summary for display
  String _getDiscountSummary() {
    if (_appliedPromoCode == null) {
      return 'No promo applied';
    }
    final percentage = _getDiscountPercentage();
    if (percentage > 0) {
      return '${_appliedPromoCode!.code} • ${percentage.toStringAsFixed(0)}% off';
    }
    return '${_appliedPromoCode!.code} • ₹${_promoDiscountAmount.toStringAsFixed(2)} off';
  }

  /// Check if current order has restricted items for applied promo
  bool _hasRestrictedItems() {
    if (_appliedPromoCode == null) return false;
    if (_appliedPromoCode!.applicableItems == null ||
        _appliedPromoCode!.applicableItems!.isEmpty) {
      return false; // No restrictions
    }
    final orderItemIds = widget.order.items.map((item) => item.id).toList();
    final restrictedItems = _appliedPromoCode!.getRestrictedItems(orderItemIds);
    return restrictedItems.isNotEmpty;
  }

  /// Get list of restricted items
  List<String> _getRestrictedItemNames() {
    if (_appliedPromoCode == null) return [];
    if (_appliedPromoCode!.applicableItems == null ||
        _appliedPromoCode!.applicableItems!.isEmpty) {
      return [];
    }
    final orderItemIds = widget.order.items.map((item) => item.id).toList();
    final restrictedIds = _appliedPromoCode!.getRestrictedItems(orderItemIds);
    return widget.order.items
        .where((item) => restrictedIds.contains(item.id))
        .map((item) => item.itemName)
        .toList();
  }

  /// Get formatted restriction warning message
  String _getRestrictionWarning() {
    final restrictedNames = _getRestrictedItemNames();
    if (restrictedNames.isEmpty) return '';
    return 'Note: Discount not applied to: ${restrictedNames.join(", ")}';
  }

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
      final updated = await prov.confirmPayment(
        orderId: widget.order.id,
        mode: _mode,
        paymentRef: _refCtrl.text.trim(),
        tipAmount: _tipAmount,
        discountAmount: _totalDiscountAmount,
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
        _showSuccess = true;
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
        color: PC.surface,
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
              color: PC.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Success overlay
          if (_showSuccess)
            _SuccessState(animation: _successAnim, amount: _grandTotal)
          else
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
                            color: PC.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '💰',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Collect Payment',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: PC.textPri,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                [
                                  'Order #${order.orderNumber}',
                                  if (order.billNumber != null &&
                                      order.billNumber!.isNotEmpty)
                                    order.billNumber!,
                                  if (order.tableNumber != null)
                                    'Table ${order.tableNumber}'
                                        '${order.seatLabel != null ? " • ${order.seatLabel}" : ""}',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PC.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Bill Summary ────────────────────────────────
                    _BillSummaryCard(
                      order: order,
                      tipAmount: _tipAmount,
                      discountAmount: _manualDiscountAmount,
                      grandTotal: _grandTotal,
                      appliedPromoCode: _appliedPromoCode,
                      promoDiscountAmount: _promoDiscountAmount,
                    ),

                    const SizedBox(height: 18),

                    // ═══════════════════════════════════════════════
                    //  PROMO CODE INPUT SECTION
                    // ═══════════════════════════════════════════════
                    PromoCodeInputWidget(
                      businessId: widget.order.businessId,
                      customerId: widget.order.customerPhone ?? 'guest',
                      orderAmount:
                          widget.order.subtotal + widget.order.taxAmount,
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

                    const SizedBox(height: 12),

                    // ═══════════════════════════════════════════════
                    //  RESTRICTION WARNING (if promo has restricted items)
                    // ═══════════════════════════════════════════════
                    if (_hasRestrictedItems()) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF7E1),
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
                              color: Color(0xFFD4A017),
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
                                      color: Color(0xFF8B6914),
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
                      const SizedBox(height: 12),
                    ],

                    // ── Tip & Discount (Only if no promo) ────
                    if (_appliedPromoCode == null)
                      Row(
                        children: [
                          Expanded(
                            child: _AmountField(
                              label: 'Tip (₹)',
                              hint: '0',
                              ctrl: _tipCtrl,
                              emoji: '🙏',
                              color: PC.gold,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AmountField(
                              label: 'Discount (₹)',
                              hint: '0',
                              ctrl: _discountCtrl,
                              emoji: '🏷️',
                              color: PC.accent,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      )
                    else
                      // Show tip only when promo is applied
                      _AmountField(
                        label: 'Tip (₹)',
                        hint: '0',
                        ctrl: _tipCtrl,
                        emoji: '🙏',
                        color: PC.gold,
                        onChanged: (_) => setState(() {}),
                      ),

                    const SizedBox(height: 18),

                    // ── Grand Total ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [PC.primary, Color(0xFF2D6A4F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: PC.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                    const _Label('Payment Mode'),
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? PC.primary : PC.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? PC.primary : PC.border,
                                width: isSel ? 2 : 1,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: PC.primary.withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : PC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // ── Transaction ref ─────────────────────────────
                    if (_mode != OrderPaymentMode.cash &&
                        _mode != OrderPaymentMode.complimentary) ...[
                      const SizedBox(height: 14),
                      _Label(
                        '${_mode.label} Reference${_mode.requiresRef ? " *" : " (optional)"}',
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _refCtrl,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PC.textPri,
                        ),
                        decoration: _inputDec(_mode.refHint),
                      ),
                    ],

                    // ── QR Code Section ─────────────────────────────
                    if (_mode == OrderPaymentMode.upi)
                      Consumer<QrCodeProvider>(
                        builder: (context, qrProv, child) {
                          // Check if UPI ID is available
                          if (!qrProv.hasUpiId) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: PC.danger.withValues(alpha: 77),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_rounded,
                                      color: PC.danger,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'UPI ID not configured in business profile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: PC.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Display payment QR code (clean QR image only)
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: PaymentQrCodeDisplay(
                              orderId: widget.order.id,
                              upiId: qrProv.upiId,
                              payeeName: widget.order.businessId,
                              orderAmount: _grandTotal,
                              orderDescription:
                                  'Order #${widget.order.tableNumber}',
                            ),
                          );
                        },
                      ),

                    // ── Error ───────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PC.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PC.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: PC.danger,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PC.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // ── Confirm button ──────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _confirmPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PC.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Confirm ₹${_grandTotal.toStringAsFixed(0)} Payment',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
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

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: PC.textMute, fontSize: 13),
    filled: true,
    fillColor: PC.surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PC.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PC.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PC.primary, width: 1.5),
    ),
  );
}

// ── Success state ─────────────────────────────────────────────
class _SuccessState extends StatelessWidget {
  final AnimationController animation;
  final double amount;

  const _SuccessState({required this.animation, required this.amount});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final scale = Curves.elasticOut.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          child: Column(
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: PC.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('✅', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Confirmed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: PC.textPri,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${amount.toStringAsFixed(2)} received',
                style: const TextStyle(fontSize: 16, color: PC.textSec),
              ),
              const SizedBox(height: 8),
              const Text(
                'Opening bill...',
                style: TextStyle(fontSize: 13, color: PC.textMute),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Bill summary card ─────────────────────────────────────────
class _BillSummaryCard extends StatelessWidget {
  final Order order;
  final double tipAmount;
  final double discountAmount;
  final double grandTotal;
  final PromoCode? appliedPromoCode;
  final double promoDiscountAmount;

  const _BillSummaryCard({
    required this.order,
    required this.tipAmount,
    required this.discountAmount,
    required this.grandTotal,
    this.appliedPromoCode,
    this.promoDiscountAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PC.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Promo code badge (if applied)
          if (appliedPromoCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD8F3DC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF40916C)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    'Promo Applied: ${appliedPromoCode!.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Table / seat info row (if applicable)
          if (order.tableNumber != null) ...[
            _Row(
              '${order.orderType.emoji} ${order.orderType.label}',
              [
                'Table ${order.tableNumber}',
                if (order.seatLabel != null) order.seatLabel!,
              ].join(' • '),
              false,
              color: const Color(0xFF5A3FD6),
            ),
            const SizedBox(height: 10),
          ],

          // ── Ordered Items List ───────────────────────────────
          if (order.items.isNotEmpty) ...[
            Row(
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'ORDERED ITEMS (${order.totalItems})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PC.textSec,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => _ItemLine(item: item)),
            const Divider(height: 14, color: PC.divider),
          ],

          // ── Financial Summary ────────────────────────────────
          _Row(
            'Subtotal (${order.totalItems} items)',
            '₹${order.subtotal.toStringAsFixed(2)}',
            false,
          ),
          const SizedBox(height: 6),
          /*  _Row(
            'Tax (${order.taxRate.toInt()}%)',
            '₹${order.taxAmount.toStringAsFixed(2)}',
            false,
          ),*/
          _Row('Tax ', '₹${order.taxAmount.toStringAsFixed(2)}', false),
          // Discount row with type indication
          if (promoDiscountAmount > 0) ...[
            const SizedBox(height: 6),
            _Row(
              'Promo Discount (${appliedPromoCode!.code})',
              '- ₹${promoDiscountAmount.toStringAsFixed(2)}',
              false,
              color: const Color(0xFF40916C),
              discountType: appliedPromoCode!.discountType
                  .toString()
                  .split('.')
                  .last,
            ),
          ] else if (discountAmount > 0) ...[
            const SizedBox(height: 6),
            _Row(
              'Manual Discount',
              '- ₹${discountAmount.toStringAsFixed(2)}',
              false,
              color: const Color(0xFF059669),
              discountType: 'fixed',
            ),
          ] else ...[
            const SizedBox(height: 6),
            _Row('Discount', '- ₹0.00', false, color: const Color(0xFF95A3B3)),
          ],
          if (tipAmount > 0) ...[
            const SizedBox(height: 6),
            _Row(
              'Tip',
              '+ ₹${tipAmount.toStringAsFixed(2)}',
              false,
              color: PC.gold,
            ),
          ],
          const Divider(height: 14, color: PC.divider),
          _Row('Total', '₹${grandTotal.toStringAsFixed(2)}', true),
        ],
      ),
    );
  }
}

// ── Single item line in payment sheet ────────────────────────
class _ItemLine extends StatelessWidget {
  final OrderItem item;
  const _ItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final vegColor = item.isVeg
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB71C1C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Veg/Non-veg indicator dot
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                border: Border.all(color: vegColor, width: 1.2),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: vegColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.itemName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PC.textPri,
              ),
            ),
          ),
          Text(
            '×${item.quantity}',
            style: const TextStyle(
              fontSize: 12,
              color: PC.textSec,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 65,
            child: Text(
              '₹${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PC.textPri,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final String? discountType;

  const _Row(
    this.label,
    this.value,
    this.bold, {
    this.color,
    this.discountType,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? PC.textPri : PC.textSec,
              ),
            ),
            // Show discount type indicator
            if (discountType != null && discountType!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                discountType == 'percentage'
                    ? '(Percentage-based)'
                    : '(Fixed amount)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: (color ?? PC.textSec).withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          color: color ?? (bold ? PC.textPri : PC.textSec),
        ),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: PC.textSec,
      letterSpacing: 0.3,
    ),
  );
}

class _AmountField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final String emoji;
  final Color color;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.emoji,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PC.textSec,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: PC.textMute, fontSize: 14),
            prefixText: '₹ ',
            prefixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            filled: true,
            fillColor: color.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
