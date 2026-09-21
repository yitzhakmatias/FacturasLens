import '../entities/invoice_category.dart';
import '../entities/supplier.dart';

/// Raised when a supplier cannot be stored because another supplier already
/// uses the same NIT. The tax id is unique by design — it is what lets an
/// invoice be attached to an existing supplier instead of creating a twin.
class DuplicateTaxIdException implements Exception {
  const DuplicateTaxIdException(this.taxId);

  final String taxId;

  @override
  String toString() => 'DuplicateTaxIdException($taxId)';
}

/// Raised when deleting a supplier would orphan invoices that reference it.
class SupplierInUseException implements Exception {
  const SupplierInUseException();

  @override
  String toString() => 'SupplierInUseException()';
}

abstract interface class CatalogRepository {
  Future<List<Supplier>> findSuppliers({String query = ''});

  /// Creates or updates [supplier].
  ///
  /// Throws [DuplicateTaxIdException] if the NIT belongs to another supplier.
  Future<int> saveSupplier(Supplier supplier);

  /// Throws [SupplierInUseException] if invoices still reference the supplier.
  Future<void> deleteSupplier(int id);

  Future<List<InvoiceCategory>> findCategories();

  Future<int> saveCategory(InvoiceCategory category);

  Future<void> deleteCategory(int id);
}
