/// Mirrors the JSON shape returned by MoneyTrack's `transaction.to_dict()`:
/// { id, name, reason, income, expenses, date, time, occurred_at }
class TransactionModel {
  final int? id;
  final String name;
  final String reason;
  final double income;
  final double expenses;
  final DateTime occurredAt;

  TransactionModel({
    this.id,
    required this.name,
    required this.reason,
    required this.income,
    required this.expenses,
    required this.occurredAt,
  });

  bool get isIncome => income > 0;

  /// Net signed amount for this entry: positive for income, negative for expense.
  double get netAmount => income > 0 ? income : -expenses;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0.0,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'name': name,
      'reason': reason,
      'income': income,
      'expenses': expenses,
      'date':
          '${occurredAt.year.toString().padLeft(4, '0')}-${occurredAt.month.toString().padLeft(2, '0')}-${occurredAt.day.toString().padLeft(2, '0')}',
      'time':
          '${occurredAt.hour.toString().padLeft(2, '0')}:${occurredAt.minute.toString().padLeft(2, '0')}',
    };
  }
}
