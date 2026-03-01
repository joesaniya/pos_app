// lib/screens/reports/report_screen.dart
//
// Report Generation Screen
// Flow: Select Company → Select Period → [Generate] → Preview → [Download PDF]
//
// ROLE GATE: Only admin / system / owner / manager.
// The PDF is generated using the `pdf` + `printing` packages:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//   path_provider: ^2.1.3
//
// Add to pubspec.yaml:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//   path_provider: ^2.1.3

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../providers/report_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLOURS  (matching dashboard palette)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF6F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F8);
  static const border = Color(0xFFEAEAF4);
  static const primary = Color(0xFF5A3FD6);
  static const primaryL = Color(0xFFEDE9FF);
  static const primaryD = Color(0xFF3D2AA0);
  static const textPri = Color(0xFF1A1A2E);
  static const textSec = Color(0xFF6B6B86);
  static const textMute = Color(0xFFAAABBB);
  static const green = Color(0xFF059669);
  static const greenL = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redL = Color(0xFFFEF2F2);
  static const amber = Color(0xFFD97706);
  static const amberL = Color(0xFFFFF4E0);
  static const blue = Color(0xFF0A7ADB);
  static const blueL = Color(0xFFE0F0FF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  REPORT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _pdfDownloading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().init();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          backgroundColor: _C.bg,
          appBar: _buildAppBar(prov),
          body: SafeArea(
            child: prov.hasReport
                ? _buildPreviewTab(context, prov)
                : _buildSetupPanel(context, prov),
          ),
        );
      },
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ReportProvider prov) {
    return AppBar(
      backgroundColor: _C.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _C.textPri,
          size: 18,
        ),
        onPressed: () {
          if (prov.hasReport) {
            prov.clearReport();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Generation',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _C.textPri,
            ),
          ),
          Text(
            prov.hasReport
                ? '${prov.reportData!.companyName} · ${prov.reportData!.period}'
                : 'Select company & period',
            style: const TextStyle(fontSize: 11, color: _C.textSec),
          ),
        ],
      ),
      actions: [
        if (prov.hasReport)
          _pdfDownloading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.primary,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () => _downloadPdf(prov.reportData!),
                    icon: const Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: _C.primary,
                    ),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _C.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: _C.primaryL,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SETUP PANEL  (step 1 & 2)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSetupPanel(BuildContext context, ReportProvider prov) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Breadcrumb ───────────────────────────────────────────────────
          _Breadcrumb(
            steps: const ['Select Company', 'Select Period', 'Preview'],
            activeIndex: prov.selectedCompanyId == null ? 0 : 1,
          ),
          const SizedBox(height: 28),

          // ── Step 1: Company ───────────────────────────────────────────────
          _buildStepCard(
            step: '1',
            title: 'Select Company',
            isComplete: prov.selectedCompanyId != null,
            child: prov.loadingCompanies
                ? const _LoadingRow('Loading companies…')
                : prov.companies.isEmpty
                ? const _EmptyRow('No companies found')
                : Column(
                    children: prov.companies.map((c) {
                      final isSelected = prov.selectedCompanyId == c.id;
                      return _SelectTile(
                        label: c.name,
                        subtitle: c.id,
                        isSelected: isSelected,
                        icon: Icons.business_rounded,
                        onTap: () => prov.selectCompany(c.id),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // ── Step 2: Period ────────────────────────────────────────────────
          AnimatedOpacity(
            opacity: prov.selectedCompanyId != null ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: prov.selectedCompanyId == null,
              child: _buildStepCard(
                step: '2',
                title: 'Select Period',
                isComplete: prov.selectedCompanyId != null,
                child: Column(
                  children: [
                    _buildPeriodOption(
                      prov,
                      period: 'Weekly',
                      icon: Icons.view_week_rounded,
                      description: 'Current week (Mon – Sun)',
                      color: _C.blue,
                    ),
                    const SizedBox(height: 8),
                    _buildPeriodOption(
                      prov,
                      period: 'Monthly',
                      icon: Icons.calendar_month_rounded,
                      description: 'Current calendar month',
                      color: _C.green,
                    ),
                    const SizedBox(height: 8),
                    _buildPeriodOption(
                      prov,
                      period: 'All',
                      icon: Icons.all_inclusive_rounded,
                      description: 'All-time combined report',
                      color: _C.amber,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Error ────────────────────────────────────────────────────────
          if (prov.error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.redL,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.red.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _C.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      prov.error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (prov.error != null) const SizedBox(height: 16),

          // ── Generate button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: prov.selectedCompanyId == null || prov.generating
                  ? null
                  : () => prov.generateReport(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                disabledBackgroundColor: _C.primary.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: prov.generating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Generating Report…',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assessment_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Generate Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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

  Widget _buildStepCard({
    required String step,
    required String title,
    required bool isComplete,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? _C.primary.withOpacity(0.3) : _C.border,
          width: isComplete ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isComplete
                        ? const LinearGradient(
                            colors: [_C.primary, _C.primaryD],
                          )
                        : null,
                    color: isComplete ? null : _C.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          step,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _C.textSec,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isComplete ? _C.primary : _C.textPri,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(
    ReportProvider prov, {
    required String period,
    required IconData icon,
    required String description,
    required Color color,
  }) {
    final isSelected = prov.selectedPeriod == period;
    return GestureDetector(
      onTap: () => prov.selectPeriod(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : _C.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? color : _C.textPri,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: _C.textSec),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PREVIEW TAB  (step 3)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPreviewTab(BuildContext context, ReportProvider prov) {
    final data = prov.reportData!;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final dateFmt = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Breadcrumb ───────────────────────────────────────────────────
          const _Breadcrumb(
            steps: ['Select Company', 'Select Period', 'Preview'],
            activeIndex: 2,
          ),
          const SizedBox(height: 20),

          // ── Report header card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.primary, _C.primaryD],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _C.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assessment_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data.period.toUpperCase()} REPORT',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data.companyName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFmt.format(data.fromDate)} – ${dateFmt.format(data.toDate.subtract(const Duration(days: 1)))}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _WhiteMetric(
                      label: 'Total Revenue',
                      value: '₹${fmt.format(data.totalRevenue)}',
                    ),
                    _WhiteMetric(
                      label: 'Total Orders',
                      value: '${data.totalOrders}',
                    ),
                    _WhiteMetric(
                      label: 'Avg Order',
                      value: '₹${fmt.format(data.averageOrderValue)}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(data.generatedAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Summary metrics grid ──────────────────────────────────────────
          _SectionTitle('Summary'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Completed',
                  value: '${data.completedOrders}',
                  sub: '${data.completionRate.toStringAsFixed(1)}%',
                  color: _C.green,
                  bg: _C.greenL,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Cancelled',
                  value: '${data.cancelledOrders}',
                  sub: '${data.cancelRate.toStringAsFixed(1)}%',
                  color: _C.red,
                  bg: _C.redL,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Daily revenue chart (bar representation) ──────────────────────
          if (data.dailyRevenue.isNotEmpty) ...[
            _SectionTitle('Daily Revenue Breakdown'),
            const SizedBox(height: 12),
            _DailyRevenueChart(dailyRevenue: data.dailyRevenue),
            const SizedBox(height: 24),
          ],

          // ── Staff performance ─────────────────────────────────────────────
          if (data.staffSummaries.isNotEmpty) ...[
            _SectionTitle('Staff Performance'),
            const SizedBox(height: 12),
            _buildStaffTable(data),
            const SizedBox(height: 24),
          ],

          // ── Top selling items ─────────────────────────────────────────────
          if (data.topItems.isNotEmpty) ...[
            _SectionTitle('Top Selling Items'),
            const SizedBox(height: 12),
            _buildTopItemsTable(data),
            const SizedBox(height: 24),
          ],

          // ── Download CTA ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _pdfDownloading ? null : () => _downloadPdf(data),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _pdfDownloading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Preparing PDF…',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Download PDF Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Secondary: generate new report
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => context.read<ReportProvider>().clearReport(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.primary,
                side: const BorderSide(color: _C.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Generate Another Report',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Staff table ────────────────────────────────────────────────────────────
  Widget _buildStaffTable(ReportData data) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _C.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Staff', style: _tableHead)),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Orders',
                    textAlign: TextAlign.center,
                    style: _tableHead,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.right,
                    style: _tableHead,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.right,
                    style: _tableHead,
                  ),
                ),
              ],
            ),
          ),
          ...data.staffSummaries.asMap().entries.map((e) {
            final s = e.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _C.primaryL,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.name.isNotEmpty
                                    ? s.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _C.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _C.textPri,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    s.role,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: _C.textMute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${s.completedOrders}/${s.totalOrders}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.textPri,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${_fmt(s.revenue)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _C.green,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${s.cancelledOrders}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: s.cancelledOrders > 0 ? _C.red : _C.textMute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.key < data.staffSummaries.length - 1)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: _C.border,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Top items table ────────────────────────────────────────────────────────
  Widget _buildTopItemsTable(ReportData data) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _C.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Item', style: _tableHead)),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: _tableHead,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.right,
                    style: _tableHead,
                  ),
                ),
              ],
            ),
          ),
          ...data.topItems.asMap().entries.map((e) {
            final item = e.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: e.key < 3 ? _C.amberL : _C.surfaceAlt,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                e.key < 3
                                    ? ['🥇', '🥈', '🥉'][e.key]
                                    : '${e.key + 1}',
                                style: TextStyle(
                                  fontSize: e.key < 3 ? 12 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _C.textPri,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.category.isNotEmpty)
                                    Text(
                                      item.category,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: _C.textMute,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.quantitySold}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _C.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${_fmt(item.revenue)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.textSec,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.key < data.topItems.length - 1)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: _C.border,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PDF GENERATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _downloadPdf(ReportData data) async {
    setState(() => _pdfDownloading = true);
    try {
      final pdfBytes = await _buildPdf(data);
      // Use the printing package to share/save PDF natively
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${data.companyName.replaceAll(' ', '_')}_${data.period}_Report_${DateFormat('yyyyMMdd').format(data.generatedAt)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: _C.red),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfDownloading = false);
    }
  }

  Future<Uint8List> _buildPdf(ReportData data) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.00', 'en_IN');

    // Colour constants for PDF
    const purple = PdfColor.fromInt(0xFF5A3FD6);
    const purpleLight = PdfColor.fromInt(0xFFEDE9FF);
    const darkText = PdfColor.fromInt(0xFF1A1A2E);
    const greyText = PdfColor.fromInt(0xFF6B6B86);
    const green = PdfColor.fromInt(0xFF059669);
    const red = PdfColor.fromInt(0xFFDC2626);
    const bgGrey = PdfColor.fromInt(0xFFF2F2F8);
    const borderColor = PdfColor.fromInt(0xFFEAEAF4);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.companyName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  pw.Text(
                    '${data.period} Revenue Report',
                    style: pw.TextStyle(fontSize: 10, color: greyText),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(fontSize: 9, color: greyText),
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(data.generatedAt)}',
                    style: pw.TextStyle(fontSize: 9, color: greyText),
                  ),
                ],
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // ── Cover summary box ────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${data.period.toUpperCase()} REPORT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor(1, 1, 1, 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  data.companyName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '${dateFmt.format(data.fromDate)} – ${dateFmt.format(data.toDate.subtract(const Duration(days: 1)))}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: const PdfColor(1, 1, 1, 0.7),
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Divider(color: const PdfColor(1, 1, 1, 0.24)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfMetric(
                      'Total Revenue',
                      '₹${numFmt.format(data.totalRevenue)}',
                    ),
                    _pdfMetric('Total Orders', '${data.totalOrders}'),
                    _pdfMetric(
                      'Completed',
                      '${data.completedOrders} (${data.completionRate.toStringAsFixed(1)}%)',
                    ),
                    _pdfMetric(
                      'Cancelled',
                      '${data.cancelledOrders} (${data.cancelRate.toStringAsFixed(1)}%)',
                    ),
                    _pdfMetric(
                      'Avg Order',
                      '₹${numFmt.format(data.averageOrderValue)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Staff Performance ─────────────────────────────────────────────
          if (data.staffSummaries.isNotEmpty) ...[
            pw.Text(
              'STAFF PERFORMANCE',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: greyText,
                letterSpacing: 1.0,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgGrey),
                  children:
                      [
                            'Staff Member',
                            'Total',
                            'Completed',
                            'Cancelled',
                            'Revenue',
                          ]
                          .map(
                            (h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                h,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: greyText,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                ...data.staffSummaries.map(
                  (s) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              s.name,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            pw.Text(
                              s.role,
                              style: pw.TextStyle(fontSize: 8, color: greyText),
                            ),
                          ],
                        ),
                      ),
                      _pdfCell('${s.totalOrders}', darkText),
                      _pdfCell('${s.completedOrders}', green),
                      _pdfCell(
                        '${s.cancelledOrders}',
                        s.cancelledOrders > 0 ? red : greyText,
                      ),
                      _pdfCell('₹${numFmt.format(s.revenue)}', green),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // ── Top Items ─────────────────────────────────────────────────────
          if (data.topItems.isNotEmpty) ...[
            pw.Text(
              'TOP SELLING ITEMS',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: greyText,
                letterSpacing: 1.0,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgGrey),
                  children: ['#', 'Item', 'Qty Sold', 'Revenue']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: greyText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...data.topItems.asMap().entries.map((e) {
                  final item = e.value;
                  return pw.TableRow(
                    children: [
                      _pdfCell('${e.key + 1}', greyText),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.name,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            if (item.category.isNotEmpty)
                              pw.Text(
                                item.category,
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: greyText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _pdfCell('${item.quantitySold}', purple),
                      _pdfCell('₹${numFmt.format(item.revenue)}', green),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // ── Daily Revenue ────────────────────────────────────────────────
          if (data.dailyRevenue.isNotEmpty) ...[
            pw.Text(
              'DAILY REVENUE BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: greyText,
                letterSpacing: 1.0,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: bgGrey),
                  children: ['Date', 'Revenue']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: greyText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...data.dailyRevenue.map(
                  (d) => pw.TableRow(
                    children: [
                      _pdfCell(
                        DateFormat('dd MMM yyyy').format(d.date),
                        darkText,
                      ),
                      _pdfCell('₹${numFmt.format(d.revenue)}', green),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: const PdfColor(1, 1, 1, 0.7)),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfCell(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static const _tableHead = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: _C.textSec,
    letterSpacing: 0.4,
  );

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: _C.textMute,
      letterSpacing: 1.4,
    ),
  );
}

class _WhiteMetric extends StatelessWidget {
  final String label, value;
  const _WhiteMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final String label, value, sub;
  final Color color, bg;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.bg,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Breadcrumb extends StatelessWidget {
  final List<String> steps;
  final int activeIndex;
  const _Breadcrumb({required this.steps, required this.activeIndex});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final label = e.value;
        final isDone = i < activeIndex;
        final isActive = i == activeIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDone || isActive ? _C.primary : _C.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isActive
                            ? _C.primary
                            : isDone
                            ? _C.green
                            : _C.textMute,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Icon(Icons.chevron_right, size: 14, color: _C.textMute),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final String label, subtitle;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;
  const _SelectTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _C.primaryL : _C.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _C.primary.withOpacity(0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? _C.primary.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: isSelected ? _C.primary : _C.textSec,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _C.primary : _C.textPri,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: _C.textMute),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: _C.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final String message;
  const _LoadingRow(this.message);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
        ),
        const SizedBox(width: 10),
        Text(message, style: const TextStyle(fontSize: 13, color: _C.textSec)),
      ],
    ),
  );
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow(this.message);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: const TextStyle(fontSize: 13, color: _C.textMute),
    ),
  );
}

// ── Daily revenue chart (horizontal bar) ──────────────────────────────────────

class _DailyRevenueChart extends StatelessWidget {
  final List<({DateTime date, double revenue})> dailyRevenue;
  const _DailyRevenueChart({required this.dailyRevenue});

  @override
  Widget build(BuildContext context) {
    if (dailyRevenue.isEmpty) return const SizedBox.shrink();

    final maxRev = dailyRevenue
        .map((d) => d.revenue)
        .reduce((a, b) => a > b ? a : b);

    final dateFmt = DateFormat('dd MMM');
    final numFmt = NumberFormat('#,##0', 'en_IN');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: dailyRevenue.map((d) {
          final frac = maxRev > 0 ? d.revenue / maxRev : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    dateFmt.format(d.date),
                    style: const TextStyle(fontSize: 10, color: _C.textSec),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 10,
                      backgroundColor: _C.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation(_C.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: Text(
                    '₹${numFmt.format(d.revenue)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
