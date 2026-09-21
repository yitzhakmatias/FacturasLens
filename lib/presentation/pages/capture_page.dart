import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/services/receipt_parser.dart';
import '../../application/view_models/capture_view_model.dart';
import '../../domain/ports/document_capture_port.dart';
import '../core/app_theme.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/qr_scan_sheet.dart';
import 'review_page.dart';

class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CaptureViewModel>(
      create: (context) => CaptureViewModel(
        context.read<DocumentCapturePort>(),
        context.read<ReceiptParser>(),
      ),
      child: const _CaptureView(),
    );
  }
}

class _CaptureView extends StatelessWidget {
  const _CaptureView();

  Future<bool> _confirmDiscard(BuildContext context) async {
    final model = context.read<CaptureViewModel>();
    if (model.sections.isEmpty) return true;
    return showDestructiveConfirmDialog(
      context,
      title: 'Descartar captura',
      message:
          'Tienes ${model.sections.length} sección(es) capturadas. '
          '¿Descartarlas y salir?',
      confirmLabel: 'Descartar',
    );
  }

  Future<void> _continue(BuildContext context) async {
    final model = context.read<CaptureViewModel>();
    final draft = model.buildDraft();
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ReviewPage(invoice: draft)));
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _scanQr(BuildContext context) async {
    final value = await showQrScanSheet(context);
    if (value != null && context.mounted) {
      context.read<CaptureViewModel>().setQrContent(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptureViewModel>(
      builder: (context, model, _) {
        return PopScope(
          canPop: model.sections.isEmpty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmDiscard(context) && context.mounted) {
              await model.discard();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Escanear factura')),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .22),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.document_scanner_rounded,
                            color: Colors.white,
                            size: 31,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Captura ${model.sections.length + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fotografía cada tramo del ticket. Deja un pequeño '
                          'solapamiento con la sección anterior para no '
                          'perder texto entre fotos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: model.isBusy
                              ? null
                              : () => model.capture(CaptureSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Cámara'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: model.isBusy
                              ? null
                              : () => model.capture(CaptureSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: model.isBusy
                          ? null
                          : () => model.capture(CaptureSource.sample),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Cargar factura de muestra'),
                    ),
                  ),
                  if (model.isBusy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text(
                      'Procesando OCR…',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ],
                  if (model.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.reviewSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        model.error!,
                        style: const TextStyle(color: AppColors.review),
                      ),
                    ),
                  ],
                  if (model.sections.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Secciones capturadas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (
                          var index = 0;
                          index < model.sections.length;
                          index++
                        )
                          _SectionThumbnail(
                            path: model.sections[index].path,
                            index: index,
                            onRemove: () => model.removeSection(index),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: model.isBusy ? null : () => _scanQr(context),
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: Text(
                      model.qrContent.isEmpty
                          ? 'Escanear código QR'
                          : 'Código QR capturado · escanear otro',
                    ),
                  ),
                  if (model.qrContent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => model.setQrContent(''),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Quitar QR'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton(
                  onPressed: model.sections.isEmpty || model.isBusy
                      ? null
                      : () => _continue(context),
                  child: const Text('Continuar a revisión'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionThumbnail extends StatelessWidget {
  const _SectionThumbnail({
    required this.path,
    required this.index,
    required this.onRemove,
  });

  final String path;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          left: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
