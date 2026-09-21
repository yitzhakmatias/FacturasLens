import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';

class ReviewInvoicePage extends StatefulWidget {
  const ReviewInvoicePage({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<ReviewInvoicePage> createState() => _ReviewInvoicePageState();
}

class _ReviewInvoicePageState extends State<ReviewInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _supplier;
  late final TextEditingController _taxId;
  late final TextEditingController _number;
  late final TextEditingController _authorization;
  late final TextEditingController _fiscalCode;
  late final TextEditingController _subtotal;
  late final TextEditingController _discount;
  late final TextEditingController _tax;
  late final TextEditingController _total;
  late final TextEditingController _paymentMethod;
  late final TextEditingController _qrContent;
  late DateTime _issueDate;
  late List<InvoiceItem> _items;
  int? _categoryId;
  bool _verified = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _supplier = TextEditingController(text: invoice.supplierName);
    _taxId = TextEditingController(text: invoice.supplierTaxId);
    _number = TextEditingController(text: invoice.number);
    _authorization = TextEditingController(text: invoice.authorizationCode);
    _fiscalCode = TextEditingController(text: invoice.fiscalCode);
    _subtotal = TextEditingController(text: _numberText(invoice.subtotal));
    _discount = TextEditingController(text: _numberText(invoice.discount));
    _tax = TextEditingController(text: _numberText(invoice.tax));
    _total = TextEditingController(text: _numberText(invoice.total));
    _paymentMethod = TextEditingController(text: invoice.paymentMethod);
    _qrContent = TextEditingController(text: invoice.qrContent);
    _issueDate = invoice.issueDate;
    _categoryId = invoice.categoryId;
    _verified = invoice.status == InvoiceStatus.verified;
    _items = [...invoice.items];
  }

  String _numberText(double value) => value.toStringAsFixed(2);

