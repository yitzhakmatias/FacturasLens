import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/invoice.dart';
import '../core/app_theme.dart';
import '../core/app_routes.dart';
import '../widgets/empty_state.dart';
import '../widgets/invoice_tile.dart';
import '../widgets/page_header.dart';

enum _SortMode { date, total }

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchController = TextEditingController();
  _SortMode _sortMode = _SortMode.date;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.invoiceDetail,
      arguments: InvoiceDetailArguments(id),
    );
    if (changed == true && mounted) {
      await context.read<InvoicesViewModel>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<InvoicesViewModel>();
    final invoices = [...model.invoices];
    if (_sortMode == _SortMode.total) {
      invoices.sort((a, b) => b.total.compareTo(a.total));
    }

    return RefreshIndicator(
      onRefresh: model.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    eyebrow: 'Historial',
                    title: 'Todas tus facturas',
                    subtitle: 'Busca, filtra y ordena tu archivo local.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por comercio, NIT o número',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) =>
                        model.applyFilters(searchQuery: value),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: model.statusFilter == null,
                        onSelected: (_) =>
                            model.applyFilters(clearStatus: true),
                      ),
                      ChoiceChip(
                        label: const Text('Por revisar'),
                        selected: model.statusFilter == InvoiceStatus.draft,
                        onSelected: (_) =>
                            model.applyFilters(status: InvoiceStatus.draft),
                      ),
                      ChoiceChip(
                        label: const Text('Verificadas'),
                        selected: model.statusFilter == InvoiceStatus.verified,
                        onSelected: (_) =>
                            model.applyFilters(status: InvoiceStatus.verified),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: model.categoryFilter,
                        hint: const Text('Categoría'),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas las categorías'),
                          ),
                          for (final category in model.categories)
                            DropdownMenuItem<int?>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: (value) => value == null
                            ? model.applyFilters(clearCategory: true)
                            : model.applyFilters(categoryId: value),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _sortMode == _SortMode.date
                            ? 'Ordenar por monto'
                            : 'Ordenar por fecha',
                        icon: Icon(
                          _sortMode == _SortMode.date
                              ? Icons.sort_by_alpha_outlined
                              : Icons.calendar_month_outlined,
                        ),
                        onPressed: () => setState(() {
                          _sortMode = _sortMode == _SortMode.date
                              ? _SortMode.total
                              : _SortMode.date;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: model.isLoading && invoices.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : invoices.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off_outlined,
                              title: 'Sin resultados',
                              message:
                                  'Ajusta la búsqueda o los filtros para encontrar facturas.',
                            )
                          : Column(
                              children: [
                                const SizedBox(height: 6),
                                for (
                                  var index = 0;
                                  index < invoices.length;
                                  index++
                                ) ...[
                                  InvoiceTile(
                                    invoice: invoices[index],
                                    onTap: () =>
                                        _openDetail(invoices[index].id!),
                                  ),
                                  if (index < invoices.length - 1)
                                    const Divider(),
                                ],
                                const SizedBox(height: 6),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${invoices.length} factura(s)',
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
