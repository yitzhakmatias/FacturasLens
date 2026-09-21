import 'package:flutter_test/flutter_test.dart';
import 'package:invoicereader/application/services/receipt_parser.dart';
import 'package:invoicereader/domain/ports/document_capture_port.dart';

CapturedDocumentSection _section(String text, {int page = 0}) =>
    CapturedDocumentSection(path: 'page$page.jpg', ocrText: text, pageIndex: page);

const _receipt = '''
SUPERMERCADO ZETA S.A.
NIT: 1020703023
FACTURA N° 4567
FECHA DE EMISION: 15/08/2026
DETALLE
PAN INTEGRAL 12.00 12.00
SUBTOTAL 112.00
DESCUENTO 2.00
TOTAL 110.00
''';

void main() {
  const parser = ReceiptParser();

  group('ReceiptParser', () {
    test('merges overlapping sections in page order', () {
      final invoice = parser.parse([
        // Deliberately out of order: the parser must sort by pageIndex.
        _section('C\nD\nE', page: 1),
        _section('A\nB\nC\nD', page: 0),
      ]);

      expect(invoice.rawOcrText, 'A\nB\nC\nD\nE');
      expect(invoice.images.map((image) => image.pageIndex), [1, 0]);
    });

    test('extracts header fields and keeps SUBTOTAL apart from TOTAL', () {
      final invoice = parser.parse([_section(_receipt)]);

      expect(invoice.supplierName, 'Supermercado Zeta S.a.');
      expect(invoice.supplierTaxId, '1020703023');
      expect(invoice.number, '4567');
      expect(invoice.issueDate, DateTime(2026, 8, 15));
      expect(invoice.subtotal, 112.00);
      expect(invoice.discount, 2.00);
      expect(invoice.total, 110.00);
      expect(invoice.items, hasLength(1));
      expect(invoice.items.single.description, 'PAN INTEGRAL');
    });

    test('a labelled issue date wins over an earlier unlabelled date', () {
      final invoice = parser.parse([
        _section('VENCE 01/01/2030\nFECHA DE EMISION: 15/08/2026'),
      ]);

      expect(invoice.issueDate, DateTime(2026, 8, 15));
    });

    test('an impossible date falls back to now instead of rolling over', () {
      final before = DateTime.now();
      final invoice = parser.parse([_section('FECHA: 45/13/2026')]);

      expect(
        invoice.issueDate.difference(before).inMinutes.abs(),
        lessThan(1),
      );
    });

    test('QR data overrides OCR guesses', () {
      final invoice = parser.parse(
        [_section(_receipt)],
        qrContent: '9999999|1|290400|20/09/2026|111.11',
      );

      expect(invoice.supplierTaxId, '9999999');
      expect(invoice.number, '1');
      expect(invoice.issueDate, DateTime(2026, 9, 20));
      expect(invoice.total, 111.11);
      // Fields the QR does not carry still come from OCR.
      expect(invoice.subtotal, 112.00);
    });
  });
}