  @override
  void dispose() {
    for (final controller in [
      _supplier,
      _taxId,
      _number,
      _authorization,
      _fiscalCode,
      _subtotal,
      _discount,
      _tax,
      _total,
      _paymentMethod,
      _qrContent,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _parseNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) setState(() => _issueDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final model = context.read<InvoicesViewModel>();
    final categoryName =
        model.categories
            .where((category) => category.id == _categoryId)
            .map((category) => category.name)
            .firstOrNull ??
        'Sin categoría';
    final updated = widget.invoice.copyWith(
      categoryId: _categoryId,
      categoryName: categoryName,
      supplierName: _supplier.text.trim(),
      supplierTaxId: _taxId.text.trim(),
      number: _number.text.trim(),
      authorizationCode: _authorization.text.trim(),
      fiscalCode: _fiscalCode.text.trim(),
      issueDate: _issueDate,
      subtotal: _parseNumber(_subtotal),
      discount: _parseNumber(_discount),
      tax: _parseNumber(_tax),
      total: _parseNumber(_total),
      paymentMethod: _paymentMethod.text.trim(),
      qrContent: _qrContent.text.trim(),
      status: _verified ? InvoiceStatus.verified : InvoiceStatus.draft,
      items: _items,
    );
    try {
      await model.saveInvoice(updated);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $exception')));
    }
  }

  Future<void> _editItem({int? index}) async {
    final current = index == null ? null : _items[index];
    final description = TextEditingController(text: current?.description ?? '');
    final quantity = TextEditingController(
      text: current == null ? '1.00' : _numberText(current.quantity),
    );
    final unitPrice = TextEditingController(
      text: current == null ? '0.00' : _numberText(current.unitPrice),
    );
    final discount = TextEditingController(
      text: current == null ? '0.00' : _numberText(current.discount),
    );
    final lineTotal = TextEditingController(
      text: current == null ? '0.00' : _numberText(current.lineTotal),
    );
    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? 'Agregar producto' : 'Editar producto'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: quantity,
                        label: 'Cantidad',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoneyField(
                        controller: unitPrice,
                        label: 'Precio unitario',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: discount,
                        label: 'Descuento',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoneyField(
                        controller: lineTotal,
                        label: 'Subtotal línea',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsedQuantity =
                  double.tryParse(quantity.text.replaceAll(',', '.')) ?? 1;
              final parsedUnit =
                  double.tryParse(unitPrice.text.replaceAll(',', '.')) ?? 0;
              final parsedDiscount =
                  double.tryParse(discount.text.replaceAll(',', '.')) ?? 0;
              final parsedTotal =
                  double.tryParse(lineTotal.text.replaceAll(',', '.')) ??
                  (parsedQuantity * parsedUnit) - parsedDiscount;
              if (description.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                InvoiceItem(
                  id: current?.id,
                  invoiceId: current?.invoiceId,
                  description: description.text.trim(),
                  quantity: parsedQuantity,
                  unitPrice: parsedUnit,
                  discount: parsedDiscount,
                  lineTotal: parsedTotal,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    lineTotal.dispose();
    if (result == null) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
      final itemsTotal = _items.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );
      _subtotal.text = _numberText(itemsTotal);
      _total.text = _numberText(itemsTotal - _parseNumber(_discount));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.invoice.id == null ? 'Revisar extracción' : 'Editar factura',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split =
                constraints.maxWidth >= 900 && widget.invoice.images.isNotEmpty;
            if (split) {
              return Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.42,
                    child: _ImagePreview(invoice: widget.invoice),
                  ),
                  const VerticalDivider(),
                  Expanded(child: _buildForm()),
                ],
              );
            }
            return _buildForm(showImages: true);
          },
        ),
      ),
    );
  }

  Widget _buildForm({bool showImages = false}) {
    final model = context.watch<InvoicesViewModel>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showImages && widget.invoice.images.isNotEmpty) ...[
                  SizedBox(
                    height: 260,
                    child: _ImagePreview(invoice: widget.invoice),
                  ),
                  const SizedBox(height: 24),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _verified
                        ? AppColors.successSurface
                        : AppColors.reviewSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _verified,
                    onChanged: (value) => setState(() => _verified = value),
                    title: Text(
                      _verified
                          ? 'Factura verificada'
                          : 'Pendiente de revisión',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Confirma solamente después de revisar comercio, número, fecha y total.',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Encabezado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(
                    labelText: 'Comercio o proveedor',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre del proveedor.'
                      : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taxId,
                        decoration: const InputDecoration(
                          labelText: 'NIT proveedor',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _number,
                        decoration: const InputDecoration(
                          labelText: 'N.º factura',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Requerido.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de emisión',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(AppFormatters.date(_issueDate)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  items: model.categories
                      .map(
                        (category) => DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _authorization,
                        decoration: const InputDecoration(
                          labelText: 'Código autorización',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _fiscalCode,
                        decoration: const InputDecoration(
                          labelText: 'Código fiscal / CUF',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Productos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _editItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: _items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(26),
                          child: Center(
                            child: Text(
                              'El OCR no identificó líneas. Puedes agregarlas manualmente.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < _items.length;
                              index++
                            ) ...[
                              ListTile(
                                onTap: () => _editItem(index: index),
                                title: Text(_items[index].description),
                                subtitle: Text(
                                  '${_items[index].quantity} × ${AppFormatters.money(_items[index].unitPrice)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppFormatters.money(
                                        _items[index].lineTotal,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar línea',
                                      onPressed: () {
                                        setState(() => _items.removeAt(index));
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                              ),
                              if (index < _items.length - 1) const Divider(),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 28),
                Text('Totales', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: _subtotal,
                        label: 'Subtotal',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MoneyField(
                        controller: _discount,
                        label: 'Descuento',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(controller: _tax, label: 'Impuesto'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MoneyField(
                        controller: _total,
                        label: 'Total',
                        requiredPositive: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _qrContent,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Contenido QR',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
                if (widget.invoice.rawOcrText.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Texto OCR original'),
                      subtitle: const Text('Conservado para trazabilidad'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          child: SelectableText(widget.invoice.rawOcrText),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _verified
                          ? 'Guardar como verificada'
                          : 'Guardar borrador',
                    ),
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

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        itemCount: invoice.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: kIsWeb
                  ? const ColoredBox(
                      color: AppColors.surfaceMuted,
                      child: Icon(Icons.receipt_long),
                    )
                  : Image.file(
                      File(invoice.images[index].path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    this.requiredPositive = false,
  });

  final TextEditingController controller;
  final String label;
  final bool requiredPositive;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, prefixText: 'Bs  '),
      validator: requiredPositive
          ? (value) {
              final number = double.tryParse(
                (value ?? '').replaceAll(',', '.'),
              );
              return number == null || number <= 0
                  ? 'Debe ser mayor a 0.'
                  : null;
            }
          : null,
    );
  }
}
