import '../../domain/entities/customer.dart';

class CustomerModel extends Customer {
  const CustomerModel({
    super.id,
    required super.name,
    super.phone,
    super.email,
    super.points,
    super.notes,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      points: map['points'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'points': points,
      'notes': notes,
    };
  }
}
