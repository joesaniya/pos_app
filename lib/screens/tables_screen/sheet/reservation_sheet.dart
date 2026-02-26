import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  RESERVATION SHEET  (add / edit)
// ─────────────────────────────────────────────────────────────
class ReservationSheet extends StatefulWidget {
  final String tableId;
  final TablesProvider provider;
  final Reservation? existing;
  const ReservationSheet({
    super.key,
    required this.tableId,
    required this.provider,
    this.existing,
  });
  @override
  State<ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<ReservationSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _phoneCtrl, _notesCtrl;
  late int _guestCount;
  late DateTime _checkIn;
  DateTime? _checkOut;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _availError;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _guestCount = e?.guestCount ?? 2;
    _checkIn = e?.reservedFor ??
        DateTime.now()
            .add(const Duration(hours: 1))
            .copyWith(second: 0, microsecond: 0, millisecond: 0);
    _checkOut = e?.checkOut ?? _checkIn.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isCheckIn ? _checkIn : (_checkOut ?? _checkIn)),
    );
    if (t != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = DateTime(_checkIn.year, _checkIn.month, _checkIn.day, t.hour, t.minute);
        } else {
          final base = _checkOut ?? _checkIn;
          _checkOut = DateTime(base.year, base.month, base.day, t.hour, t.minute);
        }
        _availError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) {
      setState(() {
        _checkIn = DateTime(d.year, d.month, d.day, _checkIn.hour, _checkIn.minute);
        if (_checkOut != null) {
          _checkOut = DateTime(d.year, d.month, d.day, _checkOut!.hour, _checkOut!.minute);
        }
      });
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isChecking = true;
      _availError = null;
    });
    final available = await widget.provider.checkAvailability(
      tableId: widget.tableId,
      checkIn: _checkIn,
      checkOut: _checkOut ?? _checkIn.add(const Duration(hours: 2)),
      excludeReservationId: widget.existing?.id,
    );
    setState(() => _isChecking = false);
    if (!available) {
      setState(() => _availError =
          'This table already has a booking during that time. Choose a different slot.');
      return;
    }

    setState(() => _isLoading = true);
    final res = Reservation(
      id: widget.existing?.id ?? 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _checkIn,
      checkOut: _checkOut,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    isEdit
        ? await widget.provider.updateReservation(widget.tableId, res)
        : await widget.provider.addReservation(widget.tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            SheetTopBar(
              emoji: '📅',
              title: isEdit ? 'Edit Reservation' : 'New Reservation',
              subtitle: isEdit ? 'Update details below' : 'Reserve this table for a guest',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormFieldWidget(
                      label: 'Guest Name *',
                      hint: 'Enter full name',
                      controller: _nameCtrl,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    FormFieldWidget(
                      label: 'Phone Number',
                      hint: '+91 98765 43210',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Party Size',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(8, (i) {
                        final n = i + 1;
                        final isSel = _guestCount == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _guestCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Date *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TC.border),
                        ),
                        child: Row(
                          children: [
                            const Text('📅', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_checkIn),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TC.textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Check-in & Check-out *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _timePickerTile(true)),
                        const SizedBox(width: 10),
                        Expanded(child: _timePickerTile(false)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quick Duration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DurationChips(
                      checkIn: _checkIn,
                      checkOut: _checkOut,
                      onCheckOutChanged: (t) => setState(() {
                        _checkOut = t;
                        _availError = null;
                      }),
                    ),
                    if (_availError != null) ...[
                      const SizedBox(height: 8),
                      _AvailErrorBox(message: _availError!),
                    ],
                    const SizedBox(height: 14),
                    FormFieldWidget(
                      label: 'Special Notes',
                      hint: 'Birthday, anniversary, dietary needs...',
                      controller: _notesCtrl,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isChecking) ? null : _checkAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isChecking)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isEdit ? 'Update Reservation' : 'Confirm Reservation',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerTile(bool isCheckIn) {
    final label = isCheckIn ? 'Check-in' : 'Check-out';
    final emoji = isCheckIn ? '🟢' : '🔴';
    final time = isCheckIn ? _checkIn : _checkOut;
    return GestureDetector(
      onTap: () => _pickTime(isCheckIn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: TC.textMute)),
                Text(
                  time != null ? _fmtTime(time) : 'Optional',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: time != null ? TC.textPri : TC.textMute,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rDate = DateTime(dt.year, dt.month, dt.day);
    if (rDate == today) return 'Today';
    if (rDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[dt.month - 1]} ${dt.day}';
  }
}

class _AvailErrorBox extends StatelessWidget {
  final String message;
  const _AvailErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TC.occupiedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TC.occupied.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: TC.occupied, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}