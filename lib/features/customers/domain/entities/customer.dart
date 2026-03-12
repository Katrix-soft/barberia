import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final int points;
  final String? notes;
  final bool isSynced;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.points = 0,
    this.notes,
    this.isSynced = true,
  });

  @override
  List<Object?> get props => [id, name, phone, email, points, notes, isSynced];
}
