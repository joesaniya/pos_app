import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pos_app/providers/expense_provider.dart';
import 'package:pos_app/services/excel_validation_service.dart';
import 'package:pos_app/models/expense_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  static const pageBg = Color(0xFFF5F4F0);
  static const cardBg = Color(0xFFFFFFFF);
  static const indigoSoft = Color(0xFFEEEDFD);
  static const indigo = Color(0xFF4F46E5);
  static const emerald = Color(0xFF059669);
  static const emeraldBg = Color(0xFFECFDF5);
  static const amber = Color(0xFFD97706);
  static const amberBg = Color(0xFFFFFBEB);
  static const rose = Color(0xFFE11D48);
  static const roseBg = Color(0xFFFFF1F2);
  static const textPri = Color(0xFF111827);
  static const textSec = Color(0xFF6B7280);
  static const textTer = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFF3F4F6);
}

// ─────────────────────────────────────────────────────────────────────────────
// UPLOAD BILL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class UploadBillScreen extends StatefulWidget {
  const UploadBillScreen({super.key});

  @override
  State<UploadBillScreen> createState() => _UploadBillScreenState();
}

class _UploadBillScreenState extends State<UploadBillScreen> {
  String? _filePath;
  String? _fileName;
  bool _isProcessing = false;
  bool _isImporting = false;
  double _progress = 0;

