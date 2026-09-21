class Supplier {
  const Supplier({
    this.id,
    required this.name,
    this.taxId = '',
    this.address = '',
    this.phone = '',
  });

  final int? id;
  final String name;
  final String taxId;
  final String address;
  final String phone;

  Supplier copyWith({
    int? id,
    String? name,
    String? taxId,
    String? address,
    String? phone,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }
}
