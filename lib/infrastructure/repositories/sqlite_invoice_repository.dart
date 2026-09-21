import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_category.dart';
import '../../domain/entities/invoice_image.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/ports/catalog_repository.dart';
import '../../domain/ports/invoice_repository.dart';
import '../database/app_database.dart';

class SqliteInvoiceRepository implements InvoiceRepository, CatalogRepository {
  SqliteInvoiceRepository(this._database);

  final AppDatabase _database;

  static const String _invoiceSelect = '''
      SELECT i.*, s.name AS supplier_name, s.tax_id AS supplier_tax_id,
             COALESCE(c.name, 'Sin categoría') AS category_name
      FROM invoices i
      JOIN suppliers s ON s.id = i.supplier_id
      LEFT JOIN categories c ON c.id = i.category_id
  ''';

  @override
  Future<List<Invoice>> findAll({
    String query = '',
    InvoiceStatus? status,
    int? categoryId,
  }) async {
    final db = await _database.instance;
    final clauses = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      clauses.add('''
        (s.name LIKE ? OR s.tax_id LIKE ? OR i.invoice_number LIKE ?)
      ''');
      final value = '%${query.trim()}%';
      args.addAll([value, value, value]);
    }
    if (status != null) {
      clauses.add('i.status = ?');
      args.add(status.name);
    }
    if (categoryId != null) {
      clauses.add('i.category_id = ?');
      args.add(categoryId);
    }

