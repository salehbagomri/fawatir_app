import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';

class SubscriptionRepository {
  final AppDatabase _db;

  SubscriptionRepository(this._db);

  Stream<List<Subscription>> watchSubscriptions(int clientId) {
    return (_db.select(_db.subscriptions)
          ..where((tbl) => tbl.clientId.equals(clientId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addSubscription(SubscriptionsCompanion data) {
    return _db.into(_db.subscriptions).insert(data);
  }

  Future<bool> updateSubscription(SubscriptionsCompanion data) {
    return (_db.update(_db.subscriptions)..where((tbl) => tbl.id.equals(data.id.value)))
        .write(data)
        .then((count) => count > 0);
  }

  Future<void> setSubscriptionActive(int id, bool active) async {
    await (_db.update(_db.subscriptions)..where((tbl) => tbl.id.equals(id))).write(
      SubscriptionsCompanion(isActive: Value(active)),
    );
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(databaseProvider)),
);
