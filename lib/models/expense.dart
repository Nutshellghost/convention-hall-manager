class Expense {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final String? notes;

  Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
