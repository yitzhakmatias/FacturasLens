class InvoiceImage {
  const InvoiceImage({
    this.id,
    this.invoiceId,
    required this.path,
    required this.pageIndex,
    this.rotation = 0,
    this.ocrText = '',
  });

  final int? id;
  final int? invoiceId;
  final String path;
  final int pageIndex;
  final int rotation;
  final String ocrText;

  InvoiceImage copyWith({
    int? id,
    int? invoiceId,
    String? path,
    int? pageIndex,
    int? rotation,
    String? ocrText,
  }) {
    return InvoiceImage(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      path: path ?? this.path,
      pageIndex: pageIndex ?? this.pageIndex,
      rotation: rotation ?? this.rotation,
      ocrText: ocrText ?? this.ocrText,
    );
  }
}
