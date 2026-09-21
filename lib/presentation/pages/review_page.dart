import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice.dart';
import '../core/formatters.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/image_carousel.dart';
import '../widgets/invoice_form.dart';

/// Shows the OCR draft for human review: photographs on one side, editable
/// fields and items on the other. Nothing is persisted until the user taps
/// "Guardar borrador" or "Confirmar y guardar" inside [InvoiceForm].
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _saving = false;

  Future<void> _handleSave(Invoice invoice) async {
    final model = context.read<InvoicesViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (invoice.status == InvoiceStatus.verified) {
      // Asks the database, not the in-memory list: that list is filtered by
      // whatever search/status/category the user left active, so a real
      // duplicate could easily be missing from it.
      final Invoice? existing;
      try {
        existing = await model.findDuplicate(invoice);
      } catch (exception) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('No se pudo verificar duplicados: $exception'),
          ),
        );
        return;
      }
      if (existing != null) {
        if (!mounted) return;
        final proceed = await showConfirmDialog(
          context,
          title: 'Posible factura duplicada',
          message:
              'Ya existe una factura de "${existing.supplierName}" '
              'N.º ${existing.number} del '
              '${AppFormatters.shortDate(existing.issueDate)} por '
              '${AppFormatters.money(existing.total)}. '
              '¿Guardar de todas formas?',
          confirmLabel: 'Guardar de todas formas',
        );
        if (!proceed || !mounted) return;
      }
    }

    setState(() => _saving = true);
    try {
      await model.saveInvoice(invoice);
      navigator.pop(true);
    } catch (exception) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo guardar la factura: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<InvoicesViewModel>();
    final imagePaths = widget.invoice.images
        .map((image) => image.path)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar extracción')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final form = InvoiceForm(
            invoice: widget.invoice,
            categories: model.categories,
            suppliers: model.suppliers,
            busy: _saving,
            onSave: _handleSave,
          );
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.42,
                  child: ImageCarousel(paths: imagePaths),
                ),
                Expanded(child: form),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: 260, child: ImageCarousel(paths: imagePaths)),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}
