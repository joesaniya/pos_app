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
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/screens/orders_bill_preview_screen.dart';
import 'package:provider/provider.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OrdersProvider>(),
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

  bool _loading = false;
  String? _error;

  late AnimationController _successAnim;
  bool _showSuccess = false;

  // Computed
  double get _tipAmount => double.tryParse(_tipCtrl.text) ?? 0;
  double get _discountAmount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _grandTotal =>
      widget.order.subtotal +
      widget.order.taxAmount +
      _tipAmount -
      _discountAmount;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _tipCtrl.dispose();
    _discountCtrl.dispose();
    _successAnim.dispose();
    super.dispose();
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
        discountAmount: _discountAmount,
      );

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
                                  if (order.billNumber != null && order.billNumber!.isNotEmpty)
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
                      discountAmount: _discountAmount,
                      grandTotal: _grandTotal,
                    ),

                    const SizedBox(height: 18),

                    // ── Tip & Discount ──────────────────────────────
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

  const _BillSummaryCard({
    required this.order,
    required this.tipAmount,
    required this.discountAmount,
    required this.grandTotal,
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
        children: [
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
            const SizedBox(height: 6),
          ],
          _Row(
            'Subtotal (${order.totalItems} items)',
            '₹${order.subtotal.toStringAsFixed(2)}',
            false,
          ),
          const SizedBox(height: 6),
          _Row(
            'Tax (${order.taxRate.toInt()}%)',
            '₹${order.taxAmount.toStringAsFixed(2)}',
            false,
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 6),
            _Row(
              'Discount',
              '- ₹${discountAmount.toStringAsFixed(2)}',
              false,
              color: const Color(0xFF059669),
            ),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _Row(this.label, this.value, this.bold, {this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: bold ? 14 : 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: bold ? PC.textPri : PC.textSec,
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
