import 'dart:io';
import 'package:pos_app/models/menu_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_app/models/menu_item.dart';

class MenuSupabaseService {
  static final MenuSupabaseService _instance = MenuSupabaseService._();
  factory MenuSupabaseService() => _instance;
  MenuSupabaseService._();

  final SupabaseClient _db = Supabase.instance.client;

  // ── BUCKET ──────────────────────────────────────────────────
  static const String _bucket = 'menu-images';

  // ════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ════════════════════════════════════════════════════════════

  /// Fetch all active categories for a business, ordered by display_order.
  Future<List<SupabaseMenuCategory>> getCategories(String businessId) async {
    final res = await _db
        .from('menu_categories')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('display_order');

    return (res as List).map((e) => SupabaseMenuCategory.fromJson(e)).toList();
  }

  /// Stream of categories — re-emits whenever data changes.
  Stream<List<SupabaseMenuCategory>> watchCategories(String businessId) {
    return _db
        .from('menu_categories')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('display_order')
        .map(
          (rows) => rows
              .where((r) => r['is_active'] == true)
              .map((e) => SupabaseMenuCategory.fromJson(e))
              .toList(),
        );
  }

  /// Create a new category.
  Future<SupabaseMenuCategory> createCategory({
    required String name,
    required String description,
    required String icon,
    required String colorHex,
    required int displayOrder,
    required String businessId,
    required String businessName,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
    String? createdByPhone,
    File? imageFile,
  }) async {
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadCategoryImage(
        file: imageFile,
        businessId: businessId,
        categoryName: name,
      );
    }

    final data = {
      'name': name,
      'description': description,
      'icon': icon,
      'color_hex': colorHex,
      'display_order': displayOrder,
      'image_url': imageUrl,
      'business_id': businessId,
      'business_name': businessName,
      'created_by_uid': createdByUid,
      'created_by_name': createdByName,
      'created_by_email': createdByEmail,
      'created_by_role': createdByRole ?? 'staff',
      'created_by_phone': createdByPhone,
    };

    final res = await _db
        .from('menu_categories')
        .insert(data)
        .select()
        .single();

