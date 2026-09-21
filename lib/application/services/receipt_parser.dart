import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_image.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/ports/document_capture_port.dart';
import 'qr_parser.dart';

class ReceiptParser {
  const ReceiptParser({QrParser qrParser = const QrParser()})
    : _qrParser = qrParser;

  final QrParser _qrParser;

  Invoice parse(
    List<CapturedDocumentSection> sections, {
    String qrContent = '',
  }) {
    final rawText = _mergeSections(sections);
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final normalized = _normalize(rawText);
    final now = DateTime.now();
    final subtotal = _moneyAfterLabel(normalized, 'SUB[ -]?TOTAL') ?? 0;
    final discount = _moneyAfterLabel(normalized, 'DESCUENTO') ?? 0;
    final total =
        _moneyAfterLabel(normalized, r'(?:^|\n)TOTAL') ??
        _moneyAfterLabel(normalized, 'MONTO A PAGAR') ??
        subtotal;

    // The QR is machine-written, so anything it yields beats the OCR guess.
    final qr = qrContent.trim().isEmpty
        ? const QrInvoiceData()
        : _qrParser.parse(qrContent);

    return Invoice(
      supplierName: _supplierName(lines),
      supplierTaxId:
          qr.supplierTaxId ??
          _firstGroup(
            normalized,
            RegExp(r'(?:^|\n)\s*NIT\s*[:.]?\s*(\d{5,})'),
          ) ??
          '',
      number:
          qr.number ??
          _firstGroup(
            normalized,
            RegExp(r'FACTURA\s*(?:N[RO°º.]*)?\s*[:.]?\s*(\d+)'),
          ) ??
          '',
      authorizationCode:
          qr.authorizationCode ??
          _firstGroup(
            normalized,
            RegExp(r'(?:COD\.?\s*)?AUTORIZACI[OÓ]N\s*[:.]?\s*([A-Z0-9]+)'),
          ) ??
          '',
      fiscalCode:
          qr.fiscalCode ??
          _firstGroup(
            normalized,
            RegExp(r'(?:CUF|C[OÓ]DIGO\s+FISCAL)\s*[:.]?\s*([A-Z0-9]+)'),
          ) ??
          '',
      issueDate: qr.issueDate ?? _parseDate(normalized) ?? now,
      subtotal: subtotal,
      discount: discount,
      total: qr.total ?? total,
      paymentMethod: _paymentMethod(lines),
      qrContent: qrContent,
      rawOcrText: rawText,
      status: InvoiceStatus.draft,
      createdAt: now,
      items: _parseItems(lines),
      images: sections
          .map(
            (section) => InvoiceImage(
              path: section.path,
              pageIndex: section.pageIndex,
              ocrText: section.ocrText,
            ),
          )
          .toList(growable: false),
    );
  }

