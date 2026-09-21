import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  /// The in-flight (or completed) open operation.
  ///
  /// This caches the *future*, not the database. Caching the database means
  /// every caller that arrives before `openDatabase` completes sees `null` and
  /// opens its own handle — and the very first thing the app does is fire four
  /// concurrent queries through `Future.wait`, so that race happened on every
  /// cold start.
  Future<Database>? _opening;

  Future<Database> get instance => _opening ??= _open();

  Future<Database> _open() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final root = await getDatabasesPath();
      return await openDatabase(
        p.join(root, 'facturalens.db'),
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      );
    } catch (_) {
      // Don't cache a failed open: the next caller should be able to retry.
      _opening = null;
      rethrow;
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tax_id TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE UNIQUE INDEX idx_suppliers_tax_id
      ON suppliers(tax_id) WHERE tax_id <> ''
    ''');
    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color_value INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        category_id INTEGER,
        invoice_number TEXT NOT NULL,
        authorization_code TEXT NOT NULL DEFAULT '',
        fiscal_code TEXT NOT NULL DEFAULT '',
        issue_date TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'BOB',
        payment_method TEXT NOT NULL DEFAULT '',
        qr_content TEXT NOT NULL DEFAULT '',
        raw_ocr_text TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    batch.execute('''
      CREATE INDEX idx_invoices_issue_date ON invoices(issue_date DESC)
    ''');
    batch.execute('''
      CREATE INDEX idx_invoices_status ON invoices(status)
    ''');
    // Backs the duplicate lookup performed before confirming an invoice.
    batch.execute(_duplicateIndex);
    batch.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE invoice_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        rotation INTEGER NOT NULL DEFAULT 0,
        ocr_text TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await batch.commit(noResult: true);

    final seed = db.batch();
    const categories = <(String, int)>[
      ('Alimentación', 0xFF2F766D),
      ('Transporte', 0xFF3B6EA8),
      ('Servicios', 0xFF7B5EA7),
      ('Salud', 0xFFB04A5A),
      ('Educación', 0xFFB47824),
      ('Otros', 0xFF6A7180),
    ];
    for (final category in categories) {
      seed.insert('categories', {
        'name': category.$1,
        'color_value': category.$2,
      });
    }
    await seed.commit(noResult: true);
  }

  /// v2: index backing the duplicate-invoice lookup.
  static const String _duplicateIndex = '''
      CREATE INDEX IF NOT EXISTS idx_invoices_duplicate
      ON invoices(supplier_id, invoice_number)
    ''';

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 1 is the initial schema. Each migration is additive and guarded
    // so re-running it on a partially migrated database is harmless.
    if (oldVersion < 2) {
      await db.execute(_duplicateIndex);
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    final db = await opening;
    await db.close();
  }
}
