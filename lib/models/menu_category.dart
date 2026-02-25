// lib/models/supabase_menu_category.dart

class SupabaseMenuCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String colorHex;
  final int displayOrder;
  final bool isActive;
  final String? imageUrl;
  final String businessId;
  final String businessName;

  // Audit — who created
  final String createdByUid;
  final String createdByName;
  final String? createdByEmail;
  final String? createdByRole;
  final String? createdByPhone;

  // Audit — who last updated
  final String? updatedByUid;
  final String? updatedByName;
  final String? updatedByRole;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Runtime only (not from DB)
  int itemCount;

  SupabaseMenuCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colorHex,
    required this.displayOrder,
    required this.isActive,
    this.imageUrl,
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
    this.itemCount = 0,
  });

  factory SupabaseMenuCategory.fromJson(Map<String, dynamic> json) {
    return SupabaseMenuCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🍽️',
      colorHex: json['color_hex'] as String? ?? '#D4673A',
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'color_hex': colorHex,
        'display_order': displayOrder,
        'is_active': isActive,
        'image_url': imageUrl,
        'business_id': businessId,
        'business_name': businessName,
        'created_by_uid': createdByUid,
        'created_by_name': createdByName,
        'created_by_email': createdByEmail,
        'created_by_role': createdByRole,
        'created_by_phone': createdByPhone,
        'updated_by_uid': updatedByUid,
        'updated_by_name': updatedByName,
        'updated_by_role': updatedByRole,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  SupabaseMenuCategory copyWith({
    String? name,
    String? description,
    String? icon,
    String? colorHex,
    int? displayOrder,
    bool? isActive,
    String? imageUrl,
    int? itemCount,
  }) {
    return SupabaseMenuCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      businessId: businessId,
      businessName: businessName,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByEmail: createdByEmail,
      createdByRole: createdByRole,
      createdByPhone: createdByPhone,
      updatedByUid: updatedByUid,
      updatedByName: updatedByName,
      updatedByRole: updatedByRole,
      createdAt: createdAt,
      updatedAt: updatedAt,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}


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
}