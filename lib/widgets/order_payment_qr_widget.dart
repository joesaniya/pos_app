import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pos_app/services/payment_qr_service.dart';

/// Widget to display dynamic payment QR code for orders
/// Displays QR code with locked amount, order details, and expiration timer
class OrderPaymentQrWidget extends StatefulWidget {
  final String orderId;
  final String upiId;
  final String payeeName;
  final double orderAmount;
  final String orderDescription;
  final VoidCallback? onRefresh;
  final Function(bool isExpired)? onExpirationChange;

  const OrderPaymentQrWidget({
    super.key,
    required this.orderId,
    required this.upiId,
    required this.payeeName,
    required this.orderAmount,
    required this.orderDescription,
    this.onRefresh,
    this.onExpirationChange,
  });

  @override
  State<OrderPaymentQrWidget> createState() => _OrderPaymentQrWidgetState();
}

class _OrderPaymentQrWidgetState extends State<OrderPaymentQrWidget> {
  late String _upiString;
  late Timer _expirationTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _generatePaymentQr();
    _startExpirationTimer();
  }

  @override
  void dispose() {
    _expirationTimer.cancel();
    super.dispose();
  }

  void _generatePaymentQr() {
    try {
      _upiString = PaymentQrService.generatePaymentUpiString(
        upiId: widget.upiId,
        payeeName: widget.payeeName,
        amount: widget.orderAmount,
        orderId: widget.orderId,
        orderDescription: widget.orderDescription,
      );

      _secondsRemaining = 3600; // 1 hour in seconds
    } catch (e) {
      debugPrint('Error generating payment QR: $e');
    }
  }

  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          widget.onExpirationChange?.call(true);
        }
      });
    });
  }

  String _formatTimeRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _handleRefresh() {
    _expirationTimer.cancel();
    _generatePaymentQr();
    _startExpirationTimer();
    widget.onRefresh?.call();
    setState(() {});
  }

  bool get _isExpired => _secondsRemaining <= 0;
  bool get _isExpiringSoon => _secondsRemaining <= 300; // 5 minutes

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1847C4);
    const Color warningColor = Color(0xFFD97706);
    const Color dangerColor = Color(0xFFE11D48);
    const Color successColor = Color(0xFF0EA472);

    if (_isExpired) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dangerColor.withValues(alpha: 20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dangerColor.withValues(alpha: 77)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: dangerColor, size: 48),
            const SizedBox(height: 12),
            Text(
              'QR Code Expired',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dangerColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please refresh to generate a new payment QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: dangerColor.withValues(alpha: 204),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Generate New QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Order Details Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 51)),
          ),
          child: Column(
            children: [
              Text(
                'Order #${widget.orderId}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8C9AB8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PaymentQrService.formatAmount(widget.orderAmount),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.orderDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF3A4A6B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // QR Code - UPI String Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: 51),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 26),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'UPI Payment String',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withValues(alpha: 26)),
                ),
                child: SelectableText(
                  _upiString,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Color(0xFF0D1B3E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment string ready to share'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expiration Timer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isExpiringSoon
                ? warningColor.withValues(alpha: 20)
                : successColor.withValues(alpha: 20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isExpiringSoon
                  ? warningColor.withValues(alpha: 77)
                  : successColor.withValues(alpha: 77),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: _isExpiringSoon ? warningColor : successColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Expires in ${_formatTimeRemaining(_secondsRemaining)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  // color: _isExpiringSoon ? warningColor : successColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Amount Lock Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor.withValues(alpha: 51)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Amount locked to ${PaymentQrService.formatAmount(widget.orderAmount)} - Cannot be modified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Refresh Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFF4F7FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Instructions:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionItem(
                '1',
                'Open any UPI app (Google Pay, PhonePe, PayTM, etc.)',
              ),
              _buildInstructionItem('2', 'Tap "Scan QR Code"'),
              _buildInstructionItem(
                '3',
                'Amount will auto-populate - ${PaymentQrService.formatAmount(widget.orderAmount)}',
              ),
              _buildInstructionItem('4', 'Verify amount and complete payment'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1847C4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3A4A6B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
