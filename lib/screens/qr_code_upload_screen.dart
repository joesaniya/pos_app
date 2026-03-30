// lib/screens/qr_code_upload_screen.dart
import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/qr_code_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'dart:developer';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE & TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const royal = Color(0xFF1847C4);
  static const ink = Color(0xFF0D1B3E);
  static const muted = Color(0xFF8C9AB8);
  static const line = Color(0xFFE4EAF8);
  static const royalBg = Color(0xFFEBF0FF);
  static const rose = Color(0xFFE11D48);
  static const green = Color(0xFF0EA472);
  static const amber = Color(0xFFD97706);
}

class QrCodeUploadScreen extends StatefulWidget {
  final String businessId;
  const QrCodeUploadScreen({Key? key, required this.businessId})
    : super(key: key);

  @override
  State<QrCodeUploadScreen> createState() => _QrCodeUploadScreenState();
}

class _QrCodeUploadScreenState extends State<QrCodeUploadScreen> {
  late TextEditingController _upiController;
  late FocusNode _upiFocusNode;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController();
    _upiFocusNode = FocusNode();

    // Fetch existing QR URL and UPI ID on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<QrCodeProvider>();
      prov.fetchQrUrl(widget.businessId);
      // Set UPI ID in controller if it exists
      if (prov.hasUpiId) {
        _upiController.text = prov.upiId;
      }
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    _upiFocusNode.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.rose : _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleUpload() async {
    final prov = context.read<QrCodeProvider>();
    final imgFile = await prov.pickQrImage();
    if (imgFile == null) return;

    final success = await prov.uploadQrCode(
      businessId: widget.businessId,
      imageFile: imgFile,
    );

    if (success) {
      _showSnack('Payment QR code updated successfully');
    } else {
      _showSnack(prov.errorMessage, isError: true);
    }
  }

  Future<void> _handleSaveUpiId() async {
    final prov = context.read<QrCodeProvider>();
    final upiId = _upiController.text.trim();
    log('Attempting to save UPI ID: $upiId');
    if (upiId.isEmpty) {
      _showSnack('Please enter a UPI ID', isError: true);
      return;
    }

    // Validate UPI ID format
    if (!prov.isValidUpiId(upiId)) {
      log('error:${prov.getUpiErrorMessage(upiId)}');
      _showSnack(prov.getUpiErrorMessage(upiId), isError: true);
      return;
    }

    final success = await prov.saveUpiId(
      businessId: widget.businessId,
      upiId: upiId,
    );

    if (success) {
      _showSnack('UPI ID saved successfully');
      _upiFocusNode.unfocus();
    } else {
      _showSnack(prov.errorMessage, isError: true);
    }
  }

  Future<void> _handleRemoveQrCode() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove QR Code?'),
        content: const Text(
          'This will remove the current payment QR code from the billing screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _C.rose),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final prov = context.read<QrCodeProvider>();
    final success = await prov.removeQrCode(widget.businessId);
    if (success) {
      _showSnack('QR code removed');
    } else {
      _showSnack(prov.errorMessage, isError: true);
    }
  }

