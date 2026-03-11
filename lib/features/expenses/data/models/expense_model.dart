import '../../domain/entities/expense.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    super.id,
    required super.description,
    required super.amount,
    required super.dueDate,
    super.isPaid = false,
    required super.category,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date']),
      isPaid: map['is_paid'] == 1,
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'is_paid': isPaid ? 1 : 0,
      'category': category,
    };
  }

  factory ExpenseModel.fromEntity(Expense entity) {
    return ExpenseModel(
      id: entity.id,
      description: entity.description,
      amount: entity.amount,
      dueDate: entity.dueDate,
      isPaid: entity.isPaid,
      category: entity.category,
    );
  }
}
