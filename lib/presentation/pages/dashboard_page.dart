import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../core/app_theme.dart';
import '../core/app_routes.dart';
import '../core/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/curved_dashboard_header.dart';
import '../widgets/invoice_tile.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _openDetail(BuildContext context, int id) async {
    final changed = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.invoiceDetail,
      arguments: InvoiceDetailArguments(id),
    );
    if (changed == true && context.mounted) {
      await context.read<InvoicesViewModel>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoicesViewModel>(
      builder: (context, model, _) {
        return RefreshIndicator(
          onRefresh: model.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: const CurvedDashboardHeader(),
                      ),
                    ),
                  ),
                ),
              ),
              if (model.isLoading && model.invoices.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (model.error != null && model.invoices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No pudimos abrir el archivo local',
                    message: model.error!,
                    action: FilledButton(
                      onPressed: model.load,
                      child: const Text('Reintentar'),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 840 ? 4 : 2;
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: columns,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              // A fixed vertical extent prevents the metric
                              // content from being compressed on narrow phones.
                              mainAxisExtent: columns == 4 ? 146 : 148,
                              children: [
                                _MetricBlock(
                                  label: 'Gasto del mes',
                                  value: AppFormatters.money(
                                    model.stats.monthTotal,
                                  ),
                                  icon: Icons.account_balance_wallet_outlined,
                                  strong: true,
                                ),
                                _MetricBlock(
                                  label: 'Facturas verificadas',
                                  value: '${model.stats.invoiceCount}',
                                  icon: Icons.verified_outlined,
                                ),
                                _MetricBlock(
                                  label: 'Ticket promedio',
                                  value: AppFormatters.money(
                                    model.stats.averageTicket,
                                  ),
                                  icon: Icons.calculate_outlined,
                                ),
                                _MetricBlock(
                                  label: 'Pendientes',
                                  value: '${model.stats.pendingCount}',
                                  icon: Icons.pending_actions_outlined,
                                  review: model.stats.pendingCount > 0,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Facturas recientes',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    Text(
                                      '${model.invoices.length} guardadas',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.inkMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (model.recentInvoices.isEmpty)
                                  const EmptyState(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Tu archivo está vacío',
                                    message:
                                        'Escanea una factura o registra una manualmente para comenzar.',
                                  )
                                else
                                  for (
                                    var index = 0;
                                    index < model.recentInvoices.length;
                                    index++
                                  ) ...[
                                    InvoiceTile(
                                      invoice: model.recentInvoices[index],
                                      onTap: () => _openDetail(
                                        context,
                                        model.recentInvoices[index].id!,
                                      ),
                                    ),
                                    if (index < model.recentInvoices.length - 1)
                                      const Divider(),
                                  ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.icon,
    this.strong = false,
    this.review = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool strong;
  final bool review;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong
            ? AppColors.primary
            : review
            ? AppColors.reviewSurface
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: strong ? AppColors.primary : AppColors.border,
        ),
        boxShadow: strong
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: strong
                  ? Colors.white70
                  : review
                  ? AppColors.review
                  : AppColors.primary,
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  height: 1.05,
                  color: strong ? Colors.white : AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                height: 1.2,
                color: strong ? Colors.white70 : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