  Future<void> _handleRemoveUpiId() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove UPI ID?'),
        content: const Text(
          'This will remove the saved UPI ID from your payment settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _C.rose),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final prov = context.read<QrCodeProvider>();
    final success = await prov.removeUpiId(widget.businessId);
    if (success) {
      _showSnack('UPI ID removed');
      _upiController.clear();
    } else {
      _showSnack(prov.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProfileProvider>().profile;
    final r = p?.role.label.toLowerCase() ?? '';
    final canUpload =
        r == 'owner' || r == 'admin' || r == 'manager' || r == 'system';

    if (!canUpload) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _C.ink),
          title: const Text(
            'Access Denied',
            style: TextStyle(
              color: _C.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 64, color: _C.rose),
              const SizedBox(height: 16),
              const Text(
                'Permission Denied',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _C.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only users with Owner, Admin, Manager, or System\nroles are allowed to modify payment QR codes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.muted, fontSize: 13),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.royal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Text(
          'Payment QR Code',
          style: TextStyle(
            color: _C.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Consumer<QrCodeProvider>(
        builder: (context, prov, child) {
          if (prov.isFetching) {
            return const Center(
              child: CircularProgressIndicator(color: _C.royal),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Restaurant Payment QR',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure payment methods for your customers. Choose at least one: upload a QR code or enter your UPI ID.',
                  style: TextStyle(fontSize: 14, color: _C.muted, height: 1.4),
                ),
                const SizedBox(height: 32),

                // ─── Status Badge ────────────────────────────────────
                _buildStatusBadge(prov),
                const SizedBox(height: 28),

                // ─── Section: QR Code Upload ─────────────────────────
                _buildSectionTitle('Payment QR Code'),
                const SizedBox(height: 12),
                _buildQrCodeSection(prov),
                const SizedBox(height: 32),

                // ─── Divider ──────────────────────────────────────────
                Container(
                  height: 1,
                  color: _C.line,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                ),
                const SizedBox(height: 12),

                // ─── Section: UPI ID Entry ────────────────────────────
                _buildSectionTitle('UPI ID'),
                const SizedBox(height: 12),
                _buildUpiIdSection(prov),
                const SizedBox(height: 40),

                // ─── Validation Error (if neither provided) ───────────
                if (!prov.hasAtLeastOnePaymentOption()) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.rose.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _C.rose.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded, color: _C.rose, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            prov.getPaymentOptionError(),
                            style: TextStyle(
                              color: _C.rose,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(QrCodeProvider prov) {
    List<Widget> statusItems = [];

    if (prov.hasQrCode) {
      statusItems.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _C.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: _C.green, size: 16),
              const SizedBox(width: 6),
              Text(
                'QR Code Configured',
                style: TextStyle(
                  color: _C.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (prov.hasUpiId) {
      if (statusItems.isNotEmpty) {
        statusItems.add(const SizedBox(width: 12));
      }
      statusItems.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _C.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: _C.green, size: 16),
              const SizedBox(width: 6),
              Text(
                'UPI ID Configured',
                style: TextStyle(
                  color: _C.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statusItems.isEmpty) {
      statusItems.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _C.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.amber.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_rounded, color: _C.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                'No Payment Method Configured',
                style: TextStyle(
                  color: _C.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: statusItems);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _C.ink,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildQrCodeSection(QrCodeProvider prov) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.royal.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (prov.hasQrCode) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                prov.qrCodeUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: _C.royal),
                    ),
                  );
                },
                errorBuilder: (ctx, err, stack) => Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _C.royalBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    size: 48,
                    color: _C.royal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Current QR Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.green,
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: _C.royalBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.royal.withOpacity(0.3), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 64,
                    color: _C.royal.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No QR Code',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _C.royal.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (prov.isUploading) ...[
            LinearProgressIndicator(
              value: prov.uploadProgress,
              backgroundColor: _C.royalBg,
              color: _C.royal,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 12),
            Text(
              'Uploading... ${(prov.uploadProgress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.royal,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleUpload,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  prov.hasQrCode ? 'Replace QR Code' : 'Upload QR Code',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.royal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (prov.hasQrCode) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleRemoveQrCode,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove QR Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.rose,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: _C.rose.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUpiIdSection(QrCodeProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your UPI ID (e.g., merchant@okhdfcbank)',
          style: TextStyle(
            fontSize: 12,
            color: _C.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _upiController,
          focusNode: _upiFocusNode,
          enabled: !prov.isFetching,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'username@bankcode',
            hintStyle: TextStyle(color: _C.muted.withOpacity(0.7)),
            filled: true,
            fillColor: _C.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _C.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _C.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _C.royal, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.payment_rounded,
                color: _C.royal.withOpacity(0.6),
                size: 20,
              ),
            ),
            suffixIcon: _upiController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _upiController.clear();
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded, color: _C.muted, size: 18),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (prov.hasUpiId) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _C.green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active UPI ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _C.green,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prov.upiId,
                        style: TextStyle(
                          fontSize: 11,
                          color: _C.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: prov.isFetching ? null : () => _handleSaveUpiId(),
                icon: const Icon(Icons.save_rounded),
                label: Text(prov.hasUpiId ? 'Update UPI ID' : 'Save UPI ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.royal,
                  disabledBackgroundColor: _C.muted.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (prov.hasUpiId) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: prov.isFetching ? null : _handleRemoveUpiId,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.rose,
                    disabledForegroundColor: _C.muted.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: _C.rose.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
