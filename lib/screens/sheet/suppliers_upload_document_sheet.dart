
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pos_app/models/supplier_modal.dart';
import 'package:pos_app/providers/supplier_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF8F9FD);
const _border = Color(0xFFE4E8F0);
const _primary = Color(0xFF1E3A5F);
const _primaryLight = Color(0xFFE8EEF8);
const _paid = Color(0xFF059669);
const _paidBg = Color(0xFFECFDF5);
const _overdue = Color(0xFFDC2626);
const _overdueBg = Color(0xFFFEF2F2);
const _amber = Color(0xFFD97706);
const _amberLight = Color(0xFFFEF3C7);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);
const _textMute = Color(0xFFABB8CC);
const _divider = Color(0xFFEEF1F7);

// ══════════════════════════════════════════════════════════════════════════════
class UploadDocumentSheet extends StatefulWidget {
  final String supplierId;
  final SupplierProvider provider;

  const UploadDocumentSheet({
    Key? key,
    required this.supplierId,
    required this.provider,
  }) : super(key: key);

  @override
  State<UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<UploadDocumentSheet> {
  final _titleCtrl = TextEditingController();
  final _picker = ImagePicker();

  DocumentType _docType = DocumentType.invoice;
  DateTime? _expiry;
  File? _pickedFile;
  String? _pickedFileName;
  String? _pickedFileExt;
  bool _loading = false;
  bool _pickInProgress = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── File type helpers ─────────────────────────────────────────────────────

  bool get _isImage =>
      _pickedFileExt != null &&
      {
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
        'heif',
      }.contains(_pickedFileExt!.toLowerCase());

  bool get _isPdf => _pickedFileExt?.toLowerCase() == 'pdf';

  IconData get _fileIcon {
    if (_isPdf) return Icons.picture_as_pdf_rounded;
    if (_isImage) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get _fileIconColor {
    if (_isPdf) return _overdue;
    if (_isImage) return _primary;
    return _amber;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SOURCE PICKER  ← KEY FIX: uses showDialog NOT showModalBottomSheet
  //
  //  showModalBottomSheet owns a Flutter surface layer.  When the sheet is
  //  dismissed while simultaneously launching the Camera Activity, Android
  //  gets two owners trying to acquire the EGL surface → crash.
  //
  //  showDialog uses a Dialog window which does NOT own the EGL surface.
  //  Dismissing it is instantaneous with no surface transition, so the
  //  Camera Activity can safely acquire the surface right after pop().
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _showSourceDialog() async {
    if (_pickInProgress) return;

    final choice = await showDialog<_PickSource>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Source',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _textPri,
                ),
              ),
              const SizedBox(height: 16),

              // Browse files
              _DialogOption(
                icon: Icons.folder_open_rounded,
                iconColor: _amber,
                iconBg: _amberLight,
                label: 'Browse Files',
                subtitle: 'PDF · Word · Excel · Any file',
                onTap: () => Navigator.pop(ctx, _PickSource.file),
              ),
              const SizedBox(height: 10),

              // Gallery
              _DialogOption(
                icon: Icons.photo_library_rounded,
                iconColor: _primary,
                iconBg: _primaryLight,
                label: 'Photo Library',
                subtitle: 'Pick an existing image',
                onTap: () => Navigator.pop(ctx, _PickSource.gallery),
              ),
              const SizedBox(height: 10),

              // Camera  ← this used to crash
             /* _DialogOption(
                icon: Icons.camera_alt_rounded,
                iconColor: _paid,
                iconBg: _paidBg,
                label: 'Camera',
                subtitle: 'Photograph a document',
                onTap: () => Navigator.pop(ctx, _PickSource.camera),
              ),*/

              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _textSec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    // ── After dialog is fully gone, launch the chosen source ──────────────
    // A tiny delay ensures the dialog's dismiss animation completes before
    // the picker is invoked. This is safe here because Dialog (unlike
    // ModalBottomSheet) does not own the EGL surface.
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    switch (choice) {
      case _PickSource.file:
        await _pickAnyFile();
        break;
      case _PickSource.gallery:
        await _pickFromGallery();
        break;
      /*case _PickSource.camera:
        await _pickFromCamera();
        break;*/
    }
  }

  // ── Pick any file (file_picker) ───────────────────────────────────────────
  Future<void> _pickAnyFile() async {
    if (_pickInProgress) return;
    _pickInProgress = true;
    _clearError();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'heif',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'csv',
          'rtf',
        ],
        withData: false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.first;
      if (pf.path == null) {
        _setError('Could not access this file. Try a different one.');
        return;
      }
      _applyPicked(
        path: pf.path!,
        name: pf.name,
        ext: (pf.extension ?? '').toLowerCase(),
      );
    } catch (e) {
      log('[UploadDoc] pickAnyFile: $e');
      _setError(_friendly(e));
    } finally {
      _pickInProgress = false;
    }
  }

  // ── Pick from gallery (image_picker) ─────────────────────────────────────
  Future<void> _pickFromGallery() async {
    if (_pickInProgress) return;
    _pickInProgress = true;
    _clearError();

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xfile == null) return;
      _applyPicked(
        path: xfile.path,
        name: xfile.name,
        ext: xfile.path.split('.').last.toLowerCase(),
      );
    } catch (e) {
      log('[UploadDoc] pickFromGallery: $e');
      _setError(_friendly(e));
    } finally {
      _pickInProgress = false;
    }
  }

  // ── Pick from camera (image_picker) ──────────────────────────────────────
  Future<void> _pickFromCamera() async {
    if (_pickInProgress) return;
    _pickInProgress = true;
    _clearError();

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return; // user cancelled
      _applyPicked(
        path: xfile.path,
        name: xfile.name,
        ext: xfile.path.split('.').last.toLowerCase(),
      );
    } catch (e) {
      log('[UploadDoc] pickFromCamera: $e');
      final msg = e.toString().toLowerCase();
      if (!msg.contains('cancel') && !msg.contains('cancelled')) {
        _setError(_friendly(e));
      }
    } finally {
      _pickInProgress = false;
    }
  }

  // ── Apply picked result ───────────────────────────────────────────────────
  void _applyPicked({
    required String path,
    required String name,
    required String ext,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      _setError('Selected file could not be read. Try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _pickedFile = file;
      _pickedFileName = name;
      _pickedFileExt = ext;
      _error = null;
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = name
            .replaceAll(RegExp(r'\.[^.]+$'), '')
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .trim();
      }
    });
  }

  void _clearPickedFile() {
    if (!mounted) return;
    setState(() {
      _pickedFile = null;
      _pickedFileName = null;
      _pickedFileExt = null;
    });
  }

  // ── Expiry picker ─────────────────────────────────────────────────────────
  Future<void> _pickExpiry() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null && mounted) setState(() => _expiry = d);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _setError('Document title is required.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final doc = SupplierDocument(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      type: _docType,
      title: _titleCtrl.text.trim(),
      uploadedOn: DateTime.now(),
      expiryDate: _expiry,
    );

    try {
      bool ok;
      if (_pickedFile != null) {
        final saved = await widget.provider.uploadDocument(
          supplierId: widget.supplierId,
          doc: doc,
          file: _pickedFile!,
        );
        ok = saved != null;
      } else {
        ok = await widget.provider.addDocument(widget.supplierId, doc);
      }

      if (!mounted) return;

      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() {
          _loading = false;
          _error = widget.provider.errorMessage.isNotEmpty
              ? widget.provider.errorMessage
              : 'Upload failed. Please try again.';
        });
      }
    } catch (e) {
      log('[UploadDoc] submit: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Upload failed: $e';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setError(String msg) {
    if (mounted && msg.isNotEmpty) setState(() => _error = msg);
  }

  void _clearError() {
    if (_error != null && mounted) setState(() => _error = null);
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('permission') || s.contains('denied')) {
      return 'Permission denied. Go to Settings → Apps → pos_app → Permissions.';
    }
    if (s.contains('cancel') || s.contains('cancelled')) return '';
    return 'Could not pick file. Please try again.';
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: _divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📎', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textPri,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'PDF · Image · Word · Excel  ',
                        // · Camera
                        
                        style: TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: _divider),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── File picker tap area ───────────────────────────────
                  GestureDetector(
                    onTap: _showSourceDialog, // ← Dialog not BottomSheet
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _pickedFile != null ? _paidBg : _surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _pickedFile != null
                              ? _paid.withOpacity(0.4)
                              : _primary.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      child: _pickedFile != null
                          ? _SelectedRow(
                              fileName: _pickedFileName ?? '',
                              fileIcon: _fileIcon,
                              fileIconColor: _fileIconColor,
                              onClear: _clearPickedFile,
                              onView: () async {
                                if (_pickedFile != null) {
                                  await OpenFilex.open(_pickedFile!.path);
                                }
                              },
                            )
                          : const _EmptyHint(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Title ──────────────────────────────────────────────
                  const _Lbl('Document Title *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPri,
                    ),
                    decoration: _dec('e.g. GST Certificate 2025'),
                  ),

                  const SizedBox(height: 16),

                  // ── Document type ──────────────────────────────────────
                  const _Lbl('Document Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DocumentType.values.map((t) {
                      final sel = _docType == t;
                      return GestureDetector(
                        onTap: () => setState(() => _docType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? _primaryLight : _surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _primary : _border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? _primary : _textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Expiry date ────────────────────────────────────────
                  GestureDetector(
                    onTap: _pickExpiry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _expiry == null
                                ? 'Set expiry date (optional)'
                                : 'Expires ${_fmtDate(_expiry!)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _expiry != null ? _textPri : _textMute,
                            ),
                          ),
                          if (_expiry != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _expiry = null),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: _textMute,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Error ──────────────────────────────────────────────
                  if (_error != null && _error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _overdueBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _overdue.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: _overdue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _overdue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Submit ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _pickedFile != null
                                  ? 'Upload & Save'
                                  : 'Save Record Only',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textMute, fontSize: 13),
    filled: true,
    fillColor: _surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
  );
}

// ── Enum for dialog return value ──────────────────────────────────────────────
enum _PickSource { file, gallery, 
// camera 
}

// ══════════════════════════════════════════════════════════════════════════════
//  DIALOG OPTION TILE (replaces _SourceTile which was inside a BottomSheet)
// ══════════════════════════════════════════════════════════════════════════════
class _DialogOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DialogOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPri,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _textSec),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: _textMute,
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SELECTED FILE ROW
// ══════════════════════════════════════════════════════════════════════════════
class _SelectedRow extends StatelessWidget {
  final String fileName;
  final IconData fileIcon;
  final Color fileIconColor;
  final VoidCallback onClear;
  final VoidCallback onView;

  const _SelectedRow({
    required this.fileName,
    required this.fileIcon,
    required this.fileIconColor,
    required this.onClear,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fileIconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(fileIcon, color: fileIconColor, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName.isEmpty ? 'File selected' : fileName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPri,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap to change',
              style: TextStyle(fontSize: 11, color: _textMute),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onView,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.visibility_outlined,
            color: _primary,
            size: 16,
          ),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onClear,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _overdueBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, color: _overdue, size: 16),
        ),
      ),
      const SizedBox(width: 4),
      const Icon(Icons.check_circle_rounded, color: _paid, size: 20),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE HINT
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: _primaryLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.upload_file_rounded, color: _primary, size: 30),
      ),
      const SizedBox(height: 10),
      const Text(
        'Tap to attach a file',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        children: const [
          _Pill(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            color: _overdue,
          ),
          _Pill(icon: Icons.image_rounded, label: 'Image', color: _primary),
          _Pill(
            icon: Icons.insert_drive_file_rounded,
            label: 'Doc/Excel',
            color: _amber,
          ),
          // _Pill(icon: Icons.camera_alt_rounded, label: 'Camera', color: _paid),
        ],
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ── Shared label widget ───────────────────────────────────────────────────────
class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _textSec,
      letterSpacing: 0.3,
    ),
  );
}
