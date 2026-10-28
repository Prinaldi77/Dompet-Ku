import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../ledger/ledger_service.dart';
import '../ledger/ledger_types.dart';

class CategoryService {
  CategoryService(this._db);

  final AppDatabase _db;

  Future<int> add({required String name, required String tipe}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('Nama kategori wajib diisi.');
    }
    if (tipe != TxType.income && tipe != TxType.expense) {
      throw ValidationException('Tipe kategori tidak valid.');
    }

    final existing = await (_db.select(_db.categories)
          ..where((c) => c.name.lower().equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) {
      throw ValidationException('Nama kategori sudah dipakai.');
    }

    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: trimmed,
            tipe: tipe,
            sortOrder: const Value(100),
          ),
        );
  }

  Future<void> setActive(int id, bool active) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(isActive: Value(active)));
  }
}
