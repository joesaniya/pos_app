import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  ADD / EDIT TABLE SHEET
// ─────────────────────────────────────────────────────────────
class AddEditTableSheet extends StatefulWidget {
  final TablesProvider provider;
  final RestaurantTable? editTable;
  const AddEditTableSheet({super.key, required this.provider, this.editTable});
  @override
  State<AddEditTableSheet> createState() => _AddEditTableSheetState();
}

class _AddEditTableSheetState extends State<AddEditTableSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _capacity;
  late TableSection _section;
  late TableShape _shape;
  late bool _hasWindow, _isPremium;
  bool _isLoading = false;
  bool get isEdit => widget.editTable != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editTable;
    _capacity = e?.capacity ?? 4;
    _section = e?.section ?? TableSection.ac;
    _shape = e?.shape ?? TableShape.square;
    _hasWindow = e?.hasWindow ?? false;
    _isPremium = e?.isPremium ?? false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final table = RestaurantTable(
      id: widget.editTable?.id ?? widget.provider.generateId(),
      tableNumber: widget.editTable?.tableNumber ?? widget.provider.nextTableNumber(),
      capacity: _capacity,
      status: widget.editTable?.status ?? TableStatus.available,
      section: _section,
      shape: _shape,
      hasWindow: _hasWindow,
      isPremium: _isPremium,
      currentCustomerName: widget.editTable?.currentCustomerName,
      currentOrderId: widget.editTable?.currentOrderId,
      currentOrderTotal: widget.editTable?.currentOrderTotal,
      occupiedSince: widget.editTable?.occupiedSince,
      reservation: widget.editTable?.reservation,
    );
    isEdit
        ? await widget.provider.updateTable(table)
        : await widget.provider.addTable(table);
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
              emoji: isEdit ? '✏️' : '➕',
              title: isEdit ? 'Edit Table' : 'Add New Table',
              subtitle: isEdit ? 'Update table configuration' : 'Configure the new table',
              color: TC.accent,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Section',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TableSection.values.map((s) {
                        final isSel = _section == s;
                        final col = sectionColor(s);
                        final bg = sectionBg(s);
                        return GestureDetector(
                          onTap: () => setState(() => _section = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? bg : TC.surfaceWarm,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? col : TC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? col : TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Seating Capacity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [2, 4, 6, 8, 10, 12].map((n) {
                        final isSel = _capacity == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _capacity = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.accent : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
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
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Table Shape',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: TableShape.values.map((s) {
                        final isSel = _shape == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _shape = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? TC.accentLight : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                s.name.capitalize(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? TC.accent : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    ToggleRow(
                      label: 'Window View',
                      subtitle: 'Table has a window or scenic view',
                      emoji: '🪟',
                      value: _hasWindow,
                      onChanged: (v) => setState(() => _hasWindow = v),
                    ),
                    const Divider(height: 1, color: TC.divider),
                    ToggleRow(
                      label: 'Premium Table',
                      subtitle: 'Marks this as a premium / special table',
                      emoji: '⭐',
                      value: _isPremium,
                      onChanged: (v) => setState(() => _isPremium = v),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (isEdit) ...[
                          OutlineBtn(
                            label: 'Delete',
                            color: const Color(0xFFDC2626),
                            onTap: () => _confirmDelete(context),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TC.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              isEdit ? 'Save Changes' : 'Add Table',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${widget.editTable!.tableName}?',
          style: const TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: const Text(
          'This will permanently remove the table.',
          style: TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteTable(widget.editTable!.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}