class DecorationCharge {
  final int? id;
  final String customerName;
  final double amount;
  final DateTime date;
  final String? notes;

  DecorationCharge({
    this.id,
    required this.customerName,
    required this.amount,
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_name': customerName,
      'amount': amount,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  factory DecorationCharge.fromMap(Map<String, dynamic> map) {
    return DecorationCharge(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
