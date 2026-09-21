import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/view_models/invoices_view_model.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoicesViewModel>(
      builder: (context, model, _) {
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
                        eyebrow: 'Análisis',
                        title: 'Patrones de gasto',
                        subtitle:
                            'Los cálculos consideran facturas verificadas y permanecen en tu dispositivo.',
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 820;
                          final children = [
                            _SummaryPanel(model: model),
                            _CategoryPieCard(slices: model.stats.byCategory),
                          ];
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: children[0]),
                                const SizedBox(width: 20),
                                Expanded(child: children[1]),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              children[0],
                              const SizedBox(height: 20),
                              children[1],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _BarChartCard(
                        title: 'Proveedores principales',
                        subtitle: 'Histórico verificado',
                        slices: model.stats.bySupplier,
                        color: AppColors.review,
                      ),
                      const SizedBox(height: 20),
                      _BarChartCard(
                        title: 'Tendencia de gasto',
                        subtitle: 'Últimos 6 meses',
                        slices: model.stats.monthlyTrend,
                        color: AppColors.primaryPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.model});

  final InvoicesViewModel model;

  @override
  Widget build(BuildContext context) {
    final change = model.stats.monthChangePercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total del mes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              AppFormatters.money(model.stats.monthTotal),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                change == null
                    ? 'Sin base del mes anterior'
                    : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% frente al mes anterior',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const Divider(height: 36),
            _SummaryLine(
              label: 'Ticket promedio',
              value: AppFormatters.money(model.stats.averageTicket),
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Facturas verificadas',
              value: '${model.stats.invoiceCount}',
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Pendientes de revisión',
              value: '${model.stats.pendingCount}',
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Impuesto del mes',
              value: AppFormatters.money(model.stats.monthTax),
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Factura más alta',
              value: model.stats.highestInvoice == null
                  ? '—'
                  : '${AppFormatters.money(model.stats.highestInvoice!.amount)} '
                        '· ${model.stats.highestInvoice!.label}',
            ),
            const SizedBox(height: 14),
            _SummaryLine(
              label: 'Total histórico',
              value: AppFormatters.money(model.stats.allTimeTotal),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

/// Colores rotados para las porciones del gráfico de pastel, en el mismo
/// espíritu de la paleta de categorías usada en CatalogsPage.
const _piePalette = <Color>[
  AppColors.primary,
  AppColors.review,
  AppColors.primaryPressed,
  Color(0xFF7B5EA7),
  Color(0xFFB04A5A),
  Color(0xFF6A7180),
];

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({required this.slices});

  final List<SpendSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución por categoría',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Mes actual',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 22),
            if (slices.isEmpty || total == 0)
              const EmptyState(
                icon: Icons.pie_chart_outline,
                title: 'Aún no hay datos',
                message: 'Verifica facturas para construir esta estadística.',
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            PieChartSectionData(
                              value: slices[i].amount,
                              color: _piePalette[i % _piePalette.length],
                              radius: 34,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < slices.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == slices.length - 1 ? 0 : 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _piePalette[i % _piePalette.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    slices[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(slices[i].amount / total * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.title,
    required this.subtitle,
    required this.slices,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<SpendSlice> slices;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maximum = slices.fold<double>(
      0,
      (current, slice) => slice.amount > current ? slice.amount : current,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 22),
            if (slices.isEmpty || maximum == 0)
              const EmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'Aún no hay datos',
                message: 'Verifica facturas para construir esta estadística.',
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: maximum * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: maximum / 4,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= slices.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                slices[index].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < slices.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: slices[i].amount,
                              color: color,
                              width: 22,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
