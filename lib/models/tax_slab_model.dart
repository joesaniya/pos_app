import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TAX TYPE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum TaxType { inclusive, exclusive, none }

extension TaxTypeExt on TaxType {
  String get displayName {
    switch (this) {
      case TaxType.inclusive:
        return 'Inclusive';
      case TaxType.exclusive:
        return 'Exclusive';
      case TaxType.none:
        return 'No Tax';
    }
  }

  String get dbValue {
    switch (this) {
      case TaxType.inclusive:
        return 'inclusive';
      case TaxType.exclusive:
        return 'exclusive';
      case TaxType.none:
        return 'none';
    }
  }

  static TaxType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'inclusive':
        return TaxType.inclusive;
      case 'exclusive':
        return TaxType.exclusive;
      case 'none':
        return TaxType.none;
      default:
        return TaxType.exclusive;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX SLAB MODEL
// ─────────────────────────────────────────────────────────────────────────────

class TaxSlab {
  final String id;
  final String businessId;
  final String name; // e.g., "GST 5%", "GST 12%", "GST 18%"
  final double percentage; // percentage value (5, 12, 18 etc.)
  final TaxType type; // inclusive or exclusive
  final String? description;
  final String? taxNumber; // Tax ID/License Number for the business (mandatory)
  final bool isActive;
  final int sortOrder;

  // Audit fields
  final String createdByUid;
  final String createdByName;
  final String? createdByEmail;
  final String? createdByRole;

  final String? updatedByUid;
  final String? updatedByName;
  final String? updatedByRole;

  final DateTime createdAt;
  final DateTime updatedAt;

  const TaxSlab({
    required this.id,
    required this.businessId,
    required this.name,
    required this.percentage,
    required this.type,
    this.description,
    this.taxNumber,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdByUid,
    required this.createdByName,
    this.createdByEmail,
    this.createdByRole,
    this.updatedByUid,
    this.updatedByName,
    this.updatedByRole,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  SERIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  factory TaxSlab.fromJson(Map<String, dynamic> json, {String? id}) {
    return TaxSlab(
      id: id ?? (json['id'] as String?) ?? '',
      businessId: (json['business_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Unnamed Tax',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      type: TaxTypeExt.fromString((json['type'] as String?) ?? 'exclusive'),
      description: json['description'] as String?,
      taxNumber: json['tax_number'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      createdByUid: (json['created_by_uid'] as String?) ?? '',
      createdByName: (json['created_by_name'] as String?) ?? 'System',
      createdByEmail: json['created_by_email'] as String?,
      createdByRole: json['created_by_role'] as String?,
      updatedByUid: json['updated_by_uid'] as String?,
      updatedByName: json['updated_by_name'] as String?,
      updatedByRole: json['updated_by_role'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  factory TaxSlab.fromFirestore(DocumentSnapshot doc) {
    return TaxSlab.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'name': name,
    'percentage': percentage,
    'type': type.dbValue,
    'description': description,
    'tax_number': taxNumber,
    'is_active': isActive,
    'sort_order': sortOrder,
    'created_by_uid': createdByUid,
    'created_by_name': createdByName,
    'created_by_email': createdByEmail,
    'created_by_role': createdByRole,
    'updated_by_uid': updatedByUid,
    'updated_by_name': updatedByName,
    'updated_by_role': updatedByRole,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  COPY WITH
  // ─────────────────────────────────────────────────────────────────────────

  TaxSlab copyWith({
    String? id,
    String? businessId,
    String? name,
    double? percentage,
    TaxType? type,
    String? description,
    String? taxNumber,
    bool? isActive,
    int? sortOrder,
    String? createdByUid,
    String? createdByName,
    String? createdByEmail,
    String? createdByRole,
    String? updatedByUid,
    String? updatedByName,
    String? updatedByRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxSlab(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      type: type ?? this.type,
      description: description ?? this.description,
      taxNumber: taxNumber ?? this.taxNumber,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      createdByRole: createdByRole ?? this.createdByRole,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedByRole: updatedByRole ?? this.updatedByRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAX CALCULATION HELPER
// ─────────────────────────────────────────────────────────────────────────────

class TaxCalculation {
  final TaxSlab taxSlab;
  final double itemPrice;

  TaxCalculation({required this.taxSlab, required this.itemPrice});

  /// Calculate tax amount based on tax type
  /// For Inclusive: tax_amount = item_price - (item_price / (1 + tax % / 100))
  /// For Exclusive: tax_amount = item_price * (tax % / 100)
  double get taxAmount {
    if (taxSlab.type == TaxType.exclusive) {
      return itemPrice * (taxSlab.percentage / 100);
    } else if (taxSlab.type == TaxType.inclusive) {
      final multiplier = 1 + (taxSlab.percentage / 100);
      return itemPrice - (itemPrice / multiplier);
    }
    return 0.0;
  }

  /// Calculate final price (including tax if exclusive)
  double get finalPrice {
    if (taxSlab.type == TaxType.exclusive) {
      return itemPrice + taxAmount;
    }
    return itemPrice; // Tax already included in price
  }

  /// Get subtotal (price before tax application)
  double get subtotal {
    if (taxSlab.type == TaxType.inclusive) {
      final multiplier = 1 + (taxSlab.percentage / 100);
      return itemPrice / multiplier;
    }
    return itemPrice;
  }

  /// Format tax display (can be customized for CGST/SGST)
  String getTaxDisplay({bool detailed = false}) {
    if (detailed) {
      return '${taxSlab.name}\n${taxSlab.percentage}% (${taxSlab.type.displayName})';
    }
    return '${taxSlab.name} (${taxSlab.percentage}%)';
  }
}