  String _mergeSections(List<CapturedDocumentSection> sections) {
    final merged = <String>[];
    for (final section in [
      ...sections,
    ]..sort((a, b) => a.pageIndex.compareTo(b.pageIndex))) {
      final incoming = section.ocrText
          .split(RegExp(r'[\r\n]+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      var overlap = 0;
      final maxOverlap = merged.length < incoming.length
          ? merged.length.clamp(0, 12)
          : incoming.length.clamp(0, 12);
      for (var size = maxOverlap; size > 0; size--) {
        final tail = merged
            .sublist(merged.length - size)
            .map(_lineKey)
            .join('|');
        final head = incoming.sublist(0, size).map(_lineKey).join('|');
        if (tail == head) {
          overlap = size;
          break;
        }
      }
      merged.addAll(incoming.skip(overlap));
    }
    return merged.join('\n');
  }

  String _lineKey(String value) => _normalize(value).replaceAll(' ', '');

  String _normalize(String value) => value
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  String _supplierName(List<String> lines) {
    for (final line in lines.take(8)) {
      final normalized = _normalize(line);
      if (normalized.length >= 4 &&
          !normalized.contains('FACTURA') &&
          !normalized.startsWith('NIT') &&
          !normalized.contains('SUCURSAL') &&
          RegExp(r'[A-Z]').hasMatch(normalized)) {
        return _titleCase(line);
      }
    }
    return 'Proveedor por revisar';
  }

  String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String? _firstGroup(String text, RegExp expression) {
    return expression.firstMatch(text)?.group(1)?.trim();
  }

  double? _moneyAfterLabel(String text, String labelPattern) {
    final expression = RegExp(
      '$labelPattern[^\\n\\d]{0,18}(\\d+[.,]\\d{2})',
      multiLine: true,
    );
    return _parseMoney(expression.firstMatch(text)?.group(1));
  }

  double? _parseMoney(String? value) {
    if (value == null) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  /// Reads the issue date.
  ///
  /// A labelled match (`FECHA DE EMISION: …`) always wins; only if there is no
  /// label do we fall back to the first date-shaped token in the document,
  /// which is a coin flip on receipts that also print a due date or a promo
  /// date. Impossible dates are rejected rather than silently rolled over by
  /// [DateTime] — `DateTime(2026, 13, 45)` quietly becomes February 2027.
  DateTime? _parseDate(String text) {
    const datePattern =
        r'(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})';
    final labelled = RegExp(
      r'FECHA(?:\s+DE)?\s*(?:EMISI[OÓ]N)?\s*[:.]?[^\d\n]{0,10}' + datePattern,
    ).firstMatch(text);
    final match = labelled ?? RegExp(datePattern).firstMatch(text);
    final value = match?.group(1);
    if (value == null) return null;

    final parts = value.split(RegExp('[-/]')).map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    final numbers = parts.cast<int>();
    if (numbers.first > 31) {
      return _safeDate(numbers[0], numbers[1], numbers[2]);
    }
    return _safeDate(numbers[2], numbers[1], numbers[0]);
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String _paymentMethod(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final normalized = _normalize(lines[index]);
      if (normalized.contains('METODO DE PAGO')) {
        final parts = lines[index].split(':');
        if (parts.length > 1 && parts.last.trim().isNotEmpty) {
          return parts.skip(1).join(':').trim();
        }
        if (index + 1 < lines.length) return lines[index + 1];
      }
    }
    return '';
  }

  List<InvoiceItem> _parseItems(List<String> lines) {
    final detailIndex = lines.indexWhere(
      (line) => _normalize(line).contains('DETALLE'),
    );
    final subtotalIndex = lines.indexWhere(
      (line) => RegExp(r'^SUB[ -]?TOTAL').hasMatch(_normalize(line)),
    );
    if (detailIndex < 0 || subtotalIndex <= detailIndex) return const [];

    final items = <InvoiceItem>[];
    final fullRow = RegExp(
      r'^([\d.,]+)\s+(.+?)\s+([\d.,]+)\s+([\d.,]+)\s+([\d.,]+)$',
    );
    final simpleRow = RegExp(r'^(.+?[A-Za-zÁÉÍÓÚÑ])\s+([\d.,]+)\s+([\d.,]+)$');
    for (final rawLine in lines.sublist(detailIndex + 1, subtotalIndex)) {
      final line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();
      final full = fullRow.firstMatch(line);
      if (full != null) {
        final quantity = _parseMoney(full.group(1)) ?? 1;
        final unit = _parseMoney(full.group(3)) ?? 0;
        final discount = _parseMoney(full.group(4)) ?? 0;
        final total = _parseMoney(full.group(5)) ?? quantity * unit;
        items.add(
          InvoiceItem(
            description: full.group(2)!.trim(),
            quantity: quantity,
            unitPrice: unit,
            discount: discount,
            lineTotal: total,
          ),
        );
        continue;
      }
      final simple = simpleRow.firstMatch(line);
      if (simple != null) {
        final unit = _parseMoney(simple.group(2)) ?? 0;
        final total = _parseMoney(simple.group(3)) ?? unit;
        items.add(
          InvoiceItem(
            description: simple.group(1)!.trim(),
            unitPrice: unit,
            lineTotal: total,
          ),
        );
      }
    }
    return items;
  }
}
