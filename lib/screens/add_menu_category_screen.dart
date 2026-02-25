// lib/screens/add_category_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

const List<String> _icons = [
  '🍽️', '🫓', '🍛', '🍳', '🍱', '🌙', '🧁', '🥤',
  '🍜', '🥘', '🫕', '🍕', '🌮', '🥗', '🥩', '🍗',
  '🦐', '🐟', '🥚', '🧆', '🧇', '🧈', '🥐', '🫔',
];

const List<Map<String, String>> _colorPresets = [
  {'name': 'Tomato',   'hex': 'E74C3C'},
  {'name': 'Orange',   'hex': 'E67E22'},
  {'name': 'Gold',     'hex': 'F1C40F'},
  {'name': 'Emerald',  'hex': '2ECC71'},
  {'name': 'Teal',     'hex': '1ABC9C'},
  {'name': 'Sky',      'hex': '3498DB'},
  {'name': 'Iris',     'hex': '9B59B6'},
  {'name': 'Rose',     'hex': 'E91E63'},
  {'name': 'Slate',    'hex': '607D8B'},
  {'name': 'Cocoa',    'hex': '795548'},
];

class AddCategoryScreen extends StatefulWidget {
  final String? editCategoryId; // null = create, non-null = edit

  const AddCategoryScreen({Key? key, this.editCategoryId}) : super(key: key);

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedIcon = '🍽️';
  String _selectedColorHex = 'E74C3C';
  File? _imageFile;
  bool _isSaving = false;

  bool get _isEdit => widget.editCategoryId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xFile != null) setState(() => _imageFile = File(xFile.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<SupabaseMenuProvider>();

      if (_isEdit) {
        await provider.updateCategory(
          id: widget.editCategoryId!,
          updates: {
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'icon': _selectedIcon,
            'color_hex': '#$_selectedColorHex',
          },
          imageFile: _imageFile,
          categoryName: _nameCtrl.text.trim(),
        );
      } else {
        await provider.createCategory(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          icon: _selectedIcon,
          colorHex: '#$_selectedColorHex',
          imageFile: _imageFile,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(int.parse('FF$_selectedColorHex', radix: 16));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Category' : 'New Category',
          style: AppTheme.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Preview Card ──────────────────────────────
              _PreviewCard(
                name: _nameCtrl.text.isEmpty ? 'Category Name' : _nameCtrl.text,
                icon: _selectedIcon,
                colorHex: _selectedColorHex,
                imageFile: _imageFile,
                onTap: _pickImage,
              ),
              const SizedBox(height: 24),

              // ── Name ──────────────────────────────────────
              _SectionTitle('Category Name'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec(
                  hint: 'e.g. Dosa, Curry, Breakfast',
                  icon: Icons.label_outline,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),

              const SizedBox(height: 20),

              // ── Description ───────────────────────────────
              _SectionTitle('Description (optional)'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _inputDec(
                  hint: 'Short description of this category',
                  icon: Icons.notes_rounded,
                ),
              ),

              const SizedBox(height: 24),

              // ── Icon picker ───────────────────────────────
              _SectionTitle('Choose Icon'),
              const SizedBox(height: 12),
              _IconPicker(
                selected: _selectedIcon,
                onSelected: (v) => setState(() => _selectedIcon = v),
              ),

              const SizedBox(height: 24),

              // ── Color picker ──────────────────────────────
              _SectionTitle('Choose Color'),
              const SizedBox(height: 12),
              _ColorPicker(
                selected: _selectedColorHex,
                onSelected: (v) => setState(() => _selectedColorHex = v),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFFAAAAAA)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.primaryPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE74C3C)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION TITLE
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF444444),
          letterSpacing: 0.2,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PREVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final String name;
  final String icon;
  final String colorHex;
  final File? imageFile;
  final VoidCallback onTap;

  const _PreviewCard({
    required this.name,
    required this.icon,
    required this.colorHex,
    this.imageFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = Color(int.parse('FF$colorHex', radix: 16));

    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [base, base.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageFile != null)
              Image.file(
                imageFile!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.25),
                colorBlendMode: BlendMode.darken,
              ),
            // Camera button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 18, color: Color(0xFF555555)),
                ),
              ),
            ),
            // Content
            Positioned(
              left: 20,
              bottom: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                        )
                      ],
                    ),
                  ),
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
//  ICON PICKER
// ─────────────────────────────────────────────────────────────────────────────
class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _IconPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _icons.map((emoji) {
        final isSel = emoji == selected;
        return GestureDetector(
          onTap: () => onSelected(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSel ? AppColors.primaryPurple : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel
                    ? AppColors.primaryPurple
                    : const Color(0xFFEEEEEE),
                width: isSel ? 2 : 1,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR PICKER
// ─────────────────────────────────────────────────────────────────────────────
class _ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ColorPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colorPresets.map((preset) {
        final hex = preset['hex']!;
        final color = Color(int.parse('FF$hex', radix: 16));
        final isSel = hex == selected;

        return GestureDetector(
          onTap: () => onSelected(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSel
                      ? color.withOpacity(0.5)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: isSel ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSel
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}