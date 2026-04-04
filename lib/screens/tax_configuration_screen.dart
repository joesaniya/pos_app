import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/providers/tax_provider.dart';
import 'package:pos_app/services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM SNACKBAR HELPER
// ─────────────────────────────────────────────────────────────────────────────

void showCustomSnackBar(
  BuildContext context, {
  required String message,
  required bool isSuccess,
}) {
  // Remove any existing snackbar
  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
      elevation: 6,
    ),
  );
}

class TaxConfigurationScreen extends StatefulWidget {
  const TaxConfigurationScreen({super.key});

  @override
  State<TaxConfigurationScreen> createState() => _TaxConfigurationScreenState();
}

class _TaxConfigurationScreenState extends State<TaxConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _TaxSlabFormDialog(
          taxSlab: null,
          onSave: (name, percentage, type, description, taxNumber) =>
              _createTaxSlab(
                dialogContext,
                name,
                percentage,
                type,
                description,
                taxNumber,
              ),
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, TaxSlab taxSlab) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _TaxSlabFormDialog(
          taxSlab: taxSlab,
          onSave: (name, percentage, type, description, taxNumber) =>
              _updateTaxSlab(
                dialogContext,
                taxSlab,
                name,
                percentage,
                type,
                description,
                taxNumber,
              ),
        ),
      );
    }
  }

  Future<void> _createTaxSlab(
    BuildContext dialogContext,
    String name,
    double percentage,
    TaxType type,
    String? description,
    String taxNumber,
  ) async {
    // Get screen context for snackbar (not dialog context)
    final screenContext = context;
    final provider = screenContext.read<TaxProvider>();

    try {
      final created = await provider.createTaxSlab(
        name: name,
        percentage: percentage,
        type: type,
        description: description,
        taxNumber: taxNumber,
      );

      if (!mounted) return;

      if (created != null) {
        // Success: close dialog then show snackbar
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showCustomSnackBar(
              screenContext,
              message: 'Tax slab "$name" created successfully',
              isSuccess: true,
            );
          }
        });
      } else {
        // Error: keep dialog open, show error snackbar
        final errorMsg = provider.error ?? 'Failed to create tax slab';
        log('Error creating tax slab: $errorMsg');
        if (mounted) {
          showCustomSnackBar(
            screenContext,
            message: errorMsg,
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      log('Exception creating tax slab: $e');
      if (mounted) {
        showCustomSnackBar(
          screenContext,
          message: 'An error occurred: $e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _updateTaxSlab(
    BuildContext dialogContext,
    TaxSlab taxSlab,
    String name,
    double percentage,
    TaxType type,
    String? description,
    String taxNumber,
  ) async {
    // Get screen context for snackbar (not dialog context)
    final screenContext = context;
    final provider = screenContext.read<TaxProvider>();

    try {
      final updated = await provider.updateTaxSlab(
        taxSlab: taxSlab,
        name: name,
        percentage: percentage,
        type: type,
        description: description,
        taxNumber: taxNumber,
      );

      if (!mounted) return;

      if (updated != null) {
        // Success: close dialog then show snackbar
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showCustomSnackBar(
              screenContext,
              message: 'Tax slab "$name" updated successfully',
              isSuccess: true,
            );
          }
        });
      } else {
        // Error: keep dialog open, show error snackbar
        final errorMsg = provider.error ?? 'Failed to update tax slab';
        log('Error updating tax slab: $errorMsg');
        if (mounted) {
          showCustomSnackBar(
            screenContext,
            message: errorMsg,
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      log('Exception updating tax slab: $e');
      if (mounted) {
        showCustomSnackBar(
          screenContext,
          message: 'An error occurred: $e',
          isSuccess: false,
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
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
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
                  color: Colors.orange.withValues(alpha: 0.2),
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
        color: color.withValues(alpha: 0.2),
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
  final Function(String, double, TaxType, String?, String) onSave;

  const _TaxSlabFormDialog({required this.taxSlab, required this.onSave});

  @override
  State<_TaxSlabFormDialog> createState() => _TaxSlabFormDialogState();
}

class _TaxSlabFormDialogState extends State<_TaxSlabFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _percentageController;
  late TextEditingController _descriptionController;
  late TextEditingController _taxNumberController;
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
    _taxNumberController = TextEditingController(
      text: widget.taxSlab?.taxNumber ?? '',
    );
    _selectedType = widget.taxSlab?.type ?? TaxType.exclusive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.taxSlab == null ? 'Create Tax Slab' : 'Edit Tax Slab',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              initialValue: _selectedType,
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
                color: Colors.blue.withValues(alpha: 0.1),
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

            // Tax Number/License field
            TextFormField(
              controller: _taxNumberController,
              decoration: const InputDecoration(
                labelText: 'Tax ID/License Number',
                hintText: 'e.g., GST123456789',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Tax ID/License Number is required';
                }
                return null;
              },
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
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: Text(widget.taxSlab == null ? 'Create' : 'Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
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
      final taxNumber = _taxNumberController.text.trim();

      // Call the async onSave callback
      // The dialog will be closed only on success by the callback
      widget.onSave(name, percentage, type, description, taxNumber);
    }
  }
}
