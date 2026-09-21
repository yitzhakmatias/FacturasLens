import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/image_carousel.dart';
import '../widgets/invoice_form.dart';
import '../widgets/status_chip.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invoice = await context.read<InvoicesViewModel>().invoiceById(
      widget.invoiceId,
    );
    if (!mounted) return;
    setState(() {
      _invoice = invoice;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final invoice = _invoice!;
    final confirmed = await showDestructiveConfirmDialog(
      context,
      title: 'Eliminar factura',
      message:
          '¿Eliminar la factura de "${invoice.supplierName}"'
          '${invoice.number.isEmpty ? '' : ' N.º ${invoice.number}'}? '
          'Esta acción no se puede deshacer.',
    );
    if (!confirmed || !mounted) return;
    await context.read<InvoicesViewModel>().deleteInvoice(invoice.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _save(Invoice updated) async {
    setState(() => _saving = true);
    try {
      await context.read<InvoicesViewModel>().saveInvoice(updated);
      if (!mounted) return;
      final refreshed = await context.read<InvoicesViewModel>().invoiceById(
        widget.invoiceId,
      );
      if (!mounted) return;
      setState(() {
        _invoice = refreshed;
        _editing = false;
        _changed = true;
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markVerified() async {
    final invoice = _invoice!;
    await _save(invoice.copyWith(status: InvoiceStatus.verified));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Editar factura' : 'Detalle de factura'),
          actions: [
            if (!_loading && _invoice != null && !_editing) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() => _editing = true),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final invoice = _invoice;
    if (invoice == null) {
      return const Center(child: Text('No se encontró la factura.'));
    }
    final imagePaths = invoice.images
        .map((image) => image.path)
        .toList(growable: false);

    if (_editing) {
      final model = context.watch<InvoicesViewModel>();
      return LayoutBuilder(
        builder: (context, constraints) {
          final form = InvoiceForm(
            invoice: invoice,
            categories: model.categories,
            suppliers: model.suppliers,
            busy: _saving,
            saveLabel: 'Guardar cambios',
            onSave: _save,
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
              SizedBox(height: 240, child: ImageCarousel(paths: imagePaths)),
              Expanded(child: form),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = _InvoiceSummary(
          invoice: invoice,
          onMarkVerified: invoice.status == InvoiceStatus.draft
              ? _markVerified
              : null,
        );
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.42,
                child: ImageCarousel(paths: imagePaths),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: summary,
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 240, child: ImageCarousel(paths: imagePaths)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: summary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({required this.invoice, this.onMarkVerified});

  final Invoice invoice;
  final VoidCallback? onMarkVerified;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'invoice-avatar-${invoice.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    invoice.supplierName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
            StatusChip(status: invoice.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          invoice.number.isEmpty ? 'Sin número' : 'N.º ${invoice.number}',
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        if (onMarkVerified != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onMarkVerified,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Marcar como verificada'),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('NIT', invoice.supplierTaxId),
                _Row('Categoría', invoice.categoryName),
                _Row('Fecha', AppFormatters.date(invoice.issueDate)),
                _Row('Código de autorización', invoice.authorizationCode),
                _Row('Código fiscal (CUF)', invoice.fiscalCode),
                _Row('Método de pago', invoice.paymentMethod),
                if (invoice.qrContent.isNotEmpty)
                  const _Row('QR', 'Contenido capturado'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('Subtotal', AppFormatters.money(invoice.subtotal)),
                _Row('Descuento', AppFormatters.money(invoice.discount)),
                _Row('Impuesto', AppFormatters.money(invoice.tax)),
                const Divider(height: 24),
                _Row(
                  'Total',
                  AppFormatters.money(invoice.total),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (invoice.items.isEmpty)
                  const Text(
                    'Sin productos registrados.',
                    style: TextStyle(color: AppColors.inkMuted),
                  )
                else
                  for (final item in invoice.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(AppFormatters.money(item.lineTotal)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasize ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
