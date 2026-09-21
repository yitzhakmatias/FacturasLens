import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/view_models/invoices_view_model.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';
import 'pages/analytics_page.dart';
import 'pages/catalogs_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/invoices_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _destinations =
      <({IconData icon, IconData active, String label})>[
        (
          icon: Icons.grid_view_rounded,
          active: Icons.dashboard_rounded,
          label: 'Inicio',
        ),
        (
          icon: Icons.receipt_long_outlined,
          active: Icons.receipt_long_rounded,
          label: 'Facturas',
        ),
        (
          icon: Icons.bar_chart_rounded,
          active: Icons.analytics_rounded,
          label: 'Estadísticas',
        ),
        (
          icon: Icons.tune_rounded,
          active: Icons.tune_rounded,
          label: 'Catálogos',
        ),
      ];

  static const _pages = <Widget>[
    DashboardPage(),
    InvoicesPage(),
    AnalyticsPage(),
    CatalogsPage(),
  ];

  Future<void> _openCapture() async {
    final saved = await Navigator.of(
      context,
    ).pushNamed<bool>(AppRoutes.capture);
    if (saved == true && mounted) {
      await context.read<InvoicesViewModel>().load();
      setState(() => _selectedIndex = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 860;
        final content = IndexedStack(index: _selectedIndex, children: _pages);
        if (!expanded) {
          return Scaffold(
            body: content,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _openCapture,
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Escanear'),
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (value) =>
                    setState(() => _selectedIndex = value),
                destinations: _destinations
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.active),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              Container(
                width: 250,
                margin: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 22, 20, 28),
                        child: _Brand(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: FilledButton.icon(
                          onPressed: _openCapture,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nueva factura'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: NavigationRail(
                          extended: true,
                          minExtendedWidth: 220,
                          groupAlignment: -1,
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (value) =>
                              setState(() => _selectedIndex = value),
                          destinations: _destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.active),
                                  label: Text(item.label),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: _PrivacyNote(),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.document_scanner_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FacturaLens',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Control de gastos',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Tus datos permanecen en este dispositivo.',
              style: TextStyle(
                color: AppColors.inkMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
