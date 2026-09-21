class InvoiceItem {
  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.lineTotal = 0,
  });

  final int? id;
  final int? invoiceId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? discount,
    double? lineTotal,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}
