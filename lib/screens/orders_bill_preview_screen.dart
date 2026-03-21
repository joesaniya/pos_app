// lib/screens/orders/bill_preview_screen.dart
// ══════════════════════════════════════════════════════════════
//  BILL PREVIEW SCREEN
//  Shows full bill after payment confirmation
//  Supports: Share · Print · Download PDF (via printing package)
// ══════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/models/order_modal.dart';

// ── Colours ────────────────────────────────────────────────────
class BC {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F9FD);
  static const border = Color(0xFFE4E8F2);
  static const primary = Color(0xFF1B4332);
  static const primaryLight = Color(0xFFD8F3DC);
  static const accent = Color(0xFF40916C);
  static const gold = Color(0xFFD4A017);
  static const goldLight = Color(0xFFFFF8E1);
  static const textPri = Color(0xFF0F172A);
  static const textSec = Color(0xFF64748B);
  static const textMute = Color(0xFFABB8CC);
  static const divider = Color(0xFFEEF1F7);
}

// ══════════════════════════════════════════════════════════════
class BillPreviewScreen extends StatefulWidget {
  final Order order;

  const BillPreviewScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _generatingPdf = false;

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_IN').format(v);

  String _fmtDate(DateTime d) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(d.toLocal());

  // ── PDF Generation ────────────────────────────────────────────
  Future<Uint8List> _generatePdf() async {
    final order = widget.order;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      order.businessName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),

              // ── Bill details ────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill No: ${order.billNumber ?? "—"}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        'Order #${order.orderNumber}',
                        style: const pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        _fmtDate(order.paidAt ?? order.completedAt ?? order.createdAt),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        [
                          order.orderType.label,
                          if (order.tableNumber != null) ...[
                            'Table ${order.tableNumber}',
                            if (order.seatLabel != null) order.seatLabel!,
                          ] else
                            'Takeaway',
                        ].join(' · '),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (order.customerName != null) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'Customer: ${order.customerName}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),

