import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final int? id;
  final String description;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final String category;

  const Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    required this.category,
  });

  @override
  List<Object?> get props => [
    id,
    description,
    amount,
    dueDate,
    isPaid,
    category,
  ];
}
