import 'package:flutter_test/flutter_test.dart';
import 'package:invoicereader/application/services/receipt_parser.dart';
import 'package:invoicereader/application/view_models/capture_view_model.dart';
import 'package:invoicereader/domain/ports/document_capture_port.dart';

void main() {
  test('discard removes every unsaved captured image', () async {
    final port = _FakeCapturePort();
    final model = CaptureViewModel(port, ReceiptParser());

    await model.capture(CaptureSource.camera);
    await model.capture(CaptureSource.gallery);
    await model.discard();

    expect(model.sections, isEmpty);
    expect(port.deletedPaths, ['receipt-0.jpg', 'receipt-1.jpg']);
  });
}

class _FakeCapturePort implements DocumentCapturePort {
  final deletedPaths = <String>[];
  var _nextPage = 0;

  @override
  Future<CapturedDocumentSection?> capture(
    CaptureSource source,
    int pageIndex,
  ) async {
    final page = _nextPage++;
    return CapturedDocumentSection(
      path: 'receipt-$page.jpg',
      ocrText: 'FACTURA',
      pageIndex: pageIndex,
    );
  }

  @override
  Future<void> delete(CapturedDocumentSection section) async {
    deletedPaths.add(section.path);
  }

  @override
  Future<void> dispose() async {}
}
