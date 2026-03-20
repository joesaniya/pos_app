// lib/models/supplier_modal.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SUPPLIER MODAL  — full data model for the supplier module
// ══════════════════════════════════════════════════════════════════════════════

enum SupplierStatus { active, inactive, blacklisted }

enum PaymentStatus { paid, pending, overdue, partial }

enum DocumentType { invoice, contract, license, delivery, gst, other }

enum PaymentMode { cash, upi, bank, cheque, credit }

// ─────────────────────────────────────────────────────────────────────────────
extension SupplierStatusExt on SupplierStatus {
  String get label {
    switch (this) {
      case SupplierStatus.active:
        return 'Active';
      case SupplierStatus.inactive:
        return 'Inactive';
      case SupplierStatus.blacklisted:
        return 'Blacklisted';
    }
  }

  String get dbValue {
    switch (this) {
      case SupplierStatus.active:
        return 'active';
      case SupplierStatus.inactive:
        return 'inactive';
      case SupplierStatus.blacklisted:
        return 'blacklisted';
    }
  }

  static SupplierStatus fromString(String s) {
    switch (s) {
      case 'inactive':
        return SupplierStatus.inactive;
      case 'blacklisted':
        return SupplierStatus.blacklisted;
      default:
        return SupplierStatus.active;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.partial:
        return 'Partial';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentStatus.paid:
        return '✅';
      case PaymentStatus.pending:
        return '🕐';
      case PaymentStatus.overdue:
        return '🔴';
      case PaymentStatus.partial:
        return '⚡';
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.overdue:
        return 'overdue';
      case PaymentStatus.partial:
        return 'partial';
    }
  }

  static PaymentStatus fromString(String s) {
    switch (s) {
      case 'pending':
        return PaymentStatus.pending;
      case 'overdue':
        return PaymentStatus.overdue;
      case 'partial':
        return PaymentStatus.partial;
      default:
        return PaymentStatus.paid;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension DocumentTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.contract:
        return 'Contract';
      case DocumentType.license:
        return 'License';
      case DocumentType.delivery:
        return 'Delivery Note';
      case DocumentType.gst:
        return 'GST Certificate';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case DocumentType.invoice:
        return '🧾';
      case DocumentType.contract:
        return '📋';
      case DocumentType.license:
        return '🪪';
      case DocumentType.delivery:
        return '📦';
      case DocumentType.gst:
        return '📄';
      case DocumentType.other:
        return '📎';
    }
  }

  String get dbValue {
    switch (this) {
      case DocumentType.invoice:
        return 'invoice';
      case DocumentType.contract:
        return 'contract';
      case DocumentType.license:
        return 'license';
      case DocumentType.delivery:
        return 'delivery';
      case DocumentType.gst:
        return 'gst';
      case DocumentType.other:
        return 'other';
    }
  }

  static DocumentType fromString(String s) {
    switch (s) {
      case 'invoice':
        return DocumentType.invoice;
      case 'contract':
        return DocumentType.contract;
      case 'license':
        return DocumentType.license;
      case 'delivery':
        return DocumentType.delivery;
      case 'gst':
        return DocumentType.gst;
      default:
        return DocumentType.other;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
extension PaymentModeExt on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bank:
        return 'Bank Transfer';
      case PaymentMode.cheque:
        return 'Cheque';
      case PaymentMode.credit:
        return 'Credit';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentMode.cash:
        return '💵';
      case PaymentMode.upi:
        return '📲';
      case PaymentMode.bank:
        return '🏦';
      case PaymentMode.cheque:
        return '📝';
      case PaymentMode.credit:
        return '💳';
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentMode.cash:
        return 'cash';
      case PaymentMode.upi:
        return 'upi';
      case PaymentMode.bank:
        return 'bank';
      case PaymentMode.cheque:
        return 'cheque';
      case PaymentMode.credit:
        return 'credit';
    }
  }

  /// Whether a transaction reference is mandatory for this mode.
  bool get requiresRef {
    switch (this) {
      case PaymentMode.cash:
        return false;
      default:
        return true;
    }
  }

