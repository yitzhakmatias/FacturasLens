import 'package:flutter/material.dart';

import '../pages/capture_page.dart';
import '../pages/invoice_detail_page.dart';

/// Centralizes the named routes demonstrated by the application.
abstract final class AppRoutes {
  static const capture = '/capture';
  static const invoiceDetail = '/invoice-detail';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case capture:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CapturePage(),
        );
      case invoiceDetail:
        final arguments = settings.arguments! as InvoiceDetailArguments;
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => InvoiceDetailPage(invoiceId: arguments.invoiceId),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Ruta no encontrada'))),
        );
    }
  }
}

class InvoiceDetailArguments {
  const InvoiceDetailArguments(this.invoiceId);

  final int invoiceId;
}
