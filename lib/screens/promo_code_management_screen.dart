// lib/screens/promo_code_management_screen.dart
// Admin screen for managing promo codes (creation, editing, deletion)

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/providers/promo_code_provider.dart';
import 'package:pos_app/utils/promo_code_access_control.dart';
import 'package:pos_app/utils/promo_code_validator.dart';
import 'package:provider/provider.dart';

// ══════════════════════════════════════════════════════════════
//  PROMO CODE MANAGEMENT SCREEN
// ══════════════════════════════════════════════════════════════

class PromoCodeManagementScreen extends StatefulWidget {
  final String businessId;
  final String? userId;
  final String? userRole;

  const PromoCodeManagementScreen({
    Key? key,
    required this.businessId,
    this.userId,
    this.userRole,
  }) : super(key: key);

  @override
  State<PromoCodeManagementScreen> createState() =>
      _PromoCodeManagementScreenState();
}

class _PromoCodeManagementScreenState extends State<PromoCodeManagementScreen> {
  late PromoCodeProvider _provider;
  bool _showActive = true;

  @override
  void initState() {
    super.initState();

    // ─ RBAC: Validate user role for promo management access
    if (!PromoCodeAccessControl.canManagePromoCodes(widget.userRole)) {
      log('[PromoCodeManagementScreen] ❌ UNAUTHORIZED ACCESS ATTEMPT');
      PromoCodeAccessControl.logAccessAttempt(
        widget.userRole,
        'direct_screen_access_denied',
        false,
      );

      // Redirect to previous screen with error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                PromoCodeAccessControl.getAccessDeniedReason(widget.userRole),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    log(
      '[PromoCodeManagementScreen] ✅ Access granted for role: ${widget.userRole}',
    );
    PromoCodeAccessControl.logAccessAttempt(
      widget.userRole,
      'promo_management_screen_opened',
      true,
    );

    // ─ CREATE PROVIDER LOCALLY (not from tree)
    _provider = PromoCodeProvider();
    _loadPromoCodess();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _loadPromoCodess() {
    _provider.loadPromoCodesByBusiness(widget.businessId);
  }

  void _navigateToCreateScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromoCodeFormScreen(
          businessId: widget.businessId,
          userId: widget.userId ?? '',
          isEdit: false,
        ),
      ),
    ).then((result) {
      if (result == true) _loadPromoCodess();
    });
  }

  void _navigateToEditScreen(PromoCode promoCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromoCodeFormScreen(
          businessId: widget.businessId,
          userId: widget.userId ?? '',
          isEdit: true,
          promoCode: promoCode,
        ),
      ),
    ).then((result) {
      if (result == true) _loadPromoCodess();
    });
  }

  void _confirmDelete(PromoCode promoCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promo Code'),
        content: Text(
          'Are you sure you want to delete promo code "${promoCode.code}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _provider.deletePromoCode(promoCode.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Promo code deleted successfully'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Codes'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadPromoCodess,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // For management screen, show all codes regardless of validity
          final allCodes = _provider.promoCodes;

          // Filter by active/expired status
          final filteredCodes = _showActive
              ? allCodes.where((p) => p.isActive).toList()
              : allCodes.where((p) => !p.isActive).toList();

          if (filteredCodes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showActive
                        ? 'No active promo codes'
                        : 'No inactive promo codes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToCreateScreen,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Promo Code'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // ─ Filter chips
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text(
                          'Active (${allCodes.where((p) => p.isActive).length})',
                        ),
                        selected: _showActive,
                        onSelected: (selected) {
                          setState(() => _showActive = true);
                        },
                      ),
                      FilterChip(
                        label: Text(
                          'Inactive (${allCodes.where((p) => !p.isActive).length})',
                        ),
                        selected: !_showActive,
                        onSelected: (selected) {
                          setState(() => _showActive = false);
                        },
                      ),
                    ],
                  ),
                ),

                // ─ Promo code list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCodes.length,
                  itemBuilder: (context, index) {
                    final promo = filteredCodes[index];
                    log(
                      'Rendering promo code: ${promo.code} (Active: ${promo.isActive})',
                    );
                    return PromoCodeCard(
                      promoCode: promo,
                      onEdit: () => _navigateToEditScreen(promo),
                      onDelete: () => _confirmDelete(promo),
                      onToggle: (isActive) async {
                        await _provider.togglePromoCodeStatus(
                          promo.id,
                          isActive,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateScreen,
        tooltip: 'Add new promo code',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE CARD
// ══════════════════════════════════════════════════════════════

class PromoCodeCard extends StatelessWidget {
  final PromoCode promoCode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const PromoCodeCard({
    Key? key,
    required this.promoCode,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    log('promo:${promoCode.isActive}');
    final isExpired = !promoCode.isValid;
    final displayText = promoCode.displayText;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ Header: Code + Status badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promoCode.code,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // if (isExpired)
                  promoCode.isActive != true
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Expired',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ─ Details grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: [
                  _DetailItem(
                    label: 'Type',
                    value: promoCode.discountType.label,
                    icon: Icons.percent,
                  ),
                  _DetailItem(
                    label: 'Min Order',
                    value: promoCode.minOrderValue > 0
                        ? '₹${promoCode.minOrderValue.toStringAsFixed(2)}'
                        : 'None',
                    icon: Icons.money,
                  ),
                  _DetailItem(
                    label: 'Valid From',
                    value: DateFormat('dd/MM/yy').format(promoCode.startDate),
                    icon: Icons.calendar_today,
                  ),
                  _DetailItem(
                    label: 'Expires',
                    value: DateFormat('dd/MM/yy').format(promoCode.expiryDate),
                    icon: Icons.event_busy,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─ Customer-specific info
              if (promoCode.customerId != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '👤 Customer-specific coupon',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ─ Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DETAIL ITEM WIDGET
// ══════════════════════════════════════════════════════════════

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CODE FORM SCREEN
// ══════════════════════════════════════════════════════════════

class PromoCodeFormScreen extends StatefulWidget {
  final String businessId;
  final String userId;
  final bool isEdit;
  final PromoCode? promoCode;

  const PromoCodeFormScreen({
    Key? key,
    required this.businessId,
    required this.userId,
    required this.isEdit,
    this.promoCode,
  }) : super(key: key);

  @override
  State<PromoCodeFormScreen> createState() => _PromoCodeFormScreenState();
}

class _PromoCodeFormScreenState extends State<PromoCodeFormScreen> {
  late TextEditingController _codeCtrl;
  late TextEditingController _discountValueCtrl;
  late TextEditingController _minOrderValueCtrl;
  late TextEditingController _customerIdCtrl;

  late DiscountType _selectedDiscountType;
  late DateTime _startDate;
  late DateTime _expiryDate;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.isEdit && widget.promoCode != null) {
      final promo = widget.promoCode!;
      _codeCtrl = TextEditingController(text: promo.code);
      _discountValueCtrl = TextEditingController(
        text: promo.discountValue.toString(),
      );
      _minOrderValueCtrl = TextEditingController(
        text: promo.minOrderValue.toString(),
      );
      _customerIdCtrl = TextEditingController(text: promo.customerId ?? '');
      _selectedDiscountType = promo.discountType;
      _startDate = promo.startDate;
      _expiryDate = promo.expiryDate;
    } else {
      _codeCtrl = TextEditingController();
      _discountValueCtrl = TextEditingController();
      _minOrderValueCtrl = TextEditingController(text: '0');
      _customerIdCtrl = TextEditingController();
      _selectedDiscountType = DiscountType.percentage;
      _startDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => _startDate = selected);
    }
  }

  Future<void> _selectExpiryDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => _expiryDate = selected);
    }
  }

  void _validateAndSave() async {
    setState(() => _error = null);

    // Validate inputs
    if (_codeCtrl.text.isEmpty) {
      setState(() => _error = 'Promo code cannot be empty');
      return;
    }

    if (_discountValueCtrl.text.isEmpty) {
      setState(() => _error = 'Discount value cannot be empty');
      return;
    }

    if (_startDate.isAfter(_expiryDate)) {
      setState(() => _error = 'Start date must be before expiry date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<PromoCodeProvider>();

      if (widget.isEdit && widget.promoCode != null) {
        // Update existing promo code
        final success = await provider.updatePromoCode(widget.promoCode!.id, {
          'code': _codeCtrl.text.toUpperCase().trim(),
          'discount_type': _selectedDiscountType.value,
          'discount_value': double.parse(_discountValueCtrl.text),
          'min_order_value': double.parse(_minOrderValueCtrl.text),
          'start_date': _startDate.toIso8601String(),
          'expiry_date': _expiryDate.toIso8601String(),
          'customer_id': _customerIdCtrl.text.trim().isEmpty
              ? null
              : _customerIdCtrl.text.trim(),
        });
        log('Update result: $success');
        if (success) {
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        // Create new promo code
        final result = await provider.createPromoCode(
          businessId: widget.businessId,
          code: _codeCtrl.text,
          discountType: _selectedDiscountType.value,
          discountValue: double.parse(_discountValueCtrl.text),
          minOrderValue: double.parse(_minOrderValueCtrl.text),
          startDate: _startDate,
          expiryDate: _expiryDate,
          createdBy: widget.userId,
          customerId: _customerIdCtrl.text.trim().isEmpty
              ? null
              : _customerIdCtrl.text.trim(),
        );
        log('Create result: $result');
        if (result != null && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      log('Error saving promo code: $e');
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _discountValueCtrl.dispose();
    _minOrderValueCtrl.dispose();
    _customerIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Promo Code' : 'Create Promo Code'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─ Code field
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Promo Code',
                hintText: 'e.g., SAVE20',
                helperText: 'Alphanumeric, no spaces',
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !widget.isEdit,
            ),
            const SizedBox(height: 16),

            // ─ Discount type and value
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DiscountType>(
                    value: _selectedDiscountType,
                    decoration: const InputDecoration(
                      labelText: 'Discount Type',
                    ),
                    items: DiscountType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (type) {
                      if (type != null) {
                        setState(() => _selectedDiscountType = type);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _discountValueCtrl,
                    decoration: InputDecoration(
                      labelText: 'Discount Value',
                      suffixText: _selectedDiscountType.symbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─ Minimum order value
            TextFormField(
              controller: _minOrderValueCtrl,
              decoration: const InputDecoration(
                labelText: 'Minimum Order Value (₹)',
                helperText: 'Optional - Leave 0 if no minimum',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),

            // ─ Dates
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                    subtitle: const Text('Start Date'),
                    onTap: _selectStartDate,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(DateFormat('dd/MM/yyyy').format(_expiryDate)),
                    subtitle: const Text('Expiry Date'),
                    onTap: _selectExpiryDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─ Customer ID (optional)
            TextFormField(
              controller: _customerIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer ID (Optional)',
                helperText:
                    'Leave empty to make it available for all customers',
              ),
            ),
            const SizedBox(height: 24),

            // ─ Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─ Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _validateAndSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEdit
                            ? 'Update Promo Code'
                            : 'Create Promo Code',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
