import 'package:flutter/foundation.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/ports/document_capture_port.dart';
import '../services/receipt_parser.dart';

class CaptureViewModel extends ChangeNotifier {
  CaptureViewModel(this._capturePort, this._parser);

  final DocumentCapturePort _capturePort;
  final ReceiptParser _parser;
  final List<CapturedDocumentSection> _sections = [];

  List<CapturedDocumentSection> get sections => List.unmodifiable(_sections);
  bool isBusy = false;
  String? error;
  String qrContent = '';

  Future<void> capture(CaptureSource source) async {
    if (isBusy) return;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final result = await _capturePort.capture(source, _sections.length);
      if (result != null) _sections.add(result);
    } catch (exception) {
      error = 'No se pudo procesar la imagen: $exception';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> removeSection(int index) async {
    if (index < 0 || index >= _sections.length) return;
    final section = _sections.removeAt(index);
    // Page indices are positional. Leaving the old ones in place lets the next
    // capture reuse an index (it is assigned from `_sections.length`), which
    // scrambles the OCR merge order and writes duplicate page_index rows.
    for (var i = 0; i < _sections.length; i++) {
      _sections[i] = _sections[i].copyWith(pageIndex: i);
    }
    notifyListeners();
    await _delete(section);
  }

  void setQrContent(String value) {
    qrContent = value;
    notifyListeners();
  }

  Invoice buildDraft() {
    if (_sections.isEmpty) {
      throw StateError('Agrega al menos una imagen de la factura.');
    }
    return _parser.parse(_sections, qrContent: qrContent);
  }

  Future<void> discard() async {
    final discarded = List<CapturedDocumentSection>.from(_sections);
    _sections.clear();
    qrContent = '';
    error = null;
    isBusy = false;
    notifyListeners();
    for (final section in discarded) {
      await _delete(section);
    }
  }

  Future<void> _delete(CapturedDocumentSection section) async {
    try {
      await _capturePort.delete(section);
    } catch (exception) {
      error = 'No se pudo eliminar una imagen descartada: $exception';
      notifyListeners();
    }
  }
}
