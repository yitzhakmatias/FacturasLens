import 'invoice_image.dart';
import 'invoice_item.dart';

enum InvoiceStatus { draft, verified }

class Invoice {
  const Invoice({
    this.id,
    this.supplierId,
    this.categoryId,
    required this.supplierName,
    this.supplierTaxId = '',
    this.categoryName = 'Sin categoría',
    required this.number,
    this.authorizationCode = '',
    this.fiscalCode = '',
    required this.issueDate,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.currency = 'BOB',
    this.paymentMethod = '',
    this.qrContent = '',
    this.rawOcrText = '',
    this.status = InvoiceStatus.draft,
    required this.createdAt,
    this.items = const [],
    this.images = const [],
  });

  final int? id;
  final int? supplierId;
  final int? categoryId;
  final String supplierName;
  final String supplierTaxId;
  final String categoryName;
  final String number;
  final String authorizationCode;
  final String fiscalCode;
  final DateTime issueDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String currency;
  final String paymentMethod;
  final String qrContent;
  final String rawOcrText;
  final InvoiceStatus status;
  final DateTime createdAt;
  final List<InvoiceItem> items;
  final List<InvoiceImage> images;

  double get calculatedItemsTotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  bool get totalsAreConsistent {
    if (items.isEmpty) return true;
    return (calculatedItemsTotal - subtotal).abs() < 0.05;
  }

  Invoice copyWith({
    int? id,
    int? supplierId,
    int? categoryId,
    String? supplierName,
    String? supplierTaxId,
    String? categoryName,
    String? number,
    String? authorizationCode,
    String? fiscalCode,
    DateTime? issueDate,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? currency,
    String? paymentMethod,
    String? qrContent,
    String? rawOcrText,
    InvoiceStatus? status,
    DateTime? createdAt,
    List<InvoiceItem>? items,
    List<InvoiceImage>? images,
  }) {
    return Invoice(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      categoryId: categoryId ?? this.categoryId,
      supplierName: supplierName ?? this.supplierName,
      supplierTaxId: supplierTaxId ?? this.supplierTaxId,
      categoryName: categoryName ?? this.categoryName,
      number: number ?? this.number,
      authorizationCode: authorizationCode ?? this.authorizationCode,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      issueDate: issueDate ?? this.issueDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      qrContent: qrContent ?? this.qrContent,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      images: images ?? this.images,
    );
  }
}