  List<ValidatedExpenseData> _validated = [];
  List<ExcelValidationError> _errors = [];
  String _summary = '';
  bool _showResults = false;
  bool _hasErrors = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExpenseProvider>();
    if (provider.categories.isEmpty) provider.loadCategories();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        final name = result.files.first.name;
        if (path != null) {
          setState(() {
            _filePath = path;
            _fileName = name;
            _showResults = false;
            _validated = [];
            _errors = [];
            _summary = '';
          });
          await _validate();
        }
      }
    } catch (e) {
      _snack('Failed to pick file: $e', _T.rose);
    }
  }

  Future<void> _validate() async {
    if (_filePath == null) {
      _snack('Please select a file first', _T.rose);
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final provider = context.read<ExpenseProvider>();
      final catMap = <String, String>{
        for (final c in provider.categories) c.name: c.id,
      };
      final result = await ExcelValidationService.parseAndValidateExcelFile(
        filePath: _filePath!,
        categoryMap: catMap,
      );
      if (mounted) {
        setState(() {
          _validated = result['data'] ?? [];
          _errors = result['errors'] ?? [];
          _summary = result['summary'] ?? '';
          _hasErrors = _errors.isNotEmpty;
          _showResults = true;
          _isProcessing = false;
        });
        if (_hasErrors) {
          _snack('${_errors.length} validation issues found', _T.amber);
        } else if (_validated.isNotEmpty) {
          _snack('${_validated.length} expenses ready to import', _T.emerald);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _snack('Validation error: $e', _T.rose);
      }
    }
  }

  Future<void> _import() async {
    if (_validated.isEmpty) {
      _snack('No valid expenses to import', _T.rose);
      return;
    }
    final provider = context.read<ExpenseProvider>();

    if (_hasErrors) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _T.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Validation Warnings',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _T.textPri,
            ),
          ),
          content: Text(
            '${_errors.length} issues found.\nImport valid rows anyway?',
            style: TextStyle(fontSize: 14.sp, color: _T.textSec),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _T.textSec)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continue', style: TextStyle(color: _T.indigo)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _isImporting = true;
      _progress = 0;
    });
    try {
      int imported = 0;
      for (int i = 0; i < _validated.length; i++) {
        final exp = _validated[i];
        try {
          Expense? existing;
          try {
            existing = provider.expenses.firstWhere(
              (e) => e.invoiceNumber == exp.invoiceNumber,
            );
          } catch (_) {
            existing = null;
          }

          if (existing != null) {
            await provider.updateExpense(
              expenseId: existing.id,
              title: exp.title,
              categoryId: exp.categoryId,
              vendorName: exp.vendorName,
              amount: exp.amount,
              expenseDate: exp.expenseDate,
              invoiceNumber: exp.invoiceNumber,
              invoiceDate: exp.invoiceDate,
              notes: exp.notes,
            );
          } else {
            await provider.createExpense(
              title: exp.title,
              expenseNumber: provider.expenses.length + 1,
              categoryId: exp.categoryId,
              categoryName: exp.categoryName,
              vendorName: exp.vendorName,
              amount: exp.amount,
              expenseDate: exp.expenseDate,
              invoiceNumber: exp.invoiceNumber,
              invoiceDate: exp.invoiceDate,
              gstAmount: exp.gstAmount,
              gstNumber: exp.gstNumber,
              description: exp.description,
            );
          }
          imported++;
          if (mounted) setState(() => _progress = (i + 1) / _validated.length);
        } catch (e) {
          debugPrint('Import error: $e');
        }
      }

      setState(() => _isImporting = false);
      if (mounted) {
        if (imported == _validated.length) {
          _snack('Successfully imported $imported expenses!', _T.emerald);
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) Navigator.pop(context);
        } else {
          _snack(
            'Imported $imported of ${_validated.length} expenses',
            _T.amber,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _snack('Import failed: $e', _T.rose);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: AppBar(
        backgroundColor: _T.pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.w),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: _T.cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _T.border),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18.sp,
                color: _T.textPri,
              ),
            ),
          ),
        ),
        title: Text(
          'Upload Bill',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: _T.textPri,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            SizedBox(height: 20.h),
            _buildUploadZone(),
            if (_isProcessing) ...[
              SizedBox(height: 16.h),
              _buildProcessingCard(),
            ],
            if (_showResults && !_isProcessing) ...[
              SizedBox(height: 16.h),
              _buildResultsCard(),
            ],
            if (_isImporting) ...[
              SizedBox(height: 16.h),
              _buildImportProgress(),
            ],
            SizedBox(height: 24.h),
            if (!_isImporting) _buildActionRow(),
          ],
        ),
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _T.indigoSoft,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _T.indigo.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: _T.cardBg,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18.sp,
              color: _T.indigo,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: _T.indigo,
                  ),
                ),
                SizedBox(height: 8.h),
                ...[
                  '1. Upload your pre-filled Excel template',
                  '2. System validates all data automatically',
                  '3. Review & click Upload Now',
                  '4. Duplicate rows are updated, new ones inserted',
                ].map(
                  (step) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: _T.indigo.withOpacity(0.75),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Upload zone ───────────────────────────────────────────────────────────

  Widget _buildUploadZone() {
    final hasFile = _filePath != null;
    return GestureDetector(
      onTap: (_isProcessing || _isImporting) ? null : _pickFile,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 24.w),
        decoration: BoxDecoration(
          color: _T.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasFile ? _T.emerald : _T.border,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: hasFile ? _T.emeraldBg : _T.indigoSoft,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                hasFile ? Icons.check_rounded : Icons.upload_file_rounded,
                size: 26.sp,
                color: hasFile ? _T.emerald : _T.indigo,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              hasFile ? (_fileName ?? 'File Selected') : 'Choose an Excel File',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: _T.textPri,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            if (!hasFile)
              Text(
                'XLSX or XLS format only',
                style: TextStyle(fontSize: 12.sp, color: _T.textSec),
              ),
            if (hasFile && _showResults && _validated.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: _T.emeraldBg,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${_validated.length} valid expenses ready',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: _T.emerald,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              GestureDetector(
                onTap: (_isProcessing || _isImporting) ? null : _pickFile,
                child: Text(
                  'Change file',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _T.indigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Processing card ───────────────────────────────────────────────────────

  Widget _buildProcessingCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _T.indigoSoft,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _T.indigo.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22.w,
            height: 22.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: _T.indigo,
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Validating Excel file...',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _T.indigo,
                ),
              ),
              Text(
                'Checking data format and contents',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: _T.indigo.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Results card ──────────────────────────────────────────────────────────

  Widget _buildResultsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary banner
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: _hasErrors ? _T.amberBg : _T.emeraldBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: (_hasErrors ? _T.amber : _T.emerald).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _hasErrors ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: _hasErrors ? _T.amber : _T.emerald,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  _summary.isNotEmpty
                      ? _summary
                      : '${_validated.length} expenses ready to import',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _hasErrors ? _T.amber : _T.emerald,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Errors list
        if (_errors.isNotEmpty) ...[
          SizedBox(height: 14.h),
          Text(
            'Validation Issues',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: _T.textPri,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            constraints: BoxConstraints(maxHeight: 180.h),
            decoration: BoxDecoration(
              color: _T.cardBg,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: _T.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _errors.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, thickness: 1, color: _T.borderSoft),
              itemBuilder: (_, i) {
                final err = _errors[i];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18.w,
                        height: 18.w,
                        decoration: const BoxDecoration(
                          color: _T.roseBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 10.sp,
                          color: _T.rose,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Row ${err.rowNumber}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: _T.rose,
                              ),
                            ),
                            Text(
                              err.error,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: _T.textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // Valid count
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: _T.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: [
              Icon(Icons.table_rows_rounded, size: 18.sp, color: _T.indigo),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '${_validated.length} records ready to import'
                  '${_hasErrors ? ' (${_errors.length} issues)' : ' — no issues'}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _T.textPri,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Import progress ───────────────────────────────────────────────────────

  Widget _buildImportProgress() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _T.emeraldBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _T.emerald.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _T.emerald,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Importing to database...',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _T.emerald,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 5.h,
              backgroundColor: _T.emerald.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(_T.emerald),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}% complete',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: _T.emerald,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action row ────────────────────────────────────────────────────────────

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: _T.cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _T.border),
              ),
              child: Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _T.textSec,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: GestureDetector(
            onTap: (_validated.isEmpty || _isProcessing || _filePath == null)
                ? null
                : _import,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color:
                    (_validated.isEmpty || _isProcessing || _filePath == null)
                    ? _T.borderSoft
                    : _T.emerald,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: (_validated.isEmpty || _isProcessing)
                    ? null
                    : [
                        BoxShadow(
                          color: _T.emerald.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_rounded,
                    size: 16.sp,
                    color: (_validated.isEmpty || _isProcessing)
                        ? _T.textTer
                        : Colors.white,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Upload Now',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: (_validated.isEmpty || _isProcessing)
                          ? _T.textTer
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