    final rows = await db.rawQuery('''
      $_invoiceSelect
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY i.issue_date DESC, i.id DESC
    ''', args);
    return Future.wait(rows.map((row) => _hydrateInvoice(db, row)));
  }

  @override
  Future<Invoice?> findById(int id) async {
    final db = await _database.instance;
    final rows = await db.rawQuery('$_invoiceSelect WHERE i.id = ? LIMIT 1', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return _hydrateInvoice(db, rows.first);
  }

  @override
  Future<Invoice?> findDuplicate({
    required String number,
    required String supplierName,
    required DateTime issueDate,
    int? excludingId,
  }) async {
    final trimmedNumber = number.trim();
    final trimmedSupplier = supplierName.trim();
    // Without a number there is nothing distinctive enough to match on.
    if (trimmedNumber.isEmpty || trimmedSupplier.isEmpty) return null;

    final db = await _database.instance;
    final day = DateTime(issueDate.year, issueDate.month, issueDate.day);
    final nextDay = day.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      '''
      $_invoiceSelect
      WHERE i.invoice_number = ?
        AND s.name = ? COLLATE NOCASE
        AND i.issue_date >= ? AND i.issue_date < ?
        AND (? IS NULL OR i.id <> ?)
      LIMIT 1
    ''',
      [
        trimmedNumber,
        trimmedSupplier,
        day.toIso8601String(),
        nextDay.toIso8601String(),
        excludingId,
        excludingId,
      ],
    );
    if (rows.isEmpty) return null;
    return _hydrateInvoice(db, rows.first);
  }

  Future<Invoice> _hydrateInvoice(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as int;
    final itemRows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final imageRows = await db.query(
      'invoice_images',
      where: 'invoice_id = ?',
      whereArgs: [id],
      orderBy: 'page_index ASC',
    );
    return Invoice(
      id: id,
      supplierId: row['supplier_id']! as int,
      categoryId: row['category_id'] as int?,
      supplierName: row['supplier_name']! as String,
      supplierTaxId: row['supplier_tax_id']! as String,
      categoryName: row['category_name']! as String,
      number: row['invoice_number']! as String,
      authorizationCode: row['authorization_code']! as String,
      fiscalCode: row['fiscal_code']! as String,
      issueDate: DateTime.parse(row['issue_date']! as String),
      subtotal: (row['subtotal']! as num).toDouble(),
      discount: (row['discount']! as num).toDouble(),
      tax: (row['tax']! as num).toDouble(),
      total: (row['total']! as num).toDouble(),
      currency: row['currency']! as String,
      paymentMethod: row['payment_method']! as String,
      qrContent: row['qr_content']! as String,
      rawOcrText: row['raw_ocr_text']! as String,
      status: _statusFrom(row['status']),
      createdAt: DateTime.parse(row['created_at']! as String),
      items: itemRows
          .map(
            (item) => InvoiceItem(
              id: item['id']! as int,
              invoiceId: item['invoice_id']! as int,
              description: item['description']! as String,
              quantity: (item['quantity']! as num).toDouble(),
              unitPrice: (item['unit_price']! as num).toDouble(),
              discount: (item['discount']! as num).toDouble(),
              lineTotal: (item['line_total']! as num).toDouble(),
            ),
          )
          .toList(growable: false),
      images: imageRows
          .map(
            (image) => InvoiceImage(
              id: image['id']! as int,
              invoiceId: image['invoice_id']! as int,
              path: image['image_path']! as String,
              pageIndex: image['page_index']! as int,
              rotation: image['rotation']! as int,
              ocrText: image['ocr_text']! as String,
            ),
          )
          .toList(growable: false),
    );
  }

  /// A status the enum does not know about must not take the whole list down.
  static InvoiceStatus _statusFrom(Object? value) {
    final name = value as String?;
    return InvoiceStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => InvoiceStatus.draft,
    );
  }

  @override
  Future<int> save(Invoice invoice) async {
    final db = await _database.instance;
    // Image files whose rows disappear during this save, collected inside the
    // transaction and deleted only once it has actually committed.
    final orphanedImages = <String>[];

    final invoiceId = await db.transaction<int>((txn) async {
      final supplierId = await _resolveSupplier(txn, invoice);
      final now = DateTime.now().toIso8601String();
      final values = <String, Object?>{
        'supplier_id': supplierId,
        'category_id': invoice.categoryId,
        'invoice_number': invoice.number.trim(),
        'authorization_code': invoice.authorizationCode.trim(),
        'fiscal_code': invoice.fiscalCode.trim(),
        'issue_date': invoice.issueDate.toIso8601String(),
        'subtotal': invoice.subtotal,
        'discount': invoice.discount,
        'tax': invoice.tax,
        'total': invoice.total,
        'currency': invoice.currency,
        'payment_method': invoice.paymentMethod.trim(),
        'qr_content': invoice.qrContent,
        'raw_ocr_text': invoice.rawOcrText,
        'status': invoice.status.name,
        'updated_at': now,
      };

      late final int id;
      if (invoice.id == null) {
        id = await txn.insert('invoices', {
          ...values,
          'created_at': invoice.createdAt.toIso8601String(),
        });
      } else {
        id = invoice.id!;
        await txn.update('invoices', values, where: 'id = ?', whereArgs: [id]);

        // Work out which image files are being dropped before deleting rows.
        final keptPaths = invoice.images.map((image) => image.path).toSet();
        final existing = await txn.query(
          'invoice_images',
          columns: ['image_path'],
          where: 'invoice_id = ?',
          whereArgs: [id],
        );
        for (final row in existing) {
          final path = row['image_path'] as String?;
          if (path != null && !keptPaths.contains(path)) {
            orphanedImages.add(path);
          }
        }

        await txn.delete(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'invoice_images',
          where: 'invoice_id = ?',
          whereArgs: [id],
        );
      }

      for (final item in invoice.items) {
        await txn.insert('invoice_items', {
          'invoice_id': id,
          'description': item.description.trim(),
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount': item.discount,
          'line_total': item.lineTotal,
        });
      }
      for (final image in invoice.images) {
        await txn.insert('invoice_images', {
          'invoice_id': id,
          'image_path': image.path,
          'page_index': image.pageIndex,
          'rotation': image.rotation,
          'ocr_text': image.ocrText,
        });
      }
      return id;
    });

    await _deleteFiles(orphanedImages);
    return invoiceId;
  }

  Future<int> _resolveSupplier(Transaction txn, Invoice invoice) async {
    final taxId = invoice.supplierTaxId.trim();
    final name = invoice.supplierName.trim();

    if (invoice.supplierId != null) {
      final values = <String, Object?>{'name': name};
      // Only write the NIT when we actually have one. OCR misses it often, and
      // blindly copying an empty string used to wipe the NIT already stored
      // for this supplier in the catalog.
      if (taxId.isNotEmpty) values['tax_id'] = taxId;
      try {
        await txn.update(
          'suppliers',
          values,
          where: 'id = ?',
          whereArgs: [invoice.supplierId],
        );
      } on DatabaseException catch (error) {
        if (!_isUniqueConstraint(error)) rethrow;
        // Another supplier already owns this NIT — keep the invoice attached
        // to its supplier and leave the conflicting NIT out rather than
        // failing the whole save.
        await txn.update(
          'suppliers',
          {'name': name},
          where: 'id = ?',
          whereArgs: [invoice.supplierId],
        );
      }
      return invoice.supplierId!;
    }

    if (taxId.isNotEmpty) {
      final rows = await txn.query(
        'suppliers',
        columns: ['id'],
        where: 'tax_id = ?',
        whereArgs: [taxId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final id = rows.first['id']! as int;
        await txn.update(
          'suppliers',
          {'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }
    }
    return txn.insert('suppliers', {
      'name': name,
      'tax_id': taxId,
      'address': '',
      'phone': '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> delete(int id) async {
    final invoice = await findById(id);
    final db = await _database.instance;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    if (invoice != null) {
      await _deleteFiles(invoice.images.map((image) => image.path));
    }
  }

  @override
  Future<DashboardStats> dashboardStats(DateTime now) async {
    final db = await _database.instance;
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final previousMonth = DateTime(now.year, now.month - 1);
    final current = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total,
             COALESCE(AVG(total), 0) AS average,
             COUNT(*) AS count
      FROM invoices
      WHERE status = 'verified' AND issue_date >= ? AND issue_date < ?
    ''',
      [monthStart.toIso8601String(), nextMonth.toIso8601String()],
    );
    final previous = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM invoices
      WHERE status = 'verified' AND issue_date >= ? AND issue_date < ?
    ''',
      [previousMonth.toIso8601String(), monthStart.toIso8601String()],
    );
    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM invoices WHERE status = 'draft'",
          ),
        ) ??
        0;

    final allTimeRow = await db.rawQuery('''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM invoices
      WHERE status = 'verified'
    ''');
    final allTimeTotal = (allTimeRow.first['total']! as num).toDouble();

    final taxRow = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(tax), 0) AS tax
      FROM invoices
      WHERE status = 'verified' AND issue_date >= ? AND issue_date < ?
    ''',
      [monthStart.toIso8601String(), nextMonth.toIso8601String()],
    );
    final monthTax = (taxRow.first['tax']! as num).toDouble();

    final highestRows = await db.rawQuery(
      '''
      SELECT s.name AS label, i.total AS amount
      FROM invoices i
      JOIN suppliers s ON s.id = i.supplier_id
      WHERE i.status = 'verified' AND i.issue_date >= ? AND i.issue_date < ?
      ORDER BY i.total DESC
      LIMIT 1
    ''',
      [monthStart.toIso8601String(), nextMonth.toIso8601String()],
    );
    final highestInvoice = highestRows.isEmpty
        ? null
        : SpendSlice(
            label: highestRows.first['label']! as String,
            amount: (highestRows.first['amount']! as num).toDouble(),
          );

    // Tendencia de gasto de los últimos 6 meses (incluye el mes actual).
    final trendStart = DateTime(now.year, now.month - 5);
    final trendRows = await db.rawQuery(
      '''
      SELECT strftime('%Y-%m', issue_date) AS ym, SUM(total) AS amount
      FROM invoices
      WHERE status = 'verified' AND issue_date >= ? AND issue_date < ?
      GROUP BY ym
    ''',
      [trendStart.toIso8601String(), nextMonth.toIso8601String()],
    );
    final trendByMonth = <String, double>{
      for (final row in trendRows)
        if (row['ym'] != null)
          row['ym']! as String: (row['amount'] as num?)?.toDouble() ?? 0,
    };
    const monthAbbrev = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final monthlyTrend = <SpendSlice>[
      for (var i = 5; i >= 0; i--)
        SpendSlice(
          label: monthAbbrev[DateTime(now.year, now.month - i).month - 1],
          amount:
              trendByMonth[_monthKey(DateTime(now.year, now.month - i))] ?? 0,
        ),
    ];

    final categories = await db.rawQuery(
      '''
      SELECT COALESCE(c.name, 'Sin categoría') AS label, SUM(i.total) AS amount
      FROM invoices i
      LEFT JOIN categories c ON c.id = i.category_id
      WHERE i.status = 'verified' AND i.issue_date >= ? AND i.issue_date < ?
      GROUP BY c.id, c.name
      ORDER BY amount DESC
    ''',
      [monthStart.toIso8601String(), nextMonth.toIso8601String()],
    );
    final suppliers = await db.rawQuery('''
      SELECT s.name AS label, SUM(i.total) AS amount
      FROM invoices i
      JOIN suppliers s ON s.id = i.supplier_id
      WHERE i.status = 'verified'
      GROUP BY s.id, s.name
      ORDER BY amount DESC
      LIMIT 5
    ''');
    final summary = current.first;
    return DashboardStats(
      monthTotal: (summary['total']! as num).toDouble(),
      previousMonthTotal: (previous.first['total']! as num).toDouble(),
      averageTicket: (summary['average']! as num).toDouble(),
      invoiceCount: summary['count']! as int,
      pendingCount: pending,
      allTimeTotal: allTimeTotal,
      monthTax: monthTax,
      highestInvoice: highestInvoice,
      monthlyTrend: monthlyTrend,
      byCategory: categories
          .map(
            (row) => SpendSlice(
              label: row['label']! as String,
              amount: (row['amount'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false),
      bySupplier: suppliers
          .map(
            (row) => SpendSlice(
              label: row['label']! as String,
              amount: (row['amount'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<Supplier>> findSuppliers({String query = ''}) async {
    final db = await _database.instance;
    final rows = await db.query(
      'suppliers',
      where: query.trim().isEmpty ? null : '(name LIKE ? OR tax_id LIKE ?)',
      whereArgs: query.trim().isEmpty
          ? null
          : ['%${query.trim()}%', '%${query.trim()}%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => Supplier(
            id: row['id']! as int,
            name: row['name']! as String,
            taxId: row['tax_id']! as String,
            address: row['address']! as String,
            phone: row['phone']! as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> saveSupplier(Supplier supplier) async {
    final db = await _database.instance;
    final taxId = supplier.taxId.trim();
    final values = {
      'name': supplier.name.trim(),
      'tax_id': taxId,
      'address': supplier.address.trim(),
      'phone': supplier.phone.trim(),
    };
    try {
      if (supplier.id == null) {
        return await db.insert('suppliers', {
          ...values,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await db.update(
        'suppliers',
        values,
        where: 'id = ?',
        whereArgs: [supplier.id],
      );
      return supplier.id!;
    } on DatabaseException catch (error) {
      // The NIT is unique by design; surface that as a domain error instead of
      // letting a raw sqflite exception escape into the widget tree.
      if (_isUniqueConstraint(error)) throw DuplicateTaxIdException(taxId);
      rethrow;
    }
  }

  @override
  Future<void> deleteSupplier(int id) async {
    final db = await _database.instance;
    try {
      await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (_) {
      throw const SupplierInUseException();
    }
  }

  @override
  Future<List<InvoiceCategory>> findCategories() async {
    final db = await _database.instance;
    final rows = await db.query(
      'categories',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => InvoiceCategory(
            id: row['id']! as int,
            name: row['name']! as String,
            colorValue: row['color_value']! as int,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> saveCategory(InvoiceCategory category) async {
    final db = await _database.instance;
    final values = {
      'name': category.name.trim(),
      'color_value': category.colorValue,
    };
    if (category.id == null) return db.insert('categories', values);
    await db.update(
      'categories',
      values,
      where: 'id = ?',
      whereArgs: [category.id],
    );
    return category.id!;
  }

  @override
  Future<void> deleteCategory(int id) async {
    final db = await _database.instance;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  static bool _isUniqueConstraint(DatabaseException error) {
    if (error.isUniqueConstraintError()) return true;
    return error.toString().toUpperCase().contains('UNIQUE CONSTRAINT');
  }

  static Future<void> _deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (error) {
        debugPrint('Could not delete image $path: $error');
      }
    }
  }

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}
