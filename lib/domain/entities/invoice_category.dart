class InvoiceCategory {
  const InvoiceCategory({
    this.id,
    required this.name,
    required this.colorValue,
  });

  final int? id;
  final String name;
  final int colorValue;

  InvoiceCategory copyWith({int? id, String? name, int? colorValue}) {
    return InvoiceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
