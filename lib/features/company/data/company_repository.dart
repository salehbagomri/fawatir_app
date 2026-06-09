import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';

class CompanyRepository {
  final AppDatabase _db;

  CompanyRepository(this._db);

  Future<Company?> getCompany() {
    return (_db.select(_db.companies)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
  }

  Future<void> saveCompany(CompaniesCompanion data) async {
    final companion = data.copyWith(id: const Value(1));
    await _db.into(_db.companies).insertOnConflictUpdate(companion);
  }

  Stream<Company?> watchCompany() {
    return (_db.select(_db.companies)..where((tbl) => tbl.id.equals(1))).watchSingleOrNull();
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>(
  (ref) => CompanyRepository(ref.watch(databaseProvider)),
);
