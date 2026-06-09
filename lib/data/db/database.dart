import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Companies,
  Clients,
  Invoices,
  InvoiceItems,
  Payments,
  Subscriptions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<File> databaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File('${dbFolder.path}/fawatir_db.sqlite');
  }
}

QueryExecutor _openConnection() {
  final connection = driftDatabase(
    name: 'fawatir_db',
    native: DriftNativeOptions(
      databasePath: () async {
        final dbFolder = await getApplicationDocumentsDirectory();
        return '${dbFolder.path}/fawatir_db.sqlite';
      },
    ),
  ) as DatabaseConnection;
  return DatabaseConnection(
    connection.executor,
    streamQueries: connection.streamQueries,
    closeStreamsSynchronously: true,
  );
}

/// مزوّد Riverpod لقاعدة البيانات (نقطة وصول موحّدة).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
