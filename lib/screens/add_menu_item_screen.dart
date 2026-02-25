

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/models/menu_item.dart';
import 'package:provider/provider.dart';

import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

const List<String> _knownAllergens = [
  'Dairy', 'Gluten', 'Nuts', 'Shellfish', 'Eggs', 'Soy', 'Fish',
];

class AddMenuItemScreen extends StatefulWidget {
  final SupabaseMenuCategory category;
  final SupabaseMenuItem? editItem; // null = create

  const AddMenuItemScreen({
    Key? key,
    required this.category,
    this.editItem,
  }) : super(key: key);

  @override
  State<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends State<AddMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _prepTimeCtrl = TextEditingController(text: '15');

  bool _isVeg = true;
  bool _isAvailable = true;
  bool _isBestSeller = false;
  bool _isFeatured = false;
  bool _isNewArrival = false;
  bool _isSpicy = false;
  double _rating = 4.0;
  final Set<String> _selectedAllergens = {};

  File? _imageFile;
  bool _isSaving = false;
  bool get _isEdit => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill(widget.editItem!);
  }

  void _prefill(SupabaseMenuItem item) {
    _nameCtrl.text = item.name;
    _descCtrl.text = item.description;
    _priceCtrl.text = item.price.toStringAsFixed(2);
    _discountCtrl.text = item.discountPrice?.toStringAsFixed(2) ?? '';
    _caloriesCtrl.text = item.calories?.toString() ?? '';
    _proteinCtrl.text = item.protein?.toString() ?? '';
    _carbsCtrl.text = item.carbs?.toString() ?? '';
    _fatCtrl.text = item.fat?.toString() ?? '';
    _ingredientsCtrl.text = item.ingredients.join(', ');
    _prepTimeCtrl.text = item.preparationTime.toString();
    _isVeg = item.isVeg;
    _isAvailable = item.isAvailable;
    _isBestSeller = item.isBestSeller;
    _isFeatured = item.isFeatured;
    _isNewArrival = item.isNewArrival;
    _isSpicy = item.isSpicy;
    _rating = item.rating;
    _selectedAllergens.addAll(item.allergens);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _priceCtrl, _discountCtrl,
      _caloriesCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl,
      _ingredientsCtrl, _prepTimeCtrl,
    ]) c.dispose();
    super.dispose();
  }

  List<String> get _ingredients => _ingredientsCtrl.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pickImage() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (xFile != null) setState(() => _imageFile = File(xFile.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<SupabaseMenuProvider>();
      final price = double.parse(_priceCtrl.text.trim());
      final discount = _discountCtrl.text.trim().isNotEmpty
          ? double.tryParse(_discountCtrl.text.trim())
          : null;

      if (_isEdit) {
        await provider.updateItem(
          id: widget.editItem!.id,
          categoryId: widget.category.id,
          updates: {
            'name': _nameCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'price': price,
            'discount_price': discount,
            'is_veg': _isVeg,
            'is_available': _isAvailable,
            'is_best_seller': _isBestSeller,
            'is_featured': _isFeatured,
            'is_new_arrival': _isNewArrival,
            'is_spicy': _isSpicy,
            'preparation_time': int.tryParse(_prepTimeCtrl.text) ?? 15,
            'calories': int.tryParse(_caloriesCtrl.text),
            'protein': double.tryParse(_proteinCtrl.text),
            'carbs': double.tryParse(_carbsCtrl.text),
            'fat': double.tryParse(_fatCtrl.text),
            'ingredients': _ingredients,
            'allergens': _selectedAllergens.toList(),
            'rating': _rating,
          },
          imageFile: _imageFile,
          itemName: _nameCtrl.text.trim(),
        );
      } else {
        await provider.createItem(
          categoryId: widget.category.id,
          name: _nameCtrl.text.trim(),
          price: price,
          isVeg: _isVeg,
          description: _descCtrl.text.trim(),
          discountPrice: discount,
          ingredients: _ingredients,
          allergens: _selectedAllergens.toList(),
          preparationTime: int.tryParse(_prepTimeCtrl.text) ?? 15,
          calories: int.tryParse(_caloriesCtrl.text),
          protein: double.tryParse(_proteinCtrl.text),
          carbs: double.tryParse(_carbsCtrl.text),
          fat: double.tryParse(_fatCtrl.text),
          isAvailable: _isAvailable,
          isBestSeller: _isBestSeller,
          isFeatured: _isFeatured,
          isNewArrival: _isNewArrival,
          isSpicy: _isSpicy,
          rating: _rating,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Item' : 'New Menu Item',
          style: AppTheme.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
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
              // Category chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.category.icon,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      widget.category.name,
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Image picker
              _ImagePickerSection(
                imageFile: _imageFile,
                existingUrl: _isEdit ? widget.editItem?.imageUrl : null,
                onTap: _pickImage,
              ),
              const SizedBox(height: 24),

              // Veg toggle
              _VegToggle(
                isVeg: _isVeg,
                onChanged: (v) => setState(() => _isVeg = v),
              ),
              const SizedBox(height: 20),

              // Name
              _label('Item Name *'),
              const SizedBox(height: 8),
              _textField(
                ctrl: _nameCtrl,
                hint: 'e.g. Masala Dosa',
                icon: Icons.fastfood_outlined,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Description
              _label('Description'),
              const SizedBox(height: 8),
              _textField(
                ctrl: _descCtrl,
                hint: 'Brief description of the dish',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Price row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Price (₹) *'),
                        const SizedBox(height: 8),
                        _textField(
                          ctrl: _priceCtrl,
                          hint: '0.00',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.trim()) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Discount (₹)'),
                        const SizedBox(height: 8),
                        _textField(
                          ctrl: _discountCtrl,
                          hint: 'Optional',
                          icon: Icons.local_offer_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prep time + rating
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Prep Time (min)'),
                        const SizedBox(height: 8),
                        _textField(
                          ctrl: _prepTimeCtrl,
                          hint: '15',
                          icon: Icons.timer_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Rating (0–5)'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.star,
                                  size: 18,
                                  color: Colors.amber.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Slider(
                                  value: _rating,
                                  min: 1,
                                  max: 5,
                                  divisions: 8,
                                  onChanged: (v) =>
                                      setState(() => _rating = v),
                                  activeColor: Colors.amber.shade600,
                                ),
                              ),
                              Text(
                                _rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nutrition
              _label('Nutrition Info (optional)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _miniField(_caloriesCtrl, 'kcal',
                        Icons.local_fire_department_outlined)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniField(
                        _proteinCtrl, 'Protein g', Icons.fitness_center),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniField(
                        _carbsCtrl, 'Carbs g', Icons.grain_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniField(
                        _fatCtrl, 'Fat g', Icons.water_drop_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ingredients
              _label('Ingredients (comma separated)'),
              const SizedBox(height: 8),
              _textField(
                ctrl: _ingredientsCtrl,
                hint: 'Rice batter, Potato, Onion...',
                icon: Icons.grass_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Allergens
              _label('Allergens'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _knownAllergens.map((a) {
                  final sel = _selectedAllergens.contains(a);
                  return FilterChip(
                    label: Text(a),
                    selected: sel,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedAllergens.add(a);
                        } else {
                          _selectedAllergens.remove(a);
                        }
                      });
                    },
                    selectedColor: const Color(0xFFFFE0B2),
                    checkmarkColor: const Color(0xFFE65100),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: sel
                          ? const Color(0xFFE65100)
                          : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: sel
                          ? const Color(0xFFE65100).withOpacity(0.5)
                          : const Color(0xFFEEEEEE),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Flags
              _label('Options'),
              const SizedBox(height: 12),
              _FlagsSection(
                isAvailable: _isAvailable,
                isBestSeller: _isBestSeller,
                isFeatured: _isFeatured,
                isNewArrival: _isNewArrival,
                isSpicy: _isSpicy,
                onAvailableChanged: (v) =>
                    setState(() => _isAvailable = v),
                onBestSellerChanged: (v) =>
                    setState(() => _isBestSeller = v),
                onFeaturedChanged: (v) =>
                    setState(() => _isFeatured = v),
                onNewArrivalChanged: (v) =>
                    setState(() => _isNewArrival = v),
                onSpicyChanged: (v) => setState(() => _isSpicy = v),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF444444),
        ),
      );

  Widget _textField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: capitalization,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFAAAAAA)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          borderSide: BorderSide(
              color: AppColors.primaryPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE74C3C)),
        ),
      ),
    );
  }

  Widget _miniField(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextFormField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 10),
        prefixIcon: Icon(icon, size: 14, color: const Color(0xFFAAAAAA)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.primaryPurple, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Veg Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _VegToggle extends StatelessWidget {
  final bool isVeg;
  final ValueChanged<bool> onChanged;

  const _VegToggle({required this.isVeg, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _VegOption(
          label: 'Veg',
          emoji: '🟢',
          selected: isVeg,
          color: const Color(0xFF2E7D32),
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 12),
        _VegOption(
          label: 'Non-Veg',
          emoji: '🔴',
          selected: !isVeg,
          color: const Color(0xFFB71C1C),
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _VegOption extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _VegOption({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFDDDDDD),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Image Picker Section
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePickerSection extends StatelessWidget {
  final File? imageFile;
  final String? existingUrl;
  final VoidCallback onTap;

  const _ImagePickerSection({
    this.imageFile,
    this.existingUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || existingUrl != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? AppColors.primaryPurple.withOpacity(0.3)
                : const Color(0xFFEEEEEE),
            width: hasImage ? 2 : 1,
            style: hasImage ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageFile != null
                        ? Image.file(imageFile!, fit: BoxFit.cover)
                        : Image.network(existingUrl!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photo',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                  Text(
                    'JPEG / PNG up to 5MB',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Flags Section
// ─────────────────────────────────────────────────────────────────────────────
class _FlagsSection extends StatelessWidget {
  final bool isAvailable;
  final bool isBestSeller;
  final bool isFeatured;
  final bool isNewArrival;
  final bool isSpicy;
  final ValueChanged<bool> onAvailableChanged;
  final ValueChanged<bool> onBestSellerChanged;
  final ValueChanged<bool> onFeaturedChanged;
  final ValueChanged<bool> onNewArrivalChanged;
  final ValueChanged<bool> onSpicyChanged;

  const _FlagsSection({
    required this.isAvailable,
    required this.isBestSeller,
    required this.isFeatured,
    required this.isNewArrival,
    required this.isSpicy,
    required this.onAvailableChanged,
    required this.onBestSellerChanged,
    required this.onFeaturedChanged,
    required this.onNewArrivalChanged,
    required this.onSpicyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          _FlagTile(
            emoji: '✅',
            label: 'Available',
            sub: 'Item can be ordered',
            value: isAvailable,
            onChanged: onAvailableChanged,
          ),
          const Divider(height: 1, indent: 56),
          _FlagTile(
            emoji: '🔥',
            label: 'Best Seller',
            sub: 'Show hot badge',
            value: isBestSeller,
            onChanged: onBestSellerChanged,
          ),
          const Divider(height: 1, indent: 56),
          _FlagTile(
            emoji: '⭐',
            label: 'Featured',
            sub: 'Highlight on menu',
            value: isFeatured,
            onChanged: onFeaturedChanged,
          ),
          const Divider(height: 1, indent: 56),
          _FlagTile(
            emoji: '🆕',
            label: 'New Arrival',
            sub: 'Recently added',
            value: isNewArrival,
            onChanged: onNewArrivalChanged,
          ),
          const Divider(height: 1, indent: 56),
          _FlagTile(
            emoji: '🌶️',
            label: 'Spicy',
            sub: 'Contains chilli',
            value: isSpicy,
            onChanged: onSpicyChanged,
          ),
        ],
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagTile({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Text(sub,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryPurple,
      dense: true,
    );
  }
}