              // ── Items header ────────────────────────────────────
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Rate',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Amount',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey300),

              // ── Items list ──────────────────────────────────────
              ...order.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            item.itemName,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.itemPrice),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.subtotal),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  )),

              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),

              // ── Totals ──────────────────────────────────────────
              _pdfRow('Subtotal', _fmt(order.subtotal)),
              pw.SizedBox(height: 3),
              _pdfRow(
                  'Tax (${order.taxRate.toInt()}%)', _fmt(order.taxAmount)),
              if (order.discountAmount > 0) ...[
                pw.SizedBox(height: 3),
                _pdfRow('Discount', '- ${_fmt(order.discountAmount)}'),
              ],
              if (order.tipAmount > 0) ...[
                pw.SizedBox(height: 3),
                _pdfRow('Tip', '+ ${_fmt(order.tipAmount)}'),
              ],
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Grand total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Rs. ${_fmt(order.grandTotal)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),

              // ── Payment info ────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment: ${order.paymentMode?.label ?? "Cash"}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'PAID',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ),
                ],
              ),

              if (order.paymentRef != null) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Ref: ${order.paymentRef}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],

              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Thank you for your visit! 🙏',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Served by: ${order.createdByName}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
    ],
  );

  Future<void> _printBill() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.order.billNumber ?? "Bill"}_${widget.order.orderNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _shareBill() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${widget.order.billNumber ?? "Bill"}_Order${widget.order.orderNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: BC.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────
            Container(
              color: BC.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.billNumber ?? 'Bill',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Order #${order.orderNumber} · ${order.businessName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_generatingPdf)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Row(
                      children: [
                        _ActionBtn(
                          icon: Icons.share_rounded,
                          onTap: _shareBill,
                          tooltip: 'Share PDF',
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          icon: Icons.print_rounded,
                          onTap: _printBill,
                          tooltip: 'Print',
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Bill body ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Receipt card ───────────────────────────
                    _ReceiptCard(order: order, fmtFn: _fmt),

                    const SizedBox(height: 16),

                    // ── Action buttons ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _BigActionButton(
                            icon: Icons.picture_as_pdf_rounded,
                            label: 'Download PDF',
                            sublabel: 'Save to device',
                            color: BC.primary,
                            onTap: _printBill,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BigActionButton(
                            icon: Icons.share_rounded,
                            label: 'Share Bill',
                            sublabel: 'WhatsApp / Email',
                            color: BC.accent,
                            onTap: _shareBill,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // New order button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Back to Orders',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: BC.primary.withOpacity(0.4),
                          ),
                          foregroundColor: BC.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Receipt card ──────────────────────────────────────────────
class _ReceiptCard extends StatelessWidget {
  final Order order;
  final String Function(double) fmtFn;

  const _ReceiptCard({required this.order, required this.fmtFn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BC.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [BC.primary, Color(0xFF2D6A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TAX INVOICE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'PAID',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InfoChip(
                      label: order.billNumber ?? '—',
                      icon: Icons.receipt_rounded,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: 'Order #${order.orderNumber}',
                      icon: Icons.tag_rounded,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: order.orderType.label,
                      icon: Icons.restaurant_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Date & customer ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: BC.textMute,
                ),
                const SizedBox(width: 5),
                Text(
                  DateFormat('dd MMM yyyy · hh:mm a').format(
                    (order.paidAt ?? order.completedAt ?? order.createdAt)
                        .toLocal(),
                  ),
                  style: const TextStyle(fontSize: 12, color: BC.textSec),
                ),
                if (order.tableNumber != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: BC.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      [
                        'Table ${order.tableNumber}',
                        if (order.seatLabel != null) order.seatLabel!,
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BC.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (order.customerName != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: BC.textMute,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    order.customerName!,
                    style: const TextStyle(fontSize: 12, color: BC.textSec),
                  ),
                  if (order.customerPhone != null) ...[
                    const Text(
                      ' · ',
                      style: TextStyle(color: BC.textMute),
                    ),
                    Text(
                      order.customerPhone!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BC.textMute,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const Divider(height: 1, color: BC.divider, indent: 16, endIndent: 16),

          // ── Items ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: const [
                Expanded(
                  flex: 5,
                  child: Text(
                    'ITEM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BC.textMute,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BC.textMute,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'AMOUNT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BC.textMute,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ...order.items.map(
            (item) => _ItemRow(item: item, fmtFn: fmtFn),
          ),

          const Divider(height: 1, color: BC.divider),

          // ── Totals ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              children: [
                _TotalRow('Subtotal', fmtFn(order.subtotal), false),
                const SizedBox(height: 5),
                _TotalRow(
                  'Tax (${order.taxRate.toInt()}%)',
                  fmtFn(order.taxAmount),
                  false,
                ),
                if (order.discountAmount > 0) ...[
                  const SizedBox(height: 5),
                  _TotalRow(
                    'Discount',
                    '- ${fmtFn(order.discountAmount)}',
                    false,
                    color: const Color(0xFF059669),
                  ),
                ],
                if (order.tipAmount > 0) ...[
                  const SizedBox(height: 5),
                  _TotalRow(
                    'Tip (Thank you!)',
                    '+ ${fmtFn(order.tipAmount)}',
                    false,
                    color: BC.gold,
                  ),
                ],
                const Divider(height: 16, color: BC.divider),
                _TotalRow(
                  'Grand Total',
                  '₹ ${fmtFn(order.grandTotal)}',
                  true,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: BC.divider),

          // ── Payment info ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: BC.surfaceAlt,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      order.paymentMode?.emoji ?? '💵',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Paid via ${order.paymentMode?.label ?? "Cash"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BC.textPri,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: BC.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✓ PAID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: BC.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.paymentRef != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      Text(
                        'Ref: ${order.paymentRef}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: BC.textMute,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: BC.textMute,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Served by ${order.createdByName}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: BC.textMute,
                      ),
                    ),
                    if (order.paidByName != null) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(color: BC.textMute, fontSize: 10),
                      ),
                      Text(
                        'Billed by ${order.paidByName}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: BC.textMute,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for dining with us! 🙏',
                  style: TextStyle(
                    fontSize: 13,
                    color: BC.textSec,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item row ──────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final String Function(double) fmtFn;

  const _ItemRow({required this.item, required this.fmtFn});

  @override
  Widget build(BuildContext context) {
    final vegColor =
        item.isVeg ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Veg dot
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 6),
            child: Container(
              width: 10,
              height: 10,
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
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BC.textPri,
                  ),
                ),
                Text(
                  '₹${fmtFn(item.itemPrice)} each',
                  style: const TextStyle(fontSize: 10, color: BC.textMute),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '×${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BC.textSec,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '₹${fmtFn(item.subtotal)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BC.textPri,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Total row ─────────────────────────────────────────────────
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow(this.label, this.value, this.bold, {this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: bold ? 15 : 12,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
          color: bold ? BC.textPri : BC.textSec,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 18 : 13,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          color: color ?? (bold ? BC.primary : BC.textSec),
        ),
      ),
    ],
  );
}

// ── Info chip ─────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ── Action button ─────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    ),
  );
}

// ── Big action button ─────────────────────────────────────────
class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.6),
            ),
          ),
        ],
      ),
    ),
  );
}