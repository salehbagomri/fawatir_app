import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and read client', () async {
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل تجريبي'),
        accountCurrency: Value('USD'),
      ),
    );

    final client = await (db.select(db.clients)..where((tbl) => tbl.id.equals(clientId))).getSingle();

    expect(client.name, 'عميل تجريبي');
    expect(client.accountCurrency, 'USD');
  });
}
