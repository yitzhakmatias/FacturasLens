enum CaptureSource { camera, gallery, sample }

class CapturedDocumentSection {
  const CapturedDocumentSection({
    required this.path,
    required this.ocrText,
    required this.pageIndex,
  });

  final String path;
  final String ocrText;
  final int pageIndex;
}

abstract interface class DocumentCapturePort {
  Future<CapturedDocumentSection?> capture(CaptureSource source, int pageIndex);

  /// Removes an image that was captured but never attached to a saved invoice.
  Future<void> delete(CapturedDocumentSection section);

  Future<void> dispose();
}
