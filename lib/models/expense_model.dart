import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE STATUS ENUMS
// ══════════════════════════════════════════════════════════════════════════════

enum ExpenseStatus { pending, approved, paid, rejected, cancelled }

extension ExpenseStatusExt on ExpenseStatus {
  String get dbValue {
    switch (this) {
      case ExpenseStatus.pending:
        return 'pending';
      case ExpenseStatus.approved:
        return 'approved';
      case ExpenseStatus.paid:
        return 'paid';
      case ExpenseStatus.rejected:
        return 'rejected';
      case ExpenseStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.paid:
        return 'Paid';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseStatus.pending:
        return '⏳';
      case ExpenseStatus.approved:
        return '✅';
      case ExpenseStatus.paid:
        return '💰';
      case ExpenseStatus.rejected:
        return '❌';
      case ExpenseStatus.cancelled:
        return '🚫';
    }
  }

  Color get color {
    switch (this) {
      case ExpenseStatus.pending:
        return const Color(0xFFE8860A);
      case ExpenseStatus.approved:
        return const Color(0xFF0A7ADB);
      case ExpenseStatus.paid:
        return const Color(0xFF1A9C5B);
      case ExpenseStatus.rejected:
        return const Color(0xFFDC2626);
      case ExpenseStatus.cancelled:
        return const Color(0xFF6B7280);
    }
  }

  Color get bgColor {
    switch (this) {
      case ExpenseStatus.pending:
        return const Color(0xFFFFF4E0);
      case ExpenseStatus.approved:
        return const Color(0xFFE0F0FF);
      case ExpenseStatus.paid:
        return const Color(0xFFE2F8ED);
      case ExpenseStatus.rejected:
        return const Color(0xFFFEF2F2);
      case ExpenseStatus.cancelled:
        return const Color(0xFFF3F4F6);
    }
  }

