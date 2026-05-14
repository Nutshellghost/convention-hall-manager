class Booking {
  final int? id;
  final String customerName;
  final String phone;
  final DateTime eventDate;
  final String eventType;
  final String hallName;
  final String startTime;
  final String endTime;
  final double totalAmount;
  final double advanceAmount;
  final String status; // confirmed, completed, cancelled
  final String? notes;
  final DateTime createdAt;

  Booking({
    this.id,
    required this.customerName,
    required this.phone,
    required this.eventDate,
    required this.eventType,
    required this.hallName,
    required this.startTime,
    required this.endTime,
    required this.totalAmount,
    this.advanceAmount = 0.0,
    this.status = 'confirmed',
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_name': customerName,
      'phone': phone,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'event_type': eventType,
      'hall_name': hallName,
      'start_time': startTime,
      'end_time': endTime,
      'total_amount': totalAmount,
      'advance_amount': advanceAmount,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      phone: map['phone'] as String,
      eventDate: DateTime.parse(map['event_date'] as String),
      eventType: map['event_type'] as String,
      hallName: map['hall_name'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      advanceAmount: (map['advance_amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'confirmed',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Booking copyWith({
    int? id,
    String? customerName,
    String? phone,
    DateTime? eventDate,
    String? eventType,
    String? hallName,
    String? startTime,
    String? endTime,
    double? totalAmount,
    double? advanceAmount,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      eventDate: eventDate ?? this.eventDate,
      eventType: eventType ?? this.eventType,
      hallName: hallName ?? this.hallName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalAmount: totalAmount ?? this.totalAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
