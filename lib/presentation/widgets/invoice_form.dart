import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_category.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/supplier.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import 'review_field.dart';

/// Shared editable invoice form used both for reviewing a freshly scanned
/// draft and for editing an already-saved invoice. The caller owns
/// persistence: [onSave] receives the invoice built from the current form
/// state and the requested [InvoiceStatus].
class InvoiceForm extends StatefulWidget {
  const InvoiceForm({
    super.key,
    required this.invoice,
    required this.categories,
    required this.suppliers,
    required this.onSave,
    this.busy = false,
    this.saveLabel = 'Confirmar y guardar',
    this.allowDraftSave = true,
  });

  final Invoice invoice;
  final List<InvoiceCategory> categories;
  final List<Supplier> suppliers;
  final Future<void> Function(Invoice invoice) onSave;
  final bool busy;
  final String saveLabel;
  final bool allowDraftSave;

  @override
  State<InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm> {
  late final TextEditingController _supplierName;
  late final TextEditingController _supplierTaxId;
  late final TextEditingController _number;
  late final TextEditingController _authorizationCode;
  late final TextEditingController _fiscalCode;
  late final TextEditingController _subtotal;
  late final TextEditingController _discount;
  late final TextEditingController _tax;
  late final TextEditingController _total;
  late final TextEditingController _paymentMethod;
  late final TextEditingController _currency;
  late final TextEditingController _issueDateText;
  late DateTime _issueDate;
  int? _categoryId;
  late List<InvoiceItem> _items;
  final FocusNode _supplierFocus = FocusNode();

  /// Catalog supplier picked from the autocomplete, if any. Picking one
  /// attaches the invoice to that supplier instead of creating a twin.
  Supplier? _pickedSupplier;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _supplierName = TextEditingController(text: invoice.supplierName);
    _supplierTaxId = TextEditingController(text: invoice.supplierTaxId);
    _number = TextEditingController(text: invoice.number);
    _authorizationCode = TextEditingController(text: invoice.authorizationCode);
    _fiscalCode = TextEditingController(text: invoice.fiscalCode);
    _subtotal = TextEditingController(text: _moneyText(invoice.subtotal));
    _discount = TextEditingController(text: _moneyText(invoice.discount));
    _tax = TextEditingController(text: _moneyText(invoice.tax));
    _total = TextEditingController(text: _moneyText(invoice.total));
    _paymentMethod = TextEditingController(text: invoice.paymentMethod);
    _currency = TextEditingController(text: invoice.currency);
    _issueDate = invoice.issueDate;
    _issueDateText = TextEditingController(text: _dateText(_issueDate));
    _categoryId = invoice.categoryId;
    _items = [...invoice.items];
    for (final controller in [_supplierName, _number, _subtotal, _total]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    // Typing over a picked supplier's name means it is no longer that one.
    final picked = _pickedSupplier;
    if (picked != null && _supplierName.text.trim() != picked.name) {
      _pickedSupplier = null;
    }
    setState(() {});
  }

  void _pickSupplier(Supplier supplier) {
    _pickedSupplier = supplier;
    if (supplier.taxId.isNotEmpty) _supplierTaxId.text = supplier.taxId;
    setState(() {});
  }

  Iterable<Supplier> _supplierOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.length < 2) return const [];
    return widget.suppliers
        .where(
          (supplier) =>
              supplier.name.toLowerCase().contains(query) ||
              (supplier.taxId.isNotEmpty && supplier.taxId.contains(query)),
        )
        .take(6);
  }

  @override
  void dispose() {
    for (final controller in [_supplierName, _number, _subtotal, _total]) {
      controller.removeListener(_refresh);
    }
    _supplierFocus.dispose();
    _supplierName.dispose();
    _supplierTaxId.dispose();
    _number.dispose();
    _authorizationCode.dispose();
    _fiscalCode.dispose();
    _subtotal.dispose();
    _discount.dispose();
    _tax.dispose();
    _total.dispose();
    _paymentMethod.dispose();
    _currency.dispose();
    _issueDateText.dispose();
    super.dispose();
  }

  String _dateText(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

  String _moneyText(double value) => value == 0 ? '' : value.toStringAsFixed(2);

  double _parseMoney(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

  Invoice _buildInvoice(InvoiceStatus status) {
    return widget.invoice.copyWith(
      supplierId: _pickedSupplier?.id,
      supplierName: _supplierName.text.trim().isEmpty
          ? 'Proveedor por revisar'
          : _supplierName.text.trim(),
      supplierTaxId: _supplierTaxId.text.trim(),
      categoryId: _categoryId,
      categoryName: _categoryId == null
          ? 'Sin categoría'
          : widget.categories
                .firstWhere(
                  (category) => category.id == _categoryId,
                  orElse: () => const InvoiceCategory(
                    name: 'Sin categoría',
                    colorValue: 0,
                  ),
                )
                .name,
      number: _number.text.trim(),
      authorizationCode: _authorizationCode.text.trim(),
      fiscalCode: _fiscalCode.text.trim(),
      issueDate: _issueDate,
      subtotal: _parseMoney(_subtotal.text),
      discount: _parseMoney(_discount.text),
      tax: _parseMoney(_tax.text),
      total: _parseMoney(_total.text),
      currency: _currency.text.trim().isEmpty ? 'BOB' : _currency.text.trim(),
      paymentMethod: _paymentMethod.text.trim(),
      status: status,
      items: _items,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _issueDate = picked;
        _issueDateText.text = _dateText(picked);
      });
    }
  }

  Future<void> _editItem({InvoiceItem? existing, int? index}) async {
    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (_) => _ItemEditorDialog(item: existing),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  void _removeItem(int index) {
    final removed = _items[index];
    setState(() => _items.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Producto eliminado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => setState(() => _items.insert(index, removed)),
        ),
      ),
    );
  }

  void _save(InvoiceStatus status) {
    if (widget.busy) return;
    if (status == InvoiceStatus.verified) {
      if (_supplierName.text.trim().isEmpty) {
        _showError('El proveedor es obligatorio para confirmar.');
        return;
      }
      if (_parseMoney(_total.text) <= 0) {
        _showError('El total debe ser mayor a 0 para confirmar.');
        return;
      }
    }
    widget.onSave(_buildInvoice(status));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _totalsConsistent {
    if (_items.isEmpty) return true;
    final itemsTotal = _items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    return (itemsTotal - _parseMoney(_subtotal.text)).abs() < 0.05;
  }

  @override
  Widget build(BuildContext context) {
    final supplierSuspect =
        _supplierName.text.trim().isEmpty ||
        _supplierName.text.trim() == 'Proveedor por revisar';
    final numberSuspect = _number.text.trim().isEmpty;
    final totalSuspect = _parseMoney(_total.text) <= 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        _SectionCard(
          title: 'Proveedor',
          children: [
            RawAutocomplete<Supplier>(
              textEditingController: _supplierName,
              focusNode: _supplierFocus,
              optionsBuilder: _supplierOptions,
              displayStringForOption: (supplier) => supplier.name,
              onSelected: _pickSupplier,
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  ReviewField(
                    controller: controller,
                    focusNode: focusNode,
                    label: 'Nombre o razón social',
                    suspect: supplierSuspect,
                  ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                      maxWidth: 420,
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final supplier in options)
                          ListTile(
                            dense: true,
                            title: Text(supplier.name),
                            subtitle: supplier.taxId.isEmpty
                                ? null
                                : Text('NIT ${supplier.taxId}'),
                            onTap: () => onSelected(supplier),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ReviewField(
              controller: _supplierTaxId,
              label: 'NIT',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Datos fiscales',
          children: [
            ReviewField(
              controller: _number,
              label: 'N.º de factura',
              suspect: numberSuspect,
            ),
            const SizedBox(height: 14),
            ReviewField(
              controller: _authorizationCode,
              label: 'Código de autorización',
            ),
            const SizedBox(height: 14),
            ReviewField(controller: _fiscalCode, label: 'Código fiscal (CUF)'),
            const SizedBox(height: 14),
            ReviewField(
              controller: _issueDateText,
              label: 'Fecha de emisión',
              readOnly: true,
              onTap: _pickDate,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            if (widget.invoice.qrContent.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_2,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Código QR capturado',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Montos',
          children: [
            Row(
              children: [
                Expanded(
                  child: ReviewField(
                    controller: _subtotal,
                    label: 'Subtotal',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReviewField(
                    controller: _discount,
                    label: 'Descuento',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ReviewField(
                    controller: _tax,
                    label: 'Impuesto',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReviewField(
                    controller: _total,
                    label: 'Total',
                    suspect: totalSuspect,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ReviewField(controller: _currency, label: 'Moneda'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ReviewField(
                    controller: _paymentMethod,
                    label: 'Método de pago',
                  ),
                ),
              ],
            ),
            if (!_totalsConsistent) ...[
              const SizedBox(height: 14),
              const _Banner(
                text:
                    'La suma de los productos no coincide con el subtotal. '
                    'Revisa el detalle antes de confirmar.',
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Productos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _editItem(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No se detectaron productos. Puedes agregarlos manualmente.',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  )
                else
                  for (var i = 0; i < _items.length; i++)
                    _ItemRow(
                      item: _items[i],
                      onTap: () => _editItem(existing: _items[i], index: i),
                      onDelete: () => _removeItem(i),
                    ),
              ],
            ),
          ),
        ),
        if (widget.invoice.rawOcrText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: const Text('Texto reconocido (OCR)'),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                SelectableText(
                  widget.invoice.rawOcrText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (widget.allowDraftSave) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () => _save(InvoiceStatus.draft),
                  child: const Text('Guardar borrador'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: widget.busy
                    ? null
                    : () => _save(InvoiceStatus.verified),
                child: widget.busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.reviewSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.review,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.review, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final InvoiceItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description.isEmpty
                        ? 'Sin descripción'
                        : item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${item.quantity} × ${AppFormatters.money(item.unitPrice)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            Text(
              AppFormatters.money(item.lineTotal),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.inkMuted,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({this.item});

  final InvoiceItem? item;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  late final _description = TextEditingController(
    text: widget.item?.description ?? '',
  );
  late final _quantity = TextEditingController(
    text: (widget.item?.quantity ?? 1).toString(),
  );
  late final _unitPrice = TextEditingController(
    text: (widget.item?.unitPrice ?? 0).toString(),
  );
  late final _discount = TextEditingController(
    text: (widget.item?.discount ?? 0).toString(),
  );
  late final _lineTotal = TextEditingController(
    text: (widget.item?.lineTotal ?? 0).toString(),
  );

  double _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  void _recalculate() {
    final total =
        _parse(_quantity.text) * _parse(_unitPrice.text) -
        _parse(_discount.text);
    setState(() => _lineTotal.text = total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discount.dispose();
    _lineTotal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Agregar producto' : 'Editar producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Descuento'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lineTotal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Total línea',
                      suffixIcon: IconButton(
                        tooltip: 'Calcular',
                        icon: const Icon(Icons.calculate_outlined),
                        onPressed: _recalculate,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_description.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              InvoiceItem(
                id: widget.item?.id,
                invoiceId: widget.item?.invoiceId,
                description: _description.text.trim(),
                quantity: _parse(_quantity.text),
                unitPrice: _parse(_unitPrice.text),
                discount: _parse(_discount.text),
                lineTotal: _parse(_lineTotal.text),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