  static ExpenseStatus fromString(String s) {
    switch (s) {
      case 'approved':
        return ExpenseStatus.approved;
      case 'paid':
        return ExpenseStatus.paid;
      case 'rejected':
        return ExpenseStatus.rejected;
      case 'cancelled':
        return ExpenseStatus.cancelled;
      default:
        return ExpenseStatus.pending;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENT STATUS ENUMS
// ══════════════════════════════════════════════════════════════════════════════

enum ExpensePaymentStatus { unpaid, partial, paid }

extension ExpensePaymentStatusExt on ExpensePaymentStatus {
  String get dbValue {
    switch (this) {
      case ExpensePaymentStatus.unpaid:
        return 'unpaid';
      case ExpensePaymentStatus.partial:
        return 'partial';
      case ExpensePaymentStatus.paid:
        return 'paid';
    }
  }

  String get label {
    switch (this) {
      case ExpensePaymentStatus.unpaid:
        return 'Unpaid';
      case ExpensePaymentStatus.partial:
        return 'Partial';
      case ExpensePaymentStatus.paid:
        return 'Paid';
    }
  }

  String get emoji {
    switch (this) {
      case ExpensePaymentStatus.unpaid:
        return '💳';
      case ExpensePaymentStatus.partial:
        return '⚡';
      case ExpensePaymentStatus.paid:
        return '✅';
    }
  }

  Color get color {
    switch (this) {
      case ExpensePaymentStatus.unpaid:
        return const Color(0xFFDC2626);
      case ExpensePaymentStatus.partial:
        return const Color(0xFFD97706);
      case ExpensePaymentStatus.paid:
        return const Color(0xFF059669);
    }
  }

  static ExpensePaymentStatus fromString(String s) {
    switch (s) {
      case 'partial':
        return ExpensePaymentStatus.partial;
      case 'paid':
        return ExpensePaymentStatus.paid;
      default:
        return ExpensePaymentStatus.unpaid;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE TYPE ENUMS
// ══════════════════════════════════════════════════════════════════════════════

enum ExpenseType {
  maintenance,
  event,
  interiorWork,
  festival,
  operational,
  utility,
  general,
}

extension ExpenseTypeExt on ExpenseType {
  String get dbValue {
    switch (this) {
      case ExpenseType.maintenance:
        return 'maintenance';
      case ExpenseType.event:
        return 'event';
      case ExpenseType.interiorWork:
        return 'interior_work';
      case ExpenseType.festival:
        return 'festival';
      case ExpenseType.operational:
        return 'operational';
      case ExpenseType.utility:
        return 'utility';
      case ExpenseType.general:
        return 'general';
    }
  }

  String get label {
    switch (this) {
      case ExpenseType.maintenance:
        return 'Maintenance';
      case ExpenseType.event:
        return 'Event';
      case ExpenseType.interiorWork:
        return 'Interior Work';
      case ExpenseType.festival:
        return 'Festival';
      case ExpenseType.operational:
        return 'Operational';
      case ExpenseType.utility:
        return 'Utility';
      case ExpenseType.general:
        return 'General';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseType.maintenance:
        return '🔧';
      case ExpenseType.event:
        return '🎉';
      case ExpenseType.interiorWork:
        return '🏠';
      case ExpenseType.festival:
        return '🎪';
      case ExpenseType.operational:
        return '📊';
      case ExpenseType.utility:
        return '⚡';
      case ExpenseType.general:
        return '📝';
    }
  }

  static ExpenseType fromString(String s) {
    switch (s) {
      case 'maintenance':
        return ExpenseType.maintenance;
      case 'event':
        return ExpenseType.event;
      case 'interior_work':
        return ExpenseType.interiorWork;
      case 'festival':
        return ExpenseType.festival;
      case 'operational':
        return ExpenseType.operational;
      case 'utility':
        return ExpenseType.utility;
      default:
        return ExpenseType.general;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENT METHOD ENUMS
// ══════════════════════════════════════════════════════════════════════════════

enum PaymentMethod { cash, bankTransfer, cheque, upi, card, credit }

extension PaymentMethodExt on PaymentMethod {
  String get dbValue {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.cheque:
        return 'cheque';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.credit:
        return 'credit';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.credit:
        return 'Credit';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentMethod.cash:
        return '💵';
      case PaymentMethod.bankTransfer:
        return '🏦';
      case PaymentMethod.cheque:
        return '💳';
      case PaymentMethod.upi:
        return '📲';
      case PaymentMethod.card:
        return '🎫';
      case PaymentMethod.credit:
        return '⏳';
    }
  }

  static PaymentMethod fromString(String s) {
    switch (s) {
      case 'cash':
        return PaymentMethod.cash;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'cheque':
        return PaymentMethod.cheque;
      case 'upi':
        return PaymentMethod.upi;
      case 'card':
        return PaymentMethod.card;
      case 'credit':
        return PaymentMethod.credit;
      default:
        return PaymentMethod.cash;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE CATEGORY MODEL
// ══════════════════════════════════════════════════════════════════════════════

class ExpenseCategory {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String? description;
  final double? monthlyBudget;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.icon = 'receipt',
    this.color = '#6366F1',
    this.description,
    this.monthlyBudget,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      icon: json['icon'] as String? ?? 'receipt',
      color: json['color'] as String? ?? '#6366F1',
      description: json['description'] as String?,
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'description': description,
    'monthly_budget': monthlyBudget,
    'is_active': isActive,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE PAYMENT MODEL
// ══════════════════════════════════════════════════════════════════════════════

class ExpensePayment {
  final String id;
  final String businessId;
  final String expenseId;
  final double paymentAmount;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? transactionId;
  final String? chequeNumber;
  final String? bankName;
  final String paymentStatus;
  final String? notes;
  final String recordedByUid;
  final String recordedByName;
  final String? recordedByRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpensePayment({
    required this.id,
    required this.businessId,
    required this.expenseId,
    required this.paymentAmount,
    required this.paymentDate,
    required this.paymentMethod,
    this.transactionId,
    this.chequeNumber,
    this.bankName,
    this.paymentStatus = 'completed',
    this.notes,
    required this.recordedByUid,
    required this.recordedByName,
    this.recordedByRole,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpensePayment.fromJson(Map<String, dynamic> json) {
    return ExpensePayment(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String? ?? '',
      expenseId: json['expense_id'] as String? ?? '',
      paymentAmount: (json['payment_amount'] as num? ?? 0).toDouble(),
      paymentDate:
          DateTime.tryParse(json['payment_date'] as String? ?? '') ??
          DateTime.now(),
      paymentMethod: PaymentMethodExt.fromString(
        json['payment_method'] as String? ?? 'cash',
      ),
      transactionId: json['transaction_id'] as String?,
      chequeNumber: json['cheque_number'] as String?,
      bankName: json['bank_name'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'completed',
      notes: json['notes'] as String?,
      recordedByUid: json['recorded_by_uid'] as String? ?? '',
      recordedByName: json['recorded_by_name'] as String? ?? '',
      recordedByRole: json['recorded_by_role'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'expense_id': expenseId,
    'payment_amount': paymentAmount,
    'payment_date': paymentDate.toIso8601String(),
    'payment_method': paymentMethod.dbValue,
    'transaction_id': transactionId,
    'cheque_number': chequeNumber,
    'bank_name': bankName,
    'notes': notes,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE MODEL (Main)
// ══════════════════════════════════════════════════════════════════════════════

class Expense {
  final String id;
  final String businessId;
  final int expenseNumber;
  final String title;
  final String? description;
  final String categoryId;
  final String categoryName;
  final String vendorName;
  final String? vendorId;
  final double amount;
  final DateTime expenseDate;
  final DateTime? dueDate;
  final DateTime? paymentDate;
  final ExpenseStatus status;
  final ExpensePaymentStatus paymentStatus;
  final double paidAmount;
  final double remainingAmount;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final double? gstAmount;
  final String? gstNumber;
  final String? billFilePath;
  final String? billFileName;
  final int? billFileSize;
  final DateTime? billUploadedAt;
  final String approvalStatus;
  final String? approvedByUid;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final ExpenseType expenseType;
  final String? notes;
  final List<String> tags;
  final String createdByUid;
  final String createdByName;
  final String? createdByRole;
  final String? updatedByUid;
  final String? updatedByName;
  final String? updatedByRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final List<ExpensePayment> payments;

  const Expense({
    required this.id,
    required this.businessId,
    required this.expenseNumber,
    required this.title,
    this.description,
    required this.categoryId,
    required this.categoryName,
    required this.vendorName,
    this.vendorId,
    required this.amount,
    required this.expenseDate,
    this.dueDate,
    this.paymentDate,
    this.status = ExpenseStatus.pending,
    this.paymentStatus = ExpensePaymentStatus.unpaid,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.invoiceNumber,
    this.invoiceDate,
    this.gstAmount,
    this.gstNumber,
    this.billFilePath,
    this.billFileName,
    this.billFileSize,
    this.billUploadedAt,
    this.approvalStatus = 'pending',
    this.approvedByUid,
    this.approvedByName,
    this.approvedAt,
    this.approvalNotes,
    this.expenseType = ExpenseType.general,
    this.notes,
    this.tags = const [],
    required this.createdByUid,
    required this.createdByName,
    this.createdByRole,
    this.updatedByUid,
    this.updatedByName,
    this.updatedByRole,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.payments = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    // Parse payments if nested
    List<ExpensePayment> parsedPayments = [];
    if (json['payments'] != null && json['payments'] is List) {
      parsedPayments = (json['payments'] as List)
          .map((p) => ExpensePayment.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    List<String> parsedTags = [];
    if (json['tags'] != null && json['tags'] is List) {
      parsedTags = List<String>.from(json['tags'] as List);
    }

    return Expense(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String? ?? '',
      expenseNumber: json['expense_number'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      categoryId: json['expense_category_id'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? 'Unknown',
      vendorName: json['vendor_name'] as String? ?? 'Unknown',
      vendorId: json['vendor_id'] as String?,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      expenseDate:
          DateTime.tryParse(json['expense_date'] as String? ?? '') ??
          DateTime.now(),
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      paymentDate: DateTime.tryParse(json['payment_date'] as String? ?? ''),
      status: ExpenseStatusExt.fromString(json['status'] as String? ?? ''),
      paymentStatus: ExpensePaymentStatusExt.fromString(
        json['payment_status'] as String? ?? '',
      ),
      paidAmount: (json['paid_amount'] as num? ?? 0).toDouble(),
      remainingAmount: (json['remaining_amount'] as num? ?? 0).toDouble(),
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: DateTime.tryParse(json['invoice_date'] as String? ?? ''),
      gstAmount: (json['gst_amount'] as num?)?.toDouble(),
      gstNumber: json['gst_number'] as String?,
      billFilePath: json['bill_file_path'] as String?,
      billFileName: json['bill_file_name'] as String?,
      billFileSize: json['bill_file_size'] as int?,
      billUploadedAt: DateTime.tryParse(
        json['bill_uploaded_at'] as String? ?? '',
      ),
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      approvedByUid: json['approved_by_uid'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
      approvalNotes: json['approval_notes'] as String?,
      expenseType: ExpenseTypeExt.fromString(
        json['expense_type'] as String? ?? '',
      ),
      notes: json['notes'] as String?,
      tags: parsedTags,
      createdByUid: json['created_by_uid'] as String? ?? '',
      createdByName: json['created_by_name'] as String? ?? '',
      createdByRole: json['created_by_role'] as String?,
      updatedByUid: json['updated_by_uid'] as String?,
      updatedByName: json['updated_by_name'] as String?,
      updatedByRole: json['updated_by_role'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      payments: parsedPayments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'expense_number': expenseNumber,
    'title': title,
    'description': description,
    'expense_category_id': categoryId,
    'category_name': categoryName,
    'vendor_name': vendorName,
    'vendor_id': vendorId,
    'amount': amount,
    'expense_date': expenseDate.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'payment_date': paymentDate?.toIso8601String(),
    'status': status.dbValue,
    'payment_status': paymentStatus.dbValue,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'invoice_number': invoiceNumber,
    'invoice_date': invoiceDate?.toIso8601String(),
    'gst_amount': gstAmount,
    'gst_number': gstNumber,
    'bill_file_path': billFilePath,
    'bill_file_name': billFileName,
    'bill_file_size': billFileSize,
    'bill_uploaded_at': billUploadedAt?.toIso8601String(),
    'approval_status': approvalStatus,
    'approved_by_uid': approvedByUid,
    'approved_by_name': approvedByName,
    'approved_at': approvedAt?.toIso8601String(),
    'approval_notes': approvalNotes,
    'expense_type': expenseType.dbValue,
    'notes': notes,
    'tags': tags,
    'created_by_uid': createdByUid,
    'created_by_name': createdByName,
    'created_by_role': createdByRole,
    'updated_by_uid': updatedByUid,
    'updated_by_name': updatedByName,
    'updated_by_role': updatedByRole,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_active': isActive,
  };

  double get progressPercentage {
    if (amount == 0) return 0;
    return (paidAmount / amount * 100).clamp(0, 100);
  }

  bool get isPaid => paymentStatus == ExpensePaymentStatus.paid;
  bool get isPartiallyPaid => paymentStatus == ExpensePaymentStatus.partial;
  bool get isUnpaid => paymentStatus == ExpensePaymentStatus.unpaid;

  Expense copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? categoryName,
    String? vendorName,
    double? amount,
    DateTime? expenseDate,
    ExpenseStatus? status,
    String? notes,
  }) {
    return Expense(
      id: id,
      businessId: businessId,
      expenseNumber: expenseNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      vendorName: vendorName ?? this.vendorName,
      vendorId: vendorId,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      dueDate: dueDate,
      paymentDate: paymentDate,
      status: status ?? this.status,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      gstAmount: gstAmount,
      gstNumber: gstNumber,
      billFilePath: billFilePath,
      billFileName: billFileName,
      billFileSize: billFileSize,
      billUploadedAt: billUploadedAt,
      approvalStatus: approvalStatus,
      approvedByUid: approvedByUid,
      approvedByName: approvedByName,
      approvedAt: approvedAt,
      approvalNotes: approvalNotes,
      expenseType: expenseType,
      notes: notes ?? this.notes,
      tags: tags,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByRole: createdByRole,
      updatedByUid: updatedByUid,
      updatedByName: updatedByName,
      updatedByRole: updatedByRole,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: isActive,
      payments: payments,
    );
  }
}
