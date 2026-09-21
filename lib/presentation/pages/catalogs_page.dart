import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice_category.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/ports/catalog_repository.dart';
import '../core/app_theme.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';

const _categoryPalette = <int>[
  0xFF2F766D,
  0xFF3B6EA8,
  0xFF7B5EA7,
  0xFFB04A5A,
  0xFFB47824,
  0xFF6A7180,
  0xFF126E62,
  0xFFC87916,
];

class CatalogsPage extends StatelessWidget {
  const CatalogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      eyebrow: 'Catálogos',
                      title: 'Proveedores y categorías',
                      subtitle:
                          'Mantén ordenado tu archivo local de comercios y clasificaciones de gasto.',
                    ),
                    const SizedBox(height: 20),
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Proveedores'),
                        Tab(text: 'Categorías'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_SuppliersTab(), _CategoriesTab()]),
          ),
        ],
      ),
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  Future<void> _openForm(BuildContext context, {Supplier? existing}) async {
    final result = await showDialog<Supplier>(
      context: context,
      builder: (_) => _SupplierFormDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<InvoicesViewModel>().saveSupplier(result);
    } on DuplicateTaxIdException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ya existe otro proveedor con el NIT ${error.taxId}.'),
        ),
      );
    } catch (exception) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el proveedor: $exception')),
      );
    }
  }

  Future<void> _delete(BuildContext context, Supplier supplier) async {
    final confirmed = await showDestructiveConfirmDialog(
      context,
      title: 'Eliminar proveedor',
      message: '¿Eliminar a "${supplier.name}" de tus proveedores?',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<InvoicesViewModel>().deleteSupplier(supplier.id!);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exception is SupplierInUseException
                  ? 'No se puede eliminar un proveedor con facturas.'
                  : 'No se pudo eliminar el proveedor.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<InvoicesViewModel>();
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: model.suppliers.isEmpty
                ? const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Aún no registras proveedores',
                    message:
                        'Se crean automáticamente al guardar una factura, o agrégalos manualmente.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
                    itemCount: model.suppliers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final supplier = model.suppliers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceMuted,
                          foregroundColor: AppColors.ink,
                          child: Text(
                            supplier.name.isEmpty
                                ? '?'
                                : supplier.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(supplier.name),
                        subtitle: Text(
                          [
                            if (supplier.taxId.isNotEmpty)
                              'NIT ${supplier.taxId}',
                            if (supplier.phone.isNotEmpty) supplier.phone,
                          ].join('  ·  '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _openForm(context, existing: supplier),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(context, supplier),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Proveedor'),
          ),
        ),
      ],
    );
  }
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({this.existing});

  final Supplier? existing;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _taxId = TextEditingController(text: widget.existing?.taxId ?? '');
  late final _address = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nuevo proveedor' : 'Editar proveedor',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre o razón social',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxId,
              decoration: const InputDecoration(labelText: 'NIT'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Dirección'),
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
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              Supplier(
                id: widget.existing?.id,
                name: _name.text.trim(),
                taxId: _taxId.text.trim(),
                address: _address.text.trim(),
                phone: _phone.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  Future<void> _openForm(
    BuildContext context, {
    InvoiceCategory? existing,
  }) async {
    final result = await showDialog<InvoiceCategory>(
      context: context,
      builder: (_) => _CategoryFormDialog(existing: existing),
    );
    if (result != null && context.mounted) {
      await context.read<InvoicesViewModel>().saveCategory(result);
    }
  }

  Future<void> _delete(BuildContext context, InvoiceCategory category) async {
    final confirmed = await showDestructiveConfirmDialog(
      context,
      title: 'Eliminar categoría',
      message:
          '¿Eliminar "${category.name}"? Las facturas asociadas quedarán sin categoría.',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<InvoicesViewModel>().deleteCategory(category.id!);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<InvoicesViewModel>();
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: model.categories.isEmpty
                ? const EmptyState(
                    icon: Icons.tune_outlined,
                    title: 'Sin categorías',
                    message: 'Crea categorías para clasificar tus facturas.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
                    itemCount: model.categories.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final category = model.categories[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Color(category.colorValue),
                        ),
                        title: Text(category.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _openForm(context, existing: category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(context, category),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Categoría'),
          ),
        ),
      ],
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.existing});

  final InvoiceCategory? existing;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late int _color = widget.existing?.colorValue ?? _categoryPalette.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nueva categoría' : 'Editar categoría',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in _categoryPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = value),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: _color == value
                            ? Border.all(color: AppColors.ink, width: 2)
                            : null,
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
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              InvoiceCategory(
                id: widget.existing?.id,
                name: _name.text.trim(),
                colorValue: _color,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
