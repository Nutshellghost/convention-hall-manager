class Payment {
  final int? id;
  final int bookingId;
  final double amount;
  final String type; // advance, final
  final String paymentMethod; // cash, upi, card, bank
  final DateTime date;
  final String? notes;

  Payment({
    this.id,
    required this.bookingId,
    required this.amount,
    required this.type,
    this.paymentMethod = 'cash',
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'booking_id': bookingId,
      'amount': amount,
      'type': type,
      'payment_method': paymentMethod,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      bookingId: map['booking_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
