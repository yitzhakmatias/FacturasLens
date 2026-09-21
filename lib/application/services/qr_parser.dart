/// Structured data recovered from an invoice QR code.
///
/// Every field is nullable on purpose: the parser only fills what it can read
/// with confidence, and the caller treats anything left null as "keep whatever
/// OCR guessed".
class QrInvoiceData {
  const QrInvoiceData({
    this.supplierTaxId,
    this.number,
    this.authorizationCode,
    this.fiscalCode,
    this.issueDate,
    this.total,
    this.buyerTaxId,
  });

  final String? supplierTaxId;
  final String? number;
  final String? authorizationCode;
  final String? fiscalCode;
  final DateTime? issueDate;
  final double? total;
  final String? buyerTaxId;

  bool get isEmpty =>
      supplierTaxId == null &&
      number == null &&
      authorizationCode == null &&
      fiscalCode == null &&
      issueDate == null &&
      total == null &&
      buyerTaxId == null;

  bool get isNotEmpty => !isEmpty;
}

/// Reads the payload of a Bolivian invoice QR code.
///
/// Three shapes are supported, tried in order:
///
/// 1. **SIAT URL** (facturación en línea) —
///    `https://siat.impuestos.gob.bo/consulta/QR?nit=...&cuf=...&numero=...`
/// 2. **Key/value pairs** — `nit=123|numero=45|cuf=ABC`, tolerant of `|`, `;`,
///    `&` and newline separators.
/// 3. **Legacy positional, pipe-delimited** — the pre-SIAT layout:
///    `NIT | nº factura | nº autorización | fecha | total | total IVA |
///     código de control | NIT/CI cliente | monto ICE`
///
/// Anything it cannot make sense of yields an empty [QrInvoiceData] rather
/// than an exception — a scanned code must never be able to crash the capture
/// flow. The QR layout is not fully uniform across Bolivian issuers, so verify
/// the positional branch against a receipt you actually hold before trusting
/// it; unknown shapes degrade to "no fields recovered", which is safe.
class QrParser {
  const QrParser();

  QrInvoiceData parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const QrInvoiceData();

    final fromUrl = _parseUrl(value);
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;

    final fromPairs = _parseKeyValuePairs(value);
    if (fromPairs != null && fromPairs.isNotEmpty) return fromPairs;

    return _parsePositional(value);
  }

  // ---------------------------------------------------------------- shapes

  QrInvoiceData? _parseUrl(String value) {
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final params = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key.toLowerCase(): entry.value,
    };
    if (params.isEmpty) return null;
    return _fromMap(params);
  }

  QrInvoiceData? _parseKeyValuePairs(String value) {
    final tokens = value.split(RegExp(r'[|;&\r\n]+'));
    final params = <String, String>{};
    for (final token in tokens) {
      final separator = token.indexOf('=');
      if (separator <= 0) continue;
      final key = token.substring(0, separator).trim().toLowerCase();
      final entry = token.substring(separator + 1).trim();
      if (key.isEmpty || entry.isEmpty) continue;
      params[key] = entry;
    }
    if (params.isEmpty) return null;
    return _fromMap(params);
  }

  QrInvoiceData _parsePositional(String value) {
    final fields = value
        .split('|')
        .map((field) => field.trim())
        .toList(growable: false);
    // Below five fields this is almost certainly not an invoice QR — better to
    // recover nothing than to mislabel arbitrary text as a NIT.
    if (fields.length < 5) return const QrInvoiceData();

    String? at(int index) {
      if (index >= fields.length) return null;
      final field = fields[index];
      return field.isEmpty ? null : field;
    }

    return QrInvoiceData(
      supplierTaxId: _digitsOrNull(at(0)),
      number: _digitsOrNull(at(1)),
      authorizationCode: at(2),
      issueDate: _parseDate(at(3)),
      total: _parseAmount(at(4)),
      fiscalCode: at(6),
      buyerTaxId: _digitsOrNull(at(7)),
    );
  }

  QrInvoiceData _fromMap(Map<String, String> params) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = params[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final cuf = pick(['cuf', 'codigofiscal', 'codigo_fiscal']);
    return QrInvoiceData(
      supplierTaxId: _digitsOrNull(
        pick(['nit', 'nitemisor', 'nit_emisor', 'nitev']),
      ),
      number: _digitsOrNull(
        pick(['numero', 'nrofactura', 'numerofactura', 'nro', 'nf']),
      ),
      authorizationCode: pick([
        'autorizacion',
        'nroautorizacion',
        'numeroautorizacion',
        'cuis',
      ]),
      fiscalCode: cuf,
      issueDate: _parseDate(pick(['fecha', 'fechaemision', 'fecha_emision'])),
      total: _parseAmount(pick(['total', 'monto', 'montototal', 'importe'])),
      buyerTaxId: _digitsOrNull(
        pick(['nitcliente', 'nit_cliente', 'nitci', 'documentocliente'])),
    );
  }

  // ----------------------------------------------------------------- atoms

  String? _digitsOrNull(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  double? _parseAmount(String? value) {
    if (value == null) return null;
    // Strip currency noise, then normalise the decimal separator. Thousands
    // separators are dropped only when they are unambiguous (a comma or dot
    // followed by exactly three digits that is not the last separator).
    var cleaned = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
    if (cleaned.isEmpty) return null;
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    final decimalAt = lastComma > lastDot ? lastComma : lastDot;
    if (decimalAt >= 0) {
      final head = cleaned
          .substring(0, decimalAt)
          .replaceAll(RegExp(r'[.,]'), '');
      final tail = cleaned.substring(decimalAt + 1);
      cleaned = tail.isEmpty ? head : '$head.$tail';
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }

  DateTime? _parseDate(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})|(\d{1,2})[-/](\d{1,2})[-/](\d{4})',
    ).firstMatch(value);
    if (match == null) {
      // SIAT sometimes encodes the date as a compact yyyyMMdd run of digits.
      final compact = RegExp(r'\b(\d{4})(\d{2})(\d{2})\b').firstMatch(value);
      if (compact == null) return null;
      return _safeDate(
        int.parse(compact.group(1)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(3)!),
      );
    }
    if (match.group(1) != null) {
      return _safeDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    return _safeDate(
      int.parse(match.group(6)!),
      int.parse(match.group(5)!),
      int.parse(match.group(4)!),
    );
  }

  /// Rejects impossible dates instead of letting [DateTime] silently roll
  /// them over — `DateTime(2026, 13, 45)` quietly becomes February 2027.
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
}
