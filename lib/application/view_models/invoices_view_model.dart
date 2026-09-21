import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_category.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/ports/catalog_repository.dart';
import '../../domain/ports/invoice_repository.dart';

class InvoicesViewModel extends ChangeNotifier {
  InvoicesViewModel(this._invoiceRepository, this._catalogRepository);

  final InvoiceRepository _invoiceRepository;
  final CatalogRepository _catalogRepository;

  List<Invoice> invoices = const [];
  List<InvoiceCategory> categories = const [];
  List<Supplier> suppliers = const [];
  DashboardStats stats = const DashboardStats();
  bool isLoading = false;
  String? error;
  String query = '';
  InvoiceStatus? statusFilter;
  int? categoryFilter;

  List<Invoice> get recentInvoices => invoices.take(5).toList(growable: false);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      // A record `.wait` keeps the four queries parallel while staying
      // statically typed — the old `Future.wait([...])` plus `results[0] as
      // List<Invoice>` compiled happily even if the order drifted.
      final (invoiceList, categoryList, supplierList, dashboard) =
          await (
            _invoiceRepository.findAll(
              query: query,
              status: statusFilter,
              categoryId: categoryFilter,
            ),
            _catalogRepository.findCategories(),
            _catalogRepository.findSuppliers(),
            _invoiceRepository.dashboardStats(DateTime.now()),
          ).wait;

      invoices = invoiceList;
      categories = categoryList;
      suppliers = supplierList;
      stats = dashboard;
    } catch (exception) {
      // Includes ParallelWaitError, whose toString lists the failed futures.
      error = 'No se pudieron cargar los datos: $exception';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({
    String? searchQuery,
    InvoiceStatus? status,
    bool clearStatus = false,
    int? categoryId,
    bool clearCategory = false,
  }) async {
    if (searchQuery != null) query = searchQuery;
    if (clearStatus) {
      statusFilter = null;
    } else if (status != null) {
      statusFilter = status;
    }
    if (clearCategory) {
      categoryFilter = null;
    } else if (categoryId != null) {
      categoryFilter = categoryId;
    }
    await load();
  }

  /// Looks for an already-stored invoice that matches [candidate].
  ///
  /// Goes to the repository rather than scanning [invoices], which only holds
  /// whatever passed the active filters.
  Future<Invoice?> findDuplicate(Invoice candidate) {
    return _invoiceRepository.findDuplicate(
      number: candidate.number,
      supplierName: candidate.supplierName,
      issueDate: candidate.issueDate,
      excludingId: candidate.id,
    );
  }

  Future<int> saveInvoice(Invoice invoice) async {
    final id = await _invoiceRepository.save(invoice);
    await load();
    return id;
  }

  Future<void> deleteInvoice(int id) async {
    await _invoiceRepository.delete(id);
    await load();
  }

  Future<Invoice?> invoiceById(int id) => _invoiceRepository.findById(id);

  Future<void> saveSupplier(Supplier supplier) async {
    await _catalogRepository.saveSupplier(supplier);
    await load();
  }

  Future<void> deleteSupplier(int id) async {
    await _catalogRepository.deleteSupplier(id);
    await load();
  }

  Future<void> saveCategory(InvoiceCategory category) async {
    await _catalogRepository.saveCategory(category);
    await load();
  }

  Future<void> deleteCategory(int id) async {
    await _catalogRepository.deleteCategory(id);
    await load();
  }
}
