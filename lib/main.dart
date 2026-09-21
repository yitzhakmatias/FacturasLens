import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'application/services/receipt_parser.dart';
import 'application/view_models/invoices_view_model.dart';
import 'domain/ports/catalog_repository.dart';
import 'domain/ports/document_capture_port.dart';
import 'domain/ports/invoice_repository.dart';
import 'infrastructure/capture/mlkit_document_capture_adapter.dart';
import 'infrastructure/database/app_database.dart';
import 'infrastructure/repositories/sqlite_invoice_repository.dart';
import 'presentation/app_shell.dart';
import 'presentation/core/app_routes.dart';
import 'presentation/core/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final repository = SqliteInvoiceRepository(AppDatabase());
  runApp(FacturaLensBootstrap(repository: repository));
}

class FacturaLensBootstrap extends StatelessWidget {
  const FacturaLensBootstrap({
    super.key,
    required this.repository,
    this.capturePort,
  });

  final SqliteInvoiceRepository repository;
  final DocumentCapturePort? capturePort;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<InvoiceRepository>.value(value: repository),
        Provider<CatalogRepository>.value(value: repository),
        Provider<ReceiptParser>(create: (_) => ReceiptParser()),
        Provider<DocumentCapturePort>(
          create: (_) => capturePort ?? MlKitDocumentCaptureAdapter(),
          dispose: (_, port) => unawaited(port.dispose()),
        ),
        ChangeNotifierProvider<InvoicesViewModel>(
          create: (_) => InvoicesViewModel(repository, repository)..load(),
        ),
      ],
      child: const FacturaLensApp(),
    );
  }
}

class FacturaLensApp extends StatelessWidget {
  const FacturaLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FacturaLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const AppShell(),
    );
  }
}
