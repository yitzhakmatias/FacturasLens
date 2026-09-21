import '../entities/invoice_category.dart';
import '../entities/supplier.dart';

abstract interface class CatalogRepository {
  Future<List<Supplier>> findSuppliers({String query = ''});

  Future<int> saveSupplier(Supplier supplier);

  Future<void> deleteSupplier(int id);

  Future<List<InvoiceCategory>> findCategories();

  Future<int> saveCategory(InvoiceCategory category);

  Future<void> deleteCategory(int id);
}
