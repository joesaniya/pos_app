class TableModel {
  final String id;
  final String tableNumber;
  final int persons;
  final String status; // 'available', 'occupied', 'reserved'
  final String? orderId;
  final String floor; // 'Ground Floor', 'First Floor', 'Second Floor', etc.
  final String? bookedBy; // Customer name if reserved
  final DateTime? bookingTime; // When the table was booked

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.persons,
    required this.status,
    this.orderId,
    required this.floor,
    this.bookedBy,
    this.bookingTime,
  });

  TableModel copyWith({
    String? id,
    String? tableNumber,
    int? persons,
    String? status,
    String? orderId,
    String? floor,
    String? bookedBy,
    DateTime? bookingTime,
  }) {
    return TableModel(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      persons: persons ?? this.persons,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      floor: floor ?? this.floor,
      bookedBy: bookedBy ?? this.bookedBy,
      bookingTime: bookingTime ?? this.bookingTime,
    );
  }
}