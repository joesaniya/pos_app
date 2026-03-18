// lib/models/supabase_menu_item.dart



class SupabaseMenuItem {
  final String id;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final String? imageUrl;

  final bool isAvailable;
  final bool isVeg;
  final bool isFeatured;
  final bool isBestSeller;
  final bool isNewArrival;
  final bool isSpicy;

  final int preparationTime;
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? servingSize;
  final List<String> allergens;
  final List<String> tags;
  final List<String> ingredients;
  final double rating;
  final int sortOrder;

  final String businessId;
  final String businessName;

  // Audit — created by
  final String createdByUid;
  final String createdByName;
  final String? createdByEmail;
  final String? createdByRole;
  final String? createdByPhone;

  // Audit — last updated by
  final String? updatedByUid;
  final String? updatedByName;
  final String? updatedByRole;

  final DateTime createdAt;
  final DateTime updatedAt;

  SupabaseMenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description = '',
    required this.price,
    this.discountPrice,
    this.imageUrl,
    this.isAvailable = true,
    this.isVeg = true,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.isNewArrival = false,
    this.isSpicy = false,
    this.preparationTime = 15,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.servingSize,
    this.allergens = const [],
    this.tags = const [],
    this.ingredients = const [],
    this.rating = 4.0,
    this.sortOrder = 0,
    required this.businessId,
    required this.businessName,
    required this.createdByUid,
    required this.createdByName,
    this.createdByEmail,
    this.createdByRole,
    this.createdByPhone,
    this.updatedByUid,
    this.updatedByName,
    this.updatedByRole,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupabaseMenuItem.fromJson(Map<String, dynamic> json) {
    List<String> _list(dynamic v) =>
        v == null ? [] : List<String>.from(v as List);

    return SupabaseMenuItem(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      discountPrice: json['discount_price'] != null
          ? (json['discount_price'] as num).toDouble()
          : null,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isVeg: json['is_veg'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      isBestSeller: json['is_best_seller'] as bool? ?? false,
      isNewArrival: json['is_new_arrival'] as bool? ?? false,
      isSpicy: json['is_spicy'] as bool? ?? false,
      preparationTime: json['preparation_time'] as int? ?? 15,
      calories: json['calories'] as int?,
      protein: json['protein'] != null ? (json['protein'] as num).toDouble() : null,
      carbs: json['carbs'] != null ? (json['carbs'] as num).toDouble() : null,
      fat: json['fat'] != null ? (json['fat'] as num).toDouble() : null,
      servingSize: json['serving_size'] as String?,
      allergens: _list(json['allergens']),
      tags: _list(json['tags']),
      ingredients: _list(json['ingredients']),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 4.0,
      sortOrder: json['sort_order'] as int? ?? 0,
      businessId: json['business_id'] as String,
      businessName: json['business_name'] as String,
      createdByUid: json['created_by_uid'] as String,
      createdByName: json['created_by_name'] as String,
      createdByEmail: json['created_by_email'] as String?,
      createdByRole: json['created_by_role'] as String?,
      createdByPhone: json['created_by_phone'] as String?,
      updatedByUid: json['updated_by_uid'] as String?,
      updatedByName: json['updated_by_name'] as String?,
      updatedByRole: json['updated_by_role'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to the existing MenuItem used by UI screens.
  MenuItem toMenuItem(String category) {
    return MenuItem(
      id: id,
      name: name,
      price: price,
      category: category,
      subcategory: '',
      available: isAvailable,
      description: description,
      ingredients: ingredients,
      allergens: allergens,
      imageUrl: imageUrl,
      rating: rating,
      prepTimeMinutes: preparationTime,
      isVeg: isVeg,
      isBestseller: isBestSeller,
      nutrition: (calories != null)
          ? NutritionalInfo(
              calories: calories!,
              protein: protein ?? 0,
              carbs: carbs ?? 0,
              fat: fat ?? 0,
            )
          : null,
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'description': description,
        'price': price,
        'discount_price': discountPrice,
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
        'serving_size': servingSize,
        'allergens': allergens,
        'tags': tags,
        'ingredients': ingredients,
        'rating': rating,
        'sort_order': sortOrder,
      };
}
class NutritionalInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String subcategory;
  final bool available;
  final String description;
  final List<String> ingredients;
  final List<String> allergens;
  final String? imageUrl;
  final double rating;
  final int prepTimeMinutes;
  final bool isVeg;
  final bool isBestseller;
  final NutritionalInfo? nutrition;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.subcategory,
    required this.available,
    this.description = '',
    this.ingredients = const [],
    this.allergens = const [],
    this.imageUrl,
    this.rating = 4.0,
    this.prepTimeMinutes = 15,
    this.isVeg = true,
    this.isBestseller = false,
    this.nutrition,
  });

  MenuItem copyWith({bool? available}) {
    return MenuItem(
      id: id,
      name: name,
      price: price,
      category: category,
      subcategory: subcategory,
      available: available ?? this.available,
      description: description,
      ingredients: ingredients,
      allergens: allergens,
      imageUrl: imageUrl,
      rating: rating,
      prepTimeMinutes: prepTimeMinutes,
      isVeg: isVeg,
      isBestseller: isBestseller,
      nutrition: nutrition,
    );
  }
}

/*class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String subcategory;
  final bool available;
  final String description;
  final List<String> ingredients;
  final List<String> allergens;
  final String? imageUrl;
  final double rating;
  final int prepTimeMinutes;
  final bool isVeg;
  final bool isBestseller;
  final NutritionalInfo? nutrition;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.subcategory,
    required this.available,
    this.description = '',
    this.ingredients = const [],
    this.allergens = const [],
    this.imageUrl,
    this.rating = 4.0,
    this.prepTimeMinutes = 15,
    this.isVeg = true,
    this.isBestseller = false,
    this.nutrition,
  });

  MenuItem copyWith({bool? available}) {
    return MenuItem(
      id: id,
      name: name,
      price: price,
      category: category,
      subcategory: subcategory,
      available: available ?? this.available,
      description: description,
      ingredients: ingredients,
      allergens: allergens,
      imageUrl: imageUrl,
      rating: rating,
      prepTimeMinutes: prepTimeMinutes,
      isVeg: isVeg,
      isBestseller: isBestseller,
      nutrition: nutrition,
    );
  }
}

class NutritionalInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

/// Menu category model — lives here so menu screens don't need table_model.dart
class MenuCategory {
  final String name;
  final String icon;
  final int itemCount;
  final String? imageUrl;
  final List<String> subcategories;

  MenuCategory({
    required this.name,
    required this.icon,
    required this.itemCount,
    this.imageUrl,
    this.subcategories = const [],
  });
}*/