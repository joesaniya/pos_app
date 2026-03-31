// lib/widgets/promo_code_input_widget.dart
// Reusable widget for promo code input and display in payment flow

import 'package:flutter/material.dart';
import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/services/promo_code_service.dart';
import 'package:pos_app/utils/promo_code_validator.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE INPUT CALLBACK
// ══════════════════════════════════════════════════════════════

typedef PromoCodeCallback =
    void Function(PromoCode? promoCode, double discountAmount);

// ══════════════════════════════════════════════════════════════
//  PROMO CODE INPUT WIDGET
// ══════════════════════════════════════════════════════════════

class PromoCodeInputWidget extends StatefulWidget {
  final String businessId;
  final String? customerId;
  final double orderAmount;
  final List<String>? selectedItemIds;
  final List<String>? selectedCategoryIds;
  final TextEditingController? controller;
  final PromoCodeCallback onPromoApplied;
  final VoidCallback? onPromoRemoved;
  final ValueChanged<String?>? onErrorChanged;
  final bool enabled;

  const PromoCodeInputWidget({
    Key? key,
    required this.businessId,
    this.customerId,
    required this.orderAmount,
    this.selectedItemIds,
    this.selectedCategoryIds,
    this.controller,
    required this.onPromoApplied,
    this.onPromoRemoved,
    this.onErrorChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<PromoCodeInputWidget> createState() => _PromoCodeInputWidgetState();
}

class _PromoCodeInputWidgetState extends State<PromoCodeInputWidget> {
  late TextEditingController _controller;
  PromoCode? _appliedPromoCode;
  double _appliedDiscount = 0;
  String? _error;
  bool _isValidating = false;
  bool _showApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onPromoCodeChanged);
  }

  void _onPromoCodeChanged() {
    _showApplied = false;
    setState(() {});
  }

  Future<void> _applyPromoCode() async {
    final code = _controller.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _error = 'Please enter a promo code');
      widget.onErrorChanged?.call(_error);
      return;
    }

    setState(() {
      _isValidating = true;
      _error = null;
    });
    widget.onErrorChanged?.call(null);

    try {
      final service = PromoCodeService.instance;
      final result = await service.applyPromoCode(
        promoCodeString: code,
        businessId: widget.businessId,
        customerId: widget.customerId,
        orderAmount: widget.orderAmount,
        selectedItemIds: widget.selectedItemIds ?? [],
        selectedCategoryIds: widget.selectedCategoryIds,
      );

      if (!mounted) return;

      if (result.success && result.promoCode != null) {
        // ✅ Promo code applied successfully
        setState(() {
          _appliedPromoCode = result.promoCode;
          _appliedDiscount = result.discountAmount;
          _showApplied = true;
          _error = null;
          _isValidating = false;
        });

        // Notify parent widget
        widget.onPromoApplied(_appliedPromoCode, _appliedDiscount);
        widget.onErrorChanged?.call(null);

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Promo code "${code}" applied! Discount: ₹${_appliedDiscount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // ❌ Validation failed
        setState(() {
          _error = result.errorMessage ?? 'Invalid promo code';
          _isValidating = false;
        });
        widget.onErrorChanged?.call(_error);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isValidating = false;
        });
        widget.onErrorChanged?.call(_error);
      }
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromoCode = null;
      _appliedDiscount = 0;
      _showApplied = false;
      _error = null;
      _controller.clear();
    });
    widget.onPromoApplied(null, 0);
    widget.onPromoRemoved?.call();
    widget.onErrorChanged?.call(null);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ Input field
        if (!_showApplied)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controller,
                enabled: widget.enabled && !_isValidating,
                decoration: InputDecoration(
                  labelText: 'Promo Code',
                  hintText: 'Enter promo code (e.g., SAVE20)',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixIcon: _isValidating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _error = null);
                          },
                        )
                      : null,
                  errorText: _error,
                  errorMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _applyPromoCode(),
                onChanged: (_) {
                  setState(() => _error = null);
                  widget.onErrorChanged?.call(null);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      widget.enabled &&
                          !_isValidating &&
                          _controller.text.isNotEmpty
                      ? _applyPromoCode
                      : null,
                  child: _isValidating
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
                      : const Text('Apply Promo Code'),
                ),
              ),
            ],
          )
        else
          // ─ Applied promo code display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promo Applied: ${_appliedPromoCode?.code}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Discount: ₹${_appliedDiscount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.green),
                      onPressed: _removePromoCode,
                      tooltip: 'Remove promo code',
                    ),
                  ],
                ),
                if (_appliedPromoCode?.customerId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '👤 Customer-specific coupon',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE SUMMARY WIDGET (For bill display)
// ══════════════════════════════════════════════════════════════

class PromoCodeSummaryWidget extends StatelessWidget {
  final PromoCode? promoCode;
  final double discountAmount;
  final bool showDetails;

  const PromoCodeSummaryWidget({
    Key? key,
    required this.promoCode,
    required this.discountAmount,
    this.showDetails = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (promoCode == null || discountAmount <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '🎟️ Promo (${promoCode!.code})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '- ₹${discountAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
        if (showDetails) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Type: ${promoCode!.discountType.label}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (promoCode!.minOrderValue > 0) ...[
                const Spacer(),
                Text(
                  'Min: ₹${promoCode!.minOrderValue}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