    return SupabaseMenuCategory.fromJson(res);
  }

  /// Update a category.
  Future<SupabaseMenuCategory> updateCategory({
    required String id,
    required Map<String, dynamic> updates,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
    File? imageFile,
    required String businessId,
    required String categoryName,
  }) async {
    if (imageFile != null) {
      updates['image_url'] = await uploadCategoryImage(
        file: imageFile,
        businessId: businessId,
        categoryName: categoryName,
      );
    }

    updates['updated_by_uid'] = updatedByUid;
    updates['updated_by_name'] = updatedByName;
    updates['updated_by_role'] = updatedByRole ?? 'staff';

    final res = await _db
        .from('menu_categories')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return SupabaseMenuCategory.fromJson(res);
  }

  /// Soft-delete (deactivate) a category.
  Future<void> deactivateCategory({
    required String id,
    required String updatedByUid,
    required String updatedByName,
  }) async {
    await _db
        .from('menu_categories')
        .update({
          'is_active': false,
          'updated_by_uid': updatedByUid,
          'updated_by_name': updatedByName,
        })
        .eq('id', id);
  }

  // ════════════════════════════════════════════════════════════
  //  MENU ITEMS
  // ════════════════════════════════════════════════════════════

  /// Fetch all items for a category.
  Future<List<SupabaseMenuItem>> getItemsByCategory(String categoryId) async {
    final res = await _db
        .from('menu_items')
        .select()
        .eq('category_id', categoryId)
        .order('sort_order');

    return (res as List).map((e) => SupabaseMenuItem.fromJson(e)).toList();
  }

  /// Fetch all items for a business.
  Future<List<SupabaseMenuItem>> getAllItems(String businessId) async {
    final res = await _db
        .from('menu_items')
        .select()
        .eq('business_id', businessId)
        .order('sort_order');

    return (res as List).map((e) => SupabaseMenuItem.fromJson(e)).toList();
  }

  /// Stream of items for a category.
  Stream<List<SupabaseMenuItem>> watchItems(String categoryId) {
    return _db
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('category_id', categoryId)
        .order('sort_order')
        .map((rows) => rows.map((e) => SupabaseMenuItem.fromJson(e)).toList());
  }

  /// Full-text search across all items for a business.
  Future<List<SupabaseMenuItem>> searchItems({
    required String businessId,
    required String query,
  }) async {
    final res = await _db
        .from('menu_items')
        .select()
        .eq('business_id', businessId)
        .textSearch('name', query, type: TextSearchType.websearch);

    return (res as List).map((e) => SupabaseMenuItem.fromJson(e)).toList();
  }

  /// Create a new menu item.
  Future<SupabaseMenuItem> createItem({
    required String categoryId,
    required String name,
    required double price,
    required bool isVeg,
    required String businessId,
    required String businessName,
    required String createdByUid,
    required String createdByName,
    String? createdByEmail,
    String? createdByRole,
    String? createdByPhone,
    String description = '',
    double? discountPrice,
    List<String> ingredients = const [],
    List<String> allergens = const [],
    int preparationTime = 15,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    bool isAvailable = true,
    bool isBestSeller = false,
    bool isFeatured = false,
    bool isNewArrival = false,
    bool isSpicy = false,
    double rating = 4.0,
    int sortOrder = 0,
    File? imageFile,
  }) async {
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadItemImage(
        file: imageFile,
        businessId: businessId,
        itemName: name,
      );
    }

    final data = {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'discount_price': discountPrice,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'is_veg': isVeg,
      'is_featured': isFeatured,
      'is_best_seller': isBestSeller,
      'is_new_arrival': isNewArrival,
      'is_spicy': isSpicy,
      'preparation_time': preparationTime,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ingredients': ingredients,
      'allergens': allergens,
      'rating': rating,
      'sort_order': sortOrder,
      'business_id': businessId,
      'business_name': businessName,
      'created_by_uid': createdByUid,
      'created_by_name': createdByName,
      'created_by_email': createdByEmail,
      'created_by_role': createdByRole ?? 'staff',
      'created_by_phone': createdByPhone,
    };

    final res = await _db.from('menu_items').insert(data).select().single();

    return SupabaseMenuItem.fromJson(res);
  }

  /// Update a menu item.
  Future<SupabaseMenuItem> updateItem({
    required String id,
    required Map<String, dynamic> updates,
    required String updatedByUid,
    required String updatedByName,
    String? updatedByRole,
    File? imageFile,
    String? businessId,
    String? itemName,
  }) async {
    if (imageFile != null && businessId != null && itemName != null) {
      updates['image_url'] = await uploadItemImage(
        file: imageFile,
        businessId: businessId,
        itemName: itemName,
      );
    }

    updates['updated_by_uid'] = updatedByUid;
    updates['updated_by_name'] = updatedByName;
    updates['updated_by_role'] = updatedByRole ?? 'staff';

    final res = await _db
        .from('menu_items')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return SupabaseMenuItem.fromJson(res);
  }

  /// Toggle item availability.
  Future<void> toggleAvailability({
    required String id,
    required bool isAvailable,
    required String updatedByUid,
    required String updatedByName,
  }) async {
    await _db
        .from('menu_items')
        .update({
          'is_available': isAvailable,
          'updated_by_uid': updatedByUid,
          'updated_by_name': updatedByName,
        })
        .eq('id', id);
  }

  /// Delete a menu item.
  Future<void> deleteItem(String id) async {
    await _db.from('menu_items').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════════
  //  STORAGE
  // ════════════════════════════════════════════════════════════

  Future<String> uploadCategoryImage({
    required File file,
    required String businessId,
    required String categoryName,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path =
        '$businessId/categories/${categoryName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage
        .from(_bucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );

    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  Future<String> uploadItemImage({
    required File file,
    required String businessId,
    required String itemName,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path =
        '$businessId/items/${itemName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage
        .from(_bucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );

    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  /// Delete an image from storage given its public URL.
  Future<void> deleteImage(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(_bucket);
      if (bucketIdx == -1) return;
      final path = segments.sublist(bucketIdx + 1).join('/');
      await _db.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  //  AUDIT LOG
  // ════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAuditLog({
    required String businessId,
    String? recordId,
    int limit = 50,
  }) async {
    final query = _db
        .from('menu_audit_log')
        .select()
        .match({
          'business_id': businessId,
          if (recordId != null) 'record_id': recordId,
        })
        .order('changed_at', ascending: false)
        .limit(limit);

    final res = await query;
    return List<Map<String, dynamic>>.from(res);
  }
}
