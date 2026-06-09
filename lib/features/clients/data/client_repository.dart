import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';

class ClientRepository {
  final AppDatabase _db;

  ClientRepository(this._db);

  Stream<List<Client>> watchClients({String? search}) {
    final query = _db.select(_db.clients);
    if (search != null && search.trim().isNotEmpty) {
      query.where((tbl) => tbl.name.contains(search.trim()));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc)]);
    return query.watch();
  }

  Future<Client?> getClient(int id) {
    return (_db.select(_db.clients)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> addClient(ClientsCompanion data) {
    return _db.into(_db.clients).insert(data);
  }

  Future<bool> updateClient(ClientsCompanion data) {
    return (_db.update(_db.clients)..where((tbl) => tbl.id.equals(data.id.value))).write(data).then((count) => count > 0);
  }

  Future<void> setClientActive(int id, bool active) async {
    await (_db.update(_db.clients)..where((tbl) => tbl.id.equals(id))).write(
      ClientsCompanion(isActive: Value(active)),
    );
  }
}

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(ref.watch(databaseProvider)),
);
