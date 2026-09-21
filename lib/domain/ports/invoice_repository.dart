import '../entities/dashboard_stats.dart';
import '../entities/invoice.dart';

abstract interface class InvoiceRepository {
  Future<List<Invoice>> findAll({
    String query = '',
    InvoiceStatus? status,
    int? categoryId,
  });

  Future<Invoice?> findById(int id);

  /// Returns an already-stored invoice that looks like the same document:
  /// same invoice number, same supplier name and same issue day.
  ///
  /// This has to hit the database rather than scan a loaded list, because the
  /// list the UI holds is filtered by the active search/status/category and
  /// would hide the very duplicate we are looking for.
  ///
  /// [excludingId] skips the invoice being edited so it never matches itself.
  Future<Invoice?> findDuplicate({
    required String number,
    required String supplierName,
    required DateTime issueDate,
    int? excludingId,
  });

  Future<int> save(Invoice invoice);

  Future<void> delete(int id);

  Future<DashboardStats> dashboardStats(DateTime now);
}
