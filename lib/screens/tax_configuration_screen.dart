import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/providers/tax_provider.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:pos_app/theme/app_colors.dart';

class TaxConfigurationScreen extends StatefulWidget {
  const TaxConfigurationScreen({Key? key}) : super(key: key);

  @override
  State<TaxConfigurationScreen> createState() => _TaxConfigurationScreenState();
}

class _TaxConfigurationScreenState extends State<TaxConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showInactive = false;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize provider and load tax slabs
    Future.microtask(() async {
      // Get role from local storage
      final userData = await StorageService.instance.getUserData();
      _userRole = userData['role'] as String;
      log('User role loaded: $_userRole');

      final provider = context.read<TaxProvider>();
      await provider.init(); // Load businessId and user context from storage
      await provider.loadAllTaxSlabs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Configuration'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Taxes'),
            Tab(text: 'All Taxes'),
          ],
        ),
      ),
      body: Consumer<TaxProvider>(
        builder: (context, provider, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Active Taxes Tab
              _buildTaxList(
                context,
                provider.activeTaxSlabs,
                "No active tax slabs",
              ),
              // All Taxes Tab
              _buildTaxList(context, provider.taxSlabs, "No tax slabs"),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildTaxList(
    BuildContext context,
    List<TaxSlab> taxSlabs,
    String emptyMessage,
  ) {
    if (taxSlabs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<TaxProvider>().loadAllTaxSlabs(),
      child: ListView.builder(
        itemCount: taxSlabs.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final tax = taxSlabs[index];
          return _TaxSlabCard(
            taxSlab: tax,
            onEdit: () => _showEditDialog(context, tax),
            onDelete: () => _showDeleteConfirmation(context, tax),
            onToggle: () => _toggleTaxStatus(context, tax),
          );
        },
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    final provider = context.watch<TaxProvider>();

    // Only show FAB if user is owner or manager
    return FloatingActionButton(
      onPressed: provider.businessId.isEmpty
          ? null
          : () => _showCreateDialog(context),

      tooltip: 'Add Tax Slab',
      child: const Icon(Icons.add),
    );
  }

  void _showCreateDialog(BuildContext context) {
    log('Opening create tax slab dialog');
    showDialog(
      context: context,
      builder: (dialogContext) => _TaxSlabFormDialog(
        taxSlab: null,
        onSave: (name, percentage, type, description) =>
            _createTaxSlab(context, name, percentage, type, description),
      ),
    );
  }

  void _showEditDialog(BuildContext context, TaxSlab taxSlab) {
    showDialog(
      context: context,
      builder: (dialogContext) => _TaxSlabFormDialog(
        taxSlab: taxSlab,
        onSave: (name, percentage, type, description) => _updateTaxSlab(
          context,
          taxSlab,
          name,
          percentage,
          type,
          description,
        ),
      ),
    );
  }

  Future<void> _createTaxSlab(
    BuildContext context,
    String name,
    double percentage,
    TaxType type,
    String? description,
  ) async {
    // Close dialog first
    Navigator.of(context).pop();

    final provider = context.read<TaxProvider>();
    final created = await provider.createTaxSlab(
      name: name,
      percentage: percentage,
      type: type,
      description: description,
    );

    if (mounted) {
      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tax slab "$name" created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.error != null) {
        log('Error creating tax slab: ${provider.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${provider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaxSlab(
    BuildContext context,
    TaxSlab taxSlab,
    String name,
    double percentage,
    TaxType type,
    String? description,
  ) async {
    // Close dialog first
    Navigator.of(context).pop();

    final provider = context.read<TaxProvider>();
    final updated = await provider.updateTaxSlab(
      taxSlab: taxSlab,
      name: name,
      percentage: percentage,
      type: type,
      description: description,
    );

    if (mounted) {
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tax slab "$name" updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${provider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleTaxStatus(BuildContext context, TaxSlab taxSlab) {
    final provider = context.read<TaxProvider>();
    provider.toggleTaxSlabStatus(
      taxSlabId: taxSlab.id,
      isActive: !taxSlab.isActive,
    );
  }

  void _showDeleteConfirmation(BuildContext context, TaxSlab taxSlab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tax Slab'),
        content: Text('Are you sure you want to delete "${taxSlab.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaxProvider>().deleteTaxSlab(taxSlab.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tax slab deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SLAB CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TaxSlabCard extends StatelessWidget {
  final TaxSlab taxSlab;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _TaxSlabCard({
    required this.taxSlab,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: taxSlab.isActive
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${taxSlab.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: taxSlab.isActive ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ),
        title: Text(
          taxSlab.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: taxSlab.isActive ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Row(
          children: [
            _TaxTypeBadge(type: taxSlab.type),
            const SizedBox(width: 8),
            if (!taxSlab.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'toggle':
                onToggle();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    taxSlab.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(taxSlab.isActive ? 'Disable' : 'Enable'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX TYPE BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _TaxTypeBadge extends StatelessWidget {
  final TaxType type;

  const _TaxTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == TaxType.inclusive ? Colors.blue : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SLAB FORM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _TaxSlabFormDialog extends StatefulWidget {
  final TaxSlab? taxSlab;
  final Function(String, double, TaxType, String?) onSave;

  const _TaxSlabFormDialog({required this.taxSlab, required this.onSave});

  @override
  State<_TaxSlabFormDialog> createState() => _TaxSlabFormDialogState();
}

class _TaxSlabFormDialogState extends State<_TaxSlabFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _percentageController;
  late TextEditingController _descriptionController;
  late TaxType _selectedType;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nameController = TextEditingController(text: widget.taxSlab?.name ?? '');
    _percentageController = TextEditingController(
      text: widget.taxSlab?.percentage.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.taxSlab?.description ?? '',
    );
    _selectedType = widget.taxSlab?.type ?? TaxType.exclusive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.taxSlab == null ? 'Create Tax Slab' : 'Edit Tax Slab'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tax Name',
                hintText: 'e.g., GST 18%',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Tax name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Percentage field
            TextFormField(
              controller: _percentageController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tax Percentage',
                hintText: 'e.g., 18',
                suffix: Text('%'),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Percentage is required';
                }
                final percent = double.tryParse(value!);
                if (percent == null || percent < 0 || percent > 100) {
                  return 'Percentage must be between 0 and 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tax Type dropdown
            DropdownButtonFormField<TaxType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tax Type',
                border: OutlineInputBorder(),
              ),
              items: TaxType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? TaxType.exclusive;
                });
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedType == TaxType.exclusive
                    ? 'Tax will be added on top of the item price'
                    : 'Tax is already included in the item price',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add any notes...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.taxSlab == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final percentage = double.parse(_percentageController.text);
      final type = _selectedType;
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      widget.onSave(name, percentage, type, description);
      Navigator.pop(context);
    }
  }
}