  static PaymentMode fromString(String s) {
    switch (s) {
      case 'cash':
        return PaymentMode.cash;
      case 'bank':
        return PaymentMode.bank;
      case 'cheque':
        return PaymentMode.cheque;
      case 'credit':
        return PaymentMode.credit;
      default:
        return PaymentMode.upi;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUPPLIER CONTACT
// ─────────────────────────────────────────────────────────────────────────────
class SupplierContact {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String? email;
  final bool isPrimary;

  const SupplierContact({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.email,
    this.isPrimary = false,
  });

  factory SupplierContact.fromJson(Map<String, dynamic> j) => SupplierContact(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    role: j['role'] as String? ?? 'Contact',
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String?,
    isPrimary: j['is_primary'] as bool? ?? false,
  );

  Map<String, dynamic> toJson(String supplierId, String businessId) => {
    'supplier_id': supplierId,
    'business_id': businessId,
    'name': name,
    'role': role,
    'phone': phone,
    'email': email,
    'is_primary': isPrimary,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUPPLIER DOCUMENT
// ─────────────────────────────────────────────────────────────────────────────
class SupplierDocument {
  final String id;
  final DocumentType type;
  final String title;
  final DateTime uploadedOn;
  final DateTime? expiryDate;
  final String? fileRef; // Supabase Storage path
  final String? fileUrl; // Signed URL for in-app viewing

  const SupplierDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.uploadedOn,
    this.expiryDate,
    this.fileRef,
    this.fileUrl,
  });

  factory SupplierDocument.fromJson(Map<String, dynamic> j) => SupplierDocument(
    id: j['id'] as String? ?? '',
    type: DocumentTypeExt.fromString(j['type'] as String? ?? 'other'),
    title: j['title'] as String? ?? '',
    uploadedOn: j['uploaded_on'] != null
        ? DateTime.parse(j['uploaded_on'] as String)
        : DateTime.now(),
    expiryDate: j['expiry_date'] != null
        ? DateTime.parse(j['expiry_date'] as String)
        : null,
    fileRef: j['file_ref'] as String?,
    fileUrl: j['file_url'] as String?,
  );

  Map<String, dynamic> toJson(String supplierId, String businessId) => {
    'supplier_id': supplierId,
    'business_id': businessId,
    'type': type.dbValue,
    'title': title,
    'uploaded_on': uploadedOn.toIso8601String(),
    'expiry_date': expiryDate?.toIso8601String(),
    'file_ref': fileRef,
  };

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get expiresSOon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

  bool get hasFile => fileRef != null && fileRef!.isNotEmpty;

  String get expiryLabel {
    if (expiryDate == null) return 'No expiry';
    if (isExpired) return 'Expired';
    final d = expiryDate!.difference(DateTime.now()).inDays;
    if (d <= 30) return 'Expires in $d days';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[expiryDate!.month - 1]} ${expiryDate!.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAYMENT RECORD
// ─────────────────────────────────────────────────────────────────────────────
class PaymentRecord {
  final String id;
  final double amount;
  final double? paidAmount;
  final PaymentStatus status;
  final PaymentMode mode;
  final DateTime date;
  final DateTime? dueDate;
  final String description;
  final String? invoiceRef;

  /// UTR / cheque number / UPI ref — mandatory for non-cash modes.
  final String? transactionRef;

  const PaymentRecord({
    required this.id,
    required this.amount,
    this.paidAmount,
    required this.status,
    required this.mode,
    required this.date,
    this.dueDate,
    required this.description,
    this.invoiceRef,
    this.transactionRef,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
    id: j['id'] as String? ?? '',
    amount: (j['amount'] as num? ?? 0).toDouble(),
    paidAmount: j['paid_amount'] != null
        ? (j['paid_amount'] as num).toDouble()
        : null,
    status: PaymentStatusExt.fromString(
      j['payment_status'] as String? ?? 'pending',
    ),
    mode: PaymentModeExt.fromString(j['payment_mode'] as String? ?? 'upi'),
    date: j['payment_date'] != null
        ? DateTime.parse(j['payment_date'] as String)
        : DateTime.now(),
    dueDate: j['due_date'] != null
        ? DateTime.parse(j['due_date'] as String)
        : null,
    description: j['description'] as String? ?? '',
    invoiceRef: j['invoice_ref'] as String?,
    transactionRef: j['transaction_ref'] as String?,
  );

  Map<String, dynamic> toJson(String supplierId, String businessId) => {
    'supplier_id': supplierId,
    'business_id': businessId,
    'amount': amount,
    'paid_amount': paidAmount,
    'payment_status': status.dbValue,
    'payment_mode': mode.dbValue,
    'description': description,
    'invoice_ref': invoiceRef,
    'transaction_ref': transactionRef,
    'payment_date': date.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
  };

  double get outstanding =>
      amount - (paidAmount ?? (status == PaymentStatus.paid ? amount : 0));

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != PaymentStatus.paid;

  String get dateLabel => _fmtDate(date);
  String get dueDateLabel => dueDate != null ? _fmtDate(dueDate!) : '';

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUPPLIER DELIVERY
// ─────────────────────────────────────────────────────────────────────────────
class SupplierDelivery {
  final String id;
  final DateTime deliveredOn;
  final List<String> items;
  final double totalValue;
  final bool onTime;
  final String? note;

  const SupplierDelivery({
    required this.id,
    required this.deliveredOn,
    required this.items,
    required this.totalValue,
    required this.onTime,
    this.note,
  });

  factory SupplierDelivery.fromJson(Map<String, dynamic> j) => SupplierDelivery(
    id: j['id'] as String? ?? '',
    deliveredOn: j['delivered_on'] != null
        ? DateTime.parse(j['delivered_on'] as String)
        : DateTime.now(),
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    totalValue: (j['total_value'] as num? ?? 0).toDouble(),
    onTime: j['on_time'] as bool? ?? true,
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson(String supplierId, String businessId) => {
    'supplier_id': supplierId,
    'business_id': businessId,
    'delivered_on': deliveredOn.toIso8601String(),
    'items': items,
    'total_value': totalValue,
    'on_time': onTime,
    'note': note,
  };

  String get dateLabel {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[deliveredOn.month - 1]} ${deliveredOn.day}, ${deliveredOn.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUPPLIER
// ─────────────────────────────────────────────────────────────────────────────
class Supplier {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final SupplierStatus status;
  final String? gstNumber;
  final String? address;
  final String? city;
  final double creditLimit;
  final int creditDays;
  final double rating;
  final List<SupplierContact> contacts;
  final List<SupplierDocument> documents;
  final List<PaymentRecord> payments;
  final List<SupplierDelivery> deliveries;
  final DateTime onboardedDate;
  final String? notes;

  const Supplier({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.status,
    this.gstNumber,
    this.address,
    this.city,
    required this.creditLimit,
    required this.creditDays,
    required this.rating,
    required this.contacts,
    required this.documents,
    required this.payments,
    required this.deliveries,
    required this.onboardedDate,
    this.notes,
  });

  // ── Derived metrics ────────────────────────────────────────────────────────

  double get totalPurchased => payments.fold(0.0, (s, p) => s + p.amount);

  double get totalPending => payments
      .where((p) => p.status != PaymentStatus.paid)
      .fold(0.0, (s, p) => s + p.outstanding);

  double get totalOverdue =>
      payments.where((p) => p.isOverdue).fold(0.0, (s, p) => s + p.outstanding);

  int get onTimeDeliveries => deliveries.where((d) => d.onTime).length;

  double get deliveryScore =>
      deliveries.isEmpty ? 0 : onTimeDeliveries / deliveries.length * 100;

  bool get hasExpiredDocs => documents.any((d) => d.isExpired);
  bool get hasExpiringDocs => documents.any((d) => d.expiresSOon);

  String get tenureLabel {
    final diff = DateTime.now().difference(onboardedDate);
    final months = (diff.inDays / 30).floor();
    if (months < 1) return '${diff.inDays}d';
    if (months < 12) return '${months}mo';
    return '${(months / 12).floor()}yr';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String? ?? 'Other',
    emoji: j['emoji'] as String? ?? '🏭',
    status: SupplierStatusExt.fromString(j['status'] as String? ?? 'active'),
    gstNumber: j['gst_number'] as String?,
    address: j['address'] as String?,
    city: j['city'] as String?,
    creditLimit: (j['credit_limit'] as num? ?? 0).toDouble(),
    creditDays: j['credit_days'] as int? ?? 14,
    rating: (j['rating'] as num? ?? 0).toDouble(),
    contacts: (j['supplier_contacts'] as List<dynamic>? ?? [])
        .map((c) => SupplierContact.fromJson(c as Map<String, dynamic>))
        .toList(),
    documents: (j['supplier_documents'] as List<dynamic>? ?? [])
        .map((d) => SupplierDocument.fromJson(d as Map<String, dynamic>))
        .toList(),
    payments: (j['supplier_payments'] as List<dynamic>? ?? [])
        .map((p) => PaymentRecord.fromJson(p as Map<String, dynamic>))
        .toList(),
    deliveries: (j['supplier_deliveries'] as List<dynamic>? ?? [])
        .map((d) => SupplierDelivery.fromJson(d as Map<String, dynamic>))
        .toList(),
    onboardedDate: j['onboarded_date'] != null
        ? DateTime.parse(j['onboarded_date'] as String)
        : DateTime.now(),
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson(String businessId) => {
    'business_id': businessId,
    'name': name,
    'category': category,
    'emoji': emoji,
    'status': status.dbValue,
    'gst_number': gstNumber,
    'address': address,
    'city': city,
    'credit_limit': creditLimit,
    'credit_days': creditDays,
    'rating': rating,
    'notes': notes,
    'onboarded_date': onboardedDate.toIso8601String().substring(0, 10),
    'is_active': true,
  };

  Supplier copyWith({
    String? name,
    String? category,
    String? emoji,
    SupplierStatus? status,
    String? gstNumber,
    String? address,
    String? city,
    double? creditLimit,
    int? creditDays,
    double? rating,
    String? notes,
    List<SupplierContact>? contacts,
    List<SupplierDocument>? documents,
    List<PaymentRecord>? payments,
    List<SupplierDelivery>? deliveries,
  }) => Supplier(
    id: id,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
    category: category ?? this.category,
    status: status ?? this.status,
    gstNumber: gstNumber ?? this.gstNumber,
    address: address ?? this.address,
    city: city ?? this.city,
    creditLimit: creditLimit ?? this.creditLimit,
    creditDays: creditDays ?? this.creditDays,
    rating: rating ?? this.rating,
    contacts: contacts ?? this.contacts,
    documents: documents ?? this.documents,
    payments: payments ?? this.payments,
    deliveries: deliveries ?? this.deliveries,
    onboardedDate: onboardedDate,
    notes: notes ?? this.notes,
  );
}
