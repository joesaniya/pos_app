import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  CALENDAR QUICK-RESERVE SHEET
// ─────────────────────────────────────────────────────────────
class CalendarReserveSheet extends StatefulWidget {
  final TablesProvider provider;
  final List<RestaurantTable> availableTables;
  final DateTime initialDate;
  const CalendarReserveSheet({
    super.key,
    required this.provider,
    required this.availableTables,
    required this.initialDate,
  });
  @override
  State<CalendarReserveSheet> createState() => _CalendarReserveSheetState();
}

class _CalendarReserveSheetState extends State<CalendarReserveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _tableId;
  int _guestCount = 2;
  late DateTime _checkIn;
  DateTime? _checkOut;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _availError;
  String? _pastError;

  @override
  void initState() {
    super.initState();
    _tableId = widget.availableTables.first.id;
    final d = widget.initialDate;

    // ── FIX: Use DateTime.now().add() to safely get +1 hour without
    //         rolling over midnight or the date boundary.
    final defaultCheckIn = DateTime.now()
        .add(const Duration(hours: 1))
        .copyWith(second: 0, millisecond: 0, microsecond: 0);

    // Keep the selected calendar date but use the safe hour/minute
    _checkIn = DateTime(
      d.year,
      d.month,
      d.day,
      defaultCheckIn.hour,
      defaultCheckIn.minute,
    );

    // ── FIX: Add duration to _checkIn so checkout never crosses
    //         midnight on the wrong date.
    _checkOut = _checkIn.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _isPast(DateTime dt) => dt.isBefore(DateTime.now());

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid phone number (min 10 digits)';
    }
    return null;
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isCheckIn ? _checkIn : (_checkOut ?? _checkIn),
      ),
    );
    if (t != null) {
      setState(() {
        _pastError = null;
        _availError = null;
        if (isCheckIn) {
          final candidate = DateTime(
            _checkIn.year,
            _checkIn.month,
            _checkIn.day,
            t.hour,
            t.minute,
          );
          if (_isPast(candidate)) {
            final clamped = DateTime.now().add(const Duration(minutes: 5));
            _checkIn = clamped.copyWith(
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
            _pastError =
                'Check-in time cannot be in the past. Set to earliest available time.';
          } else {
            _checkIn = candidate;
          }
          // ── FIX: Recalculate checkout based on new check-in so it
          //         never ends up on the wrong date.
          if (_checkOut != null) {
            final duration = _checkOut!.difference(
              DateTime(
                _checkOut!.year,
                _checkOut!.month,
                _checkOut!.day,
                // old checkin hour/min — approximate duration preserved
                t.hour,
                t.minute,
              ),
            );
            _checkOut = _checkIn.add(
              duration.isNegative ? const Duration(hours: 2) : duration,
            );
          }
        } else {
          // Checkout time: keep same date as check-in to avoid rollover.
          // If chosen time is earlier than check-in, it means next day —
          // add 1 day automatically.
          DateTime candidate = DateTime(
            _checkIn.year,
            _checkIn.month,
            _checkIn.day,
            t.hour,
            t.minute,
          );
          if (!candidate.isAfter(_checkIn)) {
            candidate = candidate.add(const Duration(days: 1));
          }
          _checkOut = candidate;
        }
      });
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isPast(_checkIn)) {
      setState(
        () => _pastError =
            'Cannot reserve a past date or time. Please pick a future time.',
      );
      return;
    }
    setState(() {
      _isChecking = true;
      _availError = null;
    });

    final effectiveCheckOut =
        _checkOut ?? _checkIn.add(const Duration(hours: 2));

    log(
      'Checking availability for table $_tableId from $_checkIn to $effectiveCheckOut',
    );

    final available = await widget.provider.checkAvailability(
      tableId: _tableId,
      checkIn: _checkIn,
      checkOut: effectiveCheckOut,
    );

    setState(() => _isChecking = false);

    if (!available) {
      setState(
        () => _availError =
            'Table already booked for this time slot. Please choose another time.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _checkIn,
      checkOut: _checkOut,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.provider.addReservation(_tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
            const SheetTopBar(
              emoji: '📅',
              title: 'Quick Reserve',
              subtitle: 'Add a reservation for this date',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Table',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TableSelector(
                      tables: widget.availableTables,
                      selectedId: _tableId,
                      onChanged: (id) => setState(() {
                        _tableId = id;
                        _availError = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    FormFieldWidget(
                      label: 'Guest Name *',
                      hint: 'Full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    FormFieldWidget(
                      label: 'Phone',
                      hint: '+91 98765...',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _timeTile(true)),
                        const SizedBox(width: 10),
                        Expanded(child: _timeTile(false)),
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
                    if (_pastError != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: _pastError!),
                    ],
                    if (_availError != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: _availError!),
                    ],
                    const SizedBox(height: 12),
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
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    FormFieldWidget(
                      label: 'Notes',
                      hint: 'Special requests...',
                      controller: _noteCtrl,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isChecking)
                            ? null
                            : _checkAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isChecking)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Reservation',
                                style: TextStyle(
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
      ),
    );
  }

  Widget _timeTile(bool isCheckIn) {
    final label = isCheckIn ? 'Check-in *' : 'Check-out';
    final emoji = isCheckIn ? '🟢' : '🔴';
    final time = isCheckIn ? _checkIn : _checkOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
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
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  time != null ? _fmtTime(time) : 'Optional',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: time != null ? TC.textPri : TC.textMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ─────────────────────────────────────────────────────────────
class _TableSelector extends StatelessWidget {
  final List<RestaurantTable> tables;
  final String selectedId;
  final ValueChanged<String> onChanged;
  const _TableSelector({
    required this.tables,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tables.length,
        itemBuilder: (_, i) {
          final t = tables[i];
          final isSel = selectedId == t.id;
          final secCol = sectionColor(t.section);
          final secBg = sectionBg(t.section);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(t.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSel ? secBg : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? secCol : TC.border,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          t.section.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.tableName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSel ? secCol : TC.textSec,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· ${t.capacity}p',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel
                                ? secCol.withOpacity(0.7)
                                : TC.textMute,
                          ),
                        ),
                      ],
                    ),
                    if (t.status == TableStatus.reserved &&
                        t.reservation != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            size: 10,
                            color: TC.reserved.withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${t.reservation!.timeLabel}${t.reservation!.checkOut != null ? " – ${t.reservation!.checkOutTimeLabel}" : ""}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: TC.reserved,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ] else if (t.status == TableStatus.occupied) ...[
                      const SizedBox(height: 3),
                      const Row(
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 10,
                            color: TC.occupied,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Occupied now',
                            style: TextStyle(
                              fontSize: 9,
                              color: TC.occupied,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
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
              style: const TextStyle(
                fontSize: 12,
                color: TC.occupied,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/*import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';

import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  CALENDAR QUICK-RESERVE SHEET
// ─────────────────────────────────────────────────────────────
class CalendarReserveSheet extends StatefulWidget {
  final TablesProvider provider;
  final List<RestaurantTable> availableTables;
  final DateTime initialDate;
  const CalendarReserveSheet({
    super.key,
    required this.provider,
    required this.availableTables,
    required this.initialDate,
  });
  @override
  State<CalendarReserveSheet> createState() => _CalendarReserveSheetState();
}

class _CalendarReserveSheetState extends State<CalendarReserveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _tableId;
  int _guestCount = 2;
  late DateTime _checkIn;
  DateTime? _checkOut;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _availError;
  String? _pastError;

  @override
  void initState() {
    super.initState();
    _tableId = widget.availableTables.first.id;
    final d = widget.initialDate;
    _checkIn = DateTime(d.year, d.month, d.day, DateTime.now().hour + 1, 0);
    _checkOut = _checkIn.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _isPast(DateTime dt) => dt.isBefore(DateTime.now());

  // ── Phone validation: at least 10 digits ──────────────
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid phone number (min 10 digits)';
    }
    return null;
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isCheckIn ? _checkIn : (_checkOut ?? _checkIn),
      ),
    );
    if (t != null) {
      setState(() {
        _pastError = null;
        _availError = null;
        if (isCheckIn) {
          final candidate = DateTime(
            _checkIn.year,
            _checkIn.month,
            _checkIn.day,
            t.hour,
            t.minute,
          );
          if (_isPast(candidate)) {
            final clamped = DateTime.now().add(const Duration(minutes: 5));
            _checkIn = clamped.copyWith(
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
            _pastError =
                'Check-in time cannot be in the past. Set to earliest available time.';
          } else {
            _checkIn = candidate;
          }
        } else {
          final base = _checkOut ?? _checkIn;
          _checkOut = DateTime(
            base.year,
            base.month,
            base.day,
            t.hour,
            t.minute,
          );
        }
      });
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isPast(_checkIn)) {
      setState(
        () => _pastError =
            'Cannot reserve a past date or time. Please pick a future time.',
      );
      return;
    }
    setState(() {
      _isChecking = true;
      _availError = null;
    });
    log(
      'Checking availability for table $_tableId from $_checkIn to $_checkOut',
    );
    final available = await widget.provider.checkAvailability(
      tableId: _tableId,
      checkIn: _checkIn,
      checkOut: _checkOut ?? _checkIn.add(const Duration(hours: 2)),
    );

    setState(() => _isChecking = false);

    if (!available) {
      setState(
        () => _availError =
            'Table already booked for this time slot. Please choose another time.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _checkIn,
      checkOut: _checkOut,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.provider.addReservation(_tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
            const SheetTopBar(
              emoji: '📅',
              title: 'Quick Reserve',
              subtitle: 'Add a reservation for this date',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Table',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TableSelector(
                      tables: widget.availableTables,
                      selectedId: _tableId,
                      onChanged: (id) => setState(() {
                        _tableId = id;
                        _availError = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    FormFieldWidget(
                      label: 'Guest Name *',
                      hint: 'Full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    // ── Phone with 10-digit validation ─────────────────
                    FormFieldWidget(
                      label: 'Phone',
                      hint: '+91 98765...',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _timeTile(true)),
                        const SizedBox(width: 10),
                        Expanded(child: _timeTile(false)),
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
                    if (_pastError != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: _pastError!),
                    ],
                    if (_availError != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: _availError!),
                    ],
                    const SizedBox(height: 12),
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
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    FormFieldWidget(
                      label: 'Notes',
                      hint: 'Special requests...',
                      controller: _noteCtrl,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isChecking)
                            ? null
                            : _checkAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isChecking)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Reservation',
                                style: TextStyle(
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
      ),
    );
  }

  Widget _timeTile(bool isCheckIn) {
    final label = isCheckIn ? 'Check-in *' : 'Check-out';
    final emoji = isCheckIn ? '🟢' : '🔴';
    final time = isCheckIn ? _checkIn : _checkOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
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
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  time != null ? _fmtTime(time) : 'Optional',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: time != null ? TC.textPri : TC.textMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ─────────────────────────────────────────────────────────────
class _TableSelector extends StatelessWidget {
  final List<RestaurantTable> tables;
  final String selectedId;
  final ValueChanged<String> onChanged;
  const _TableSelector({
    required this.tables,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tables.length,
        itemBuilder: (_, i) {
          final t = tables[i];
          final isSel = selectedId == t.id;
          final secCol = sectionColor(t.section);
          final secBg = sectionBg(t.section);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(t.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSel ? secBg : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? secCol : TC.border,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          t.section.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.tableName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSel ? secCol : TC.textSec,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· ${t.capacity}p',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel
                                ? secCol.withOpacity(0.7)
                                : TC.textMute,
                          ),
                        ),
                      ],
                    ),
                    if (t.status == TableStatus.reserved &&
                        t.reservation != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            size: 10,
                            color: TC.reserved.withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${t.reservation!.timeLabel}${t.reservation!.checkOut != null ? " – ${t.reservation!.checkOutTimeLabel}" : ""}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: TC.reserved,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ] else if (t.status == TableStatus.occupied) ...[
                      const SizedBox(height: 3),
                      const Row(
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 10,
                            color: TC.occupied,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Occupied now',
                            style: TextStyle(
                              fontSize: 9,
                              color: TC.occupied,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
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
              style: const TextStyle(
                fontSize: 12,
                color: TC.occupied,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/