enum SupplierStatus { active, inactive, blacklisted }

enum PaymentStatus { paid, pending, overdue, partial }

enum DocumentType { invoice, contract, license, delivery, gst, other }

enum PaymentMode { cash, upi, bank, cheque, credit }
//

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
class SupplierContact {
  final String name;
  final String role;
  final String phone;
  final String? email;
  const SupplierContact({
    required this.name,
    required this.role,
    required this.phone,
    this.email,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class SupplierDocument {
  final String id;
  final DocumentType type;
  final String title;
  final DateTime uploadedOn;
  final DateTime? expiryDate;
  final String? fileRef;
  const SupplierDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.uploadedOn,
    this.expiryDate,
    this.fileRef,
  });

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get expiresSOon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

  String get expiryLabel {
    if (expiryDate == null) return 'No expiry';
    if (isExpired) return 'Expired';
    final d = expiryDate!.difference(DateTime.now()).inDays;
    if (d <= 30) return 'Expires in $d days';
    final months = [
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
    return '${months[expiryDate!.month - 1]} ${expiryDate!.year}';
  }
}

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
  });

  double get outstanding =>
      amount - (paidAmount ?? (status == PaymentStatus.paid ? amount : 0));

  String get dateLabel {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get dueDateLabel {
    if (dueDate == null) return '';
    final months = [
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
    return '${months[dueDate!.month - 1]} ${dueDate!.day}';
  }

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != PaymentStatus.paid;
}

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

  String get dateLabel {
    final months = [
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
    return '${months[deliveredOn.month - 1]} ${deliveredOn.day}, ${deliveredOn.year}';
  }
}

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

  Supplier copyWith({
    String? name,
    String? category,
    SupplierStatus? status,
    String? gstNumber,
    String? address,
    String? city,
    double? creditLimit,
    int? creditDays,
    String? notes,
    List<SupplierContact>? contacts,
    List<SupplierDocument>? documents,
    List<PaymentRecord>? payments,
    List<SupplierDelivery>? deliveries,
  }) => Supplier(
    id: id,
    emoji: emoji,
    name: name ?? this.name,
    category: category ?? this.category,
    status: status ?? this.status,
    gstNumber: gstNumber ?? this.gstNumber,
    address: address ?? this.address,
    city: city ?? this.city,
    creditLimit: creditLimit ?? this.creditLimit,
    creditDays: creditDays ?? this.creditDays,
    rating: rating,
    contacts: contacts ?? this.contacts,
    documents: documents ?? this.documents,
    payments: payments ?? this.payments,
    deliveries: deliveries ?? this.deliveries,
    onboardedDate: onboardedDate,
    notes: notes ?? this.notes,
  );
}


/*enum SupplierStatus { active, inactive, blacklisted }
enum PaymentStatus { paid, pending, overdue, partial }
enum DocumentType { invoice, contract, license, delivery, gst, other }
enum PaymentMode { cash, upi, bank, cheque, credit }

extension SupplierStatusExt on SupplierStatus {
  String get label {
    switch (this) {
      case SupplierStatus.active:      return 'Active';
      case SupplierStatus.inactive:    return 'Inactive';
      case SupplierStatus.blacklisted: return 'Blacklisted';
    }
  }
}

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:    return 'Paid';
      case PaymentStatus.pending: return 'Pending';
      case PaymentStatus.overdue: return 'Overdue';
      case PaymentStatus.partial: return 'Partial';
    }
  }
  String get emoji {
    switch (this) {
      case PaymentStatus.paid:    return '✅';
      case PaymentStatus.pending: return '🕐';
      case PaymentStatus.overdue: return '🔴';
      case PaymentStatus.partial: return '⚡';
    }
  }
}

extension DocumentTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.invoice:  return 'Invoice';
      case DocumentType.contract: return 'Contract';
      case DocumentType.license:  return 'License';
      case DocumentType.delivery: return 'Delivery Note';
      case DocumentType.gst:      return 'GST Certificate';
      case DocumentType.other:    return 'Other';
    }
  }
  String get emoji {
    switch (this) {
      case DocumentType.invoice:  return '🧾';
      case DocumentType.contract: return '📋';
      case DocumentType.license:  return '🪪';
      case DocumentType.delivery: return '📦';
      case DocumentType.gst:      return '📄';
      case DocumentType.other:    return '📎';
    }
  }
}

extension PaymentModeExt on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:   return 'Cash';
      case PaymentMode.upi:    return 'UPI';
      case PaymentMode.bank:   return 'Bank Transfer';
      case PaymentMode.cheque: return 'Cheque';
      case PaymentMode.credit: return 'Credit';
    }
  }
  String get emoji {
    switch (this) {
      case PaymentMode.cash:   return '💵';
      case PaymentMode.upi:    return '📲';
      case PaymentMode.bank:   return '🏦';
      case PaymentMode.cheque: return '📝';
      case PaymentMode.credit: return '💳';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class SupplierContact {
  final String name;
  final String role;
  final String phone;
  final String? email;
  const SupplierContact({
    required this.name,
    required this.role,
    required this.phone,
    this.email,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class SupplierDocument {
  final String id;
  final DocumentType type;
  final String title;
  final DateTime uploadedOn;
  final DateTime? expiryDate;
  final String? fileRef;
  const SupplierDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.uploadedOn,
    this.expiryDate,
    this.fileRef,
  });

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get expiresSOon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

  String get expiryLabel {
    if (expiryDate == null) return 'No expiry';
    if (isExpired) return 'Expired';
    final d = expiryDate!.difference(DateTime.now()).inDays;
    if (d <= 30) return 'Expires in $d days';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[expiryDate!.month - 1]} ${expiryDate!.year}';
  }
}

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
  });

  double get outstanding => amount - (paidAmount ?? (status == PaymentStatus.paid ? amount : 0));

  String get dateLabel {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get dueDateLabel {
    if (dueDate == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dueDate!.month - 1]} ${dueDate!.day}';
  }

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != PaymentStatus.paid;
}

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

  String get dateLabel {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[deliveredOn.month - 1]} ${deliveredOn.day}, ${deliveredOn.year}';
  }
}

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

  // Computed
  double get totalPurchased =>
      payments.fold(0.0, (s, p) => s + p.amount);

  double get totalPending =>
      payments.where((p) => p.status != PaymentStatus.paid)
              .fold(0.0, (s, p) => s + p.outstanding);

  double get totalOverdue =>
      payments.where((p) => p.isOverdue)
              .fold(0.0, (s, p) => s + p.outstanding);

  int get onTimeDeliveries =>
      deliveries.where((d) => d.onTime).length;

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

  Supplier copyWith({
    String? name,
    String? category,
    SupplierStatus? status,
    String? gstNumber,
    String? address,
    String? city,
    double? creditLimit,
    int? creditDays,
    String? notes,
    List<SupplierContact>? contacts,
    List<SupplierDocument>? documents,
    List<PaymentRecord>? payments,
    List<SupplierDelivery>? deliveries,
  }) => Supplier(
    id: id, emoji: emoji,
    name: name ?? this.name,
    category: category ?? this.category,
    status: status ?? this.status,
    gstNumber: gstNumber ?? this.gstNumber,
    address: address ?? this.address,
    city: city ?? this.city,
    creditLimit: creditLimit ?? this.creditLimit,
    creditDays: creditDays ?? this.creditDays,
    rating: this.rating,
    contacts: contacts ?? this.contacts,
    documents: documents ?? this.documents,
    payments: payments ?? this.payments,
    deliveries: deliveries ?? this.deliveries,
    onboardedDate: onboardedDate,
    notes: notes ?? this.notes,
  );
}*/