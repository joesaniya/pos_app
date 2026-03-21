// lib/screens/qr_code_upload_screen.dart
import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/qr_code_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';

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
}

class QrCodeUploadScreen extends StatefulWidget {
  final String businessId;
  const QrCodeUploadScreen({Key? key, required this.businessId})
    : super(key: key);

  @override
  State<QrCodeUploadScreen> createState() => _QrCodeUploadScreenState();
}

class _QrCodeUploadScreenState extends State<QrCodeUploadScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch existing QR URL on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrCodeProvider>().fetchQrUrl(widget.businessId);
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.rose : _C.royal,
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

  Future<void> _handleRemove() async {
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  'Upload your UPI or payment QR code here. It will be displayed at the bottom of the bill preview for customers to scan and pay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: _C.muted, height: 1.4),
                ),
                const SizedBox(height: 40),

                // ─── Current QR Preview ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(24),
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
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _C.royal,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 220,
                              height: 220,
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
                            color: _C.royal,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: _C.royalBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _C.royal.withOpacity(0.3),
                              style: BorderStyle.solid,
                              width: 2,
                            ),
                            // add dashed border visual hack if needed or keep solid
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
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ─── Progress Bar (if uploading) ─────────────────────
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
                  const SizedBox(height: 24),
                ] else ...[
                  // ─── Action Buttons ────────────────────────────────
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  if (prov.hasQrCode) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleRemove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove QR Code'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.rose,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _C.rose.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
