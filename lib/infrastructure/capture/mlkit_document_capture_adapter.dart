import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/ports/document_capture_port.dart';

/// Bundled sample receipt used for testing the capture → OCR → review
/// pipeline without a camera or gallery image (see pubspec.yaml assets).
const String _sampleReceiptAsset =
    'assets/sample_receipts/factura_zumarket.jpg';

class MlKitDocumentCaptureAdapter implements DocumentCapturePort {
  MlKitDocumentCaptureAdapter({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  Future<CapturedDocumentSection?> capture(
    CaptureSource source,
    int pageIndex,
  ) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final receiptDirectory = Directory(p.join(appDirectory.path, 'receipts'));
    await receiptDirectory.create(recursive: true);

    String sourceImagePath;
    String extension;

    if (source == CaptureSource.sample) {
      // Copy the bundled sample receipt out of the asset bundle so it can be
      // treated the same way as a captured/picked image from here on.
      final bytes = await rootBundle.load(_sampleReceiptAsset);
      extension = p.extension(_sampleReceiptAsset);
      final tempPath = p.join(
        receiptDirectory.path,
        'sample_source_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      sourceImagePath = tempFile.path;
    } else {
      final image = await _picker.pickImage(
        source: source == CaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (image == null) return null;
      sourceImagePath = image.path;
      extension = p.extension(image.path).isEmpty
          ? '.jpg'
          : p.extension(image.path).toLowerCase();
    }

    final destination = p.join(
      receiptDirectory.path,
      'receipt_${DateTime.now().microsecondsSinceEpoch}_$pageIndex$extension',
    );
    final persistentImage = await File(sourceImagePath).copy(destination);
    if (source == CaptureSource.sample) {
      // Clean up the intermediate copy pulled from the asset bundle.
      final temp = File(sourceImagePath);
      if (await temp.exists()) await temp.delete();
    }
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(persistentImage.path),
    );
    return CapturedDocumentSection(
      path: persistentImage.path,
      ocrText: recognized.text,
      pageIndex: pageIndex,
    );
  }

  @override
  Future<void> delete(CapturedDocumentSection section) async {
    final file = File(section.path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
