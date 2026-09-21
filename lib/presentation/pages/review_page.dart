import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice.dart';
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

  bool _looksDuplicate(Invoice candidate, List<Invoice> existing) {
    if (candidate.number.trim().isEmpty) return false;
    return existing.any(
      (invoice) =>
          invoice.id != candidate.id &&
          invoice.number.trim() == candidate.number.trim() &&
          invoice.supplierName.trim().toLowerCase() ==
              candidate.supplierName.trim().toLowerCase() &&
          invoice.issueDate.year == candidate.issueDate.year &&
          invoice.issueDate.month == candidate.issueDate.month &&
          invoice.issueDate.day == candidate.issueDate.day,
    );
  }

  Future<void> _handleSave(Invoice invoice) async {
    final model = context.read<InvoicesViewModel>();
    if (invoice.status == InvoiceStatus.verified &&
        _looksDuplicate(invoice, model.invoices)) {
      final proceed = await showConfirmDialog(
        context,
        title: 'Posible factura duplicada',
        message:
            'Ya existe una factura de "${invoice.supplierName}" con el '
            'mismo número y fecha. ¿Guardar de todas formas?',
        confirmLabel: 'Guardar de todas formas',
      );
      if (!proceed) return;
    }

    setState(() => _saving = true);
    try {
      await model.saveInvoice(invoice);
      if (mounted) Navigator.of(context).pop(true);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
