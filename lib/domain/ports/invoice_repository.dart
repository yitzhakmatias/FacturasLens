import '../entities/dashboard_stats.dart';
import '../entities/invoice.dart';

abstract interface class InvoiceRepository {
  Future<List<Invoice>> findAll({
    String query = '',
    InvoiceStatus? status,
    int? categoryId,
  });

  Future<Invoice?> findById(int id);

  Future<int> save(Invoice invoice);

  Future<void> delete(int id);

  Future<DashboardStats> dashboardStats(DateTime now);
}
