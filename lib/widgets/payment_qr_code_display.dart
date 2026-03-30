import 'package:flutter/material.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pos_app/services/payment_qr_service.dart';

/// Simplified widget to display ONLY the QR code image
/// No text or UPI string visible to users
class PaymentQrCodeDisplay extends StatefulWidget {
  final String orderId;
  final String upiId;
  final String payeeName;
  final double orderAmount;
  final String orderDescription;

  const PaymentQrCodeDisplay({
    super.key,
    required this.orderId,
    required this.upiId,
    required this.payeeName,
    required this.orderAmount,
    required this.orderDescription,
  });

  @override
  State<PaymentQrCodeDisplay> createState() => _PaymentQrCodeDisplayState();
}

class _PaymentQrCodeDisplayState extends State<PaymentQrCodeDisplay> {
  late String _upiString;
  late Timer _expirationTimer;
  int _secondsRemaining = 3600; // 1 hour

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
        }
      });
    });
  }

  String _formatTimeRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1B4332);
    const Color warningColor = Color(0xFFD97706);
    const Color successColor = Color(0xFF0EA472);

    if (_secondsRemaining <= 0) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDC2626).withValues(alpha: 77),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR Code Expired. Please refresh payment.',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _generatePaymentQr();
                  _expirationTimer.cancel();
                  _secondsRemaining = 3600;
                  _startExpirationTimer();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh Payment QR'),
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
        ],
      );
    }

    return Column(
      children: [
        /*// Amount display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Order #${widget.orderId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PaymentQrService.formatAmount(widget.orderAmount),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),*/

        // QR Code Image - Dynamically rendered
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(data: _upiString),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Timer
        /*     Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _secondsRemaining <= 300
                ? warningColor.withValues(alpha: 20)
                : successColor.withValues(alpha: 20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _secondsRemaining <= 300
                  ? warningColor.withValues(alpha: 77)
                  : successColor.withValues(alpha: 77),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: _secondsRemaining <= 300 ? warningColor : successColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Valid for ${_formatTimeRemaining(_secondsRemaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _secondsRemaining <= 300 ? warningColor : successColor,
                ),
              ),
            ],
          ),
        ),
    */
      ],
    );
  }
}
