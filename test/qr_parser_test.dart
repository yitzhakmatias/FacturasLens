import 'package:flutter_test/flutter_test.dart';
import 'package:invoicereader/application/services/qr_parser.dart';

void main() {
  const parser = QrParser();

  group('QrParser', () {
    test('reads a SIAT consultation URL', () {
      final data = parser.parse(
        'https://siat.impuestos.gob.bo/consulta/QR'
        '?nit=1020703023&cuf=ABC123DEF&numero=4567&t=2',
      );

      expect(data.supplierTaxId, '1020703023');
      expect(data.number, '4567');
      expect(data.fiscalCode, 'ABC123DEF');
      expect(data.total, isNull);
    });

    test('reads the legacy positional pipe-delimited layout', () {
      final data = parser.parse(
        '1020703023|4567|29040011007|20/09/2026|152.50|152.50|7A-3F-2B|1234567|0',
      );

      expect(data.supplierTaxId, '1020703023');
      expect(data.number, '4567');
      expect(data.authorizationCode, '29040011007');
      expect(data.issueDate, DateTime(2026, 9, 20));
      expect(data.total, 152.50);
      expect(data.fiscalCode, '7A-3F-2B');
      expect(data.buyerTaxId, '1234567');
    });

    test('reads key/value pairs and a thousands-separated amount', () {
      final data = parser.parse(
        'nit=1020703023|numero=88|fecha=2026-09-01|total=1.234,50',
      );

      expect(data.supplierTaxId, '1020703023');
      expect(data.number, '88');
      expect(data.issueDate, DateTime(2026, 9, 1));
      expect(data.total, 1234.50);
    });

    test('rejects impossible dates instead of rolling them over', () {
      final data = parser.parse('1020703023|4567|290400|31/02/2026|10.00');

      expect(data.issueDate, isNull);
      expect(data.total, 10.00);
    });

    test('returns empty data for text that is not an invoice QR', () {
      expect(parser.parse('hello world').isEmpty, isTrue);
      expect(parser.parse('').isEmpty, isTrue);
      expect(parser.parse('a|b|c').isEmpty, isTrue);
    });
  });
}
