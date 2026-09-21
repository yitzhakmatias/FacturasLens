import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';

/// Whether `mobile_scanner` actually ships an implementation for the current
/// platform.
///
/// The plugin only registers for Android, iOS, macOS and web — on Windows and
/// Linux there is no native side at all, so building a [MobileScanner] there
/// throws a `MissingPluginException` and the preview stays black forever.
/// On those platforms we go straight to manual entry instead.
bool get scannerIsSupported {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// Opens the QR scanner and resolves with the decoded payload, or `null` if
/// the user backed out.
///
/// Falls back to a manual-entry dialog on platforms without a camera scanner.
Future<String?> showQrScanSheet(BuildContext context) async {
  if (!scannerIsSupported) {
    return showManualQrEntryDialog(context);
  }
  return Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const _QrScanPage()));
}

/// Last-resort escape hatch: lets the user paste or type the QR payload.
///
/// This is what keeps the feature usable when the camera permission has been
/// permanently denied, when the device has no usable camera, and on desktop.
Future<String?> showManualQrEntryDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ingresar código QR'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pega aquí el contenido del código QR de la factura.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'https://siat.impuestos.gob.bo/... o 1234567|89|...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(dialogContext).pop(value.isEmpty ? null : value);
          },
          child: const Text('Usar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  /// Restarting the scanner after an error needs a fresh widget subtree,
  /// because [MobileScanner] initialises its controller exactly once in
  /// `initState`. Bumping this key rebuilds it from scratch.
  int _attempt = 0;
  MobileScannerController _controller = _newController();
  bool _handled = false;

  static MobileScannerController _newController() => MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value.trim());
        return;
      }
    }
  }

  void _retry() {
    final old = _controller;
    setState(() {
      _attempt++;
      _controller = _newController();
    });
    unawaited(old.dispose());
  }

  Future<void> _enterManually() async {
    final value = await showManualQrEntryDialog(context);
    if (value != null && mounted) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Escanear código QR'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Apagar linterna' : 'Encender linterna',
                icon: Icon(
                  on ? Icons.flashlight_on : Icons.flashlight_off_outlined,
                ),
                onPressed: () => unawaited(_controller.toggleTorch()),
              );
            },
          ),
          IconButton(
            tooltip: 'Ingresar manualmente',
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _enterManually,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            key: ValueKey(_attempt),
            controller: _controller,
            onDetect: _onDetect,
            onDetectError: (error, stack) =>
                debugPrint('QR detect error: $error'),
            fit: BoxFit.cover,
            placeholderBuilder: (context) => const ColoredBox(
              color: AppColors.ink,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Iniciando la cámara…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            errorBuilder: (context, error) {
              // Surface the real reason in the console too: a silent black
              // preview is exactly what made this impossible to diagnose.
              debugPrint('MobileScanner error: $error');
              return _ScannerError(
                error: error,
                onRetry: _retry,
                onManualEntry: _enterManually,
              );
            },
          ),
          // The framing square and hint only make sense over a live preview.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isRunning || state.error != null) {
                return const SizedBox.shrink();
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 32,
                    left: 24,
                    right: 24,
                    child: Text(
                      'Apunta al código QR impreso en la factura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Replaces `mobile_scanner`'s default error widget — a black box with a tiny
/// white icon — with something that says what went wrong and offers a way out.
class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.error,
    required this.onRetry,
    required this.onManualEntry,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  (String, String) get _message {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return (
          'Sin permiso de cámara',
          'FacturaLens necesita la cámara para leer el código QR. '
              'Concede el permiso en Ajustes › Aplicaciones › FacturaLens › '
              'Permisos › Cámara y vuelve a intentarlo.',
        );
      case MobileScannerErrorCode.unsupported:
        return (
          'No disponible en este dispositivo',
          'El lector de códigos QR no está soportado aquí. Puedes ingresar '
              'el contenido del QR manualmente.',
        );
      case MobileScannerErrorCode.controllerInitializing:
        return (
          'La cámara sigue iniciando',
          'Espera un momento y vuelve a intentarlo.',
        );
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerNotAttached:
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.genericError:
        return (
          'No se pudo abrir la cámara',
          error.errorDetails?.message ?? error.errorCode.message,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, detail) = _message;
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 44,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                '(${error.errorCode.name})',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Ingresar el código manualmente'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

