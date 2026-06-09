import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';

class InvoiceRepository {
  final AppDatabase _db;

  InvoiceRepository(this._db);

  Future<int> createInvoiceWithItems(
      InvoicesCompanion invoice, List<InvoiceItemsCompanion> items) async {
    return _db.transaction(() async {
      // 1. Insert the invoice with a temporary total of 0 (or whatever value is passed)
      final invoiceId = await _db.into(_db.invoices).insert(invoice);

      // 2. Insert items and calculate line totals
      int calculatedTotalMinor = 0;
      for (final item in items) {
        final double qty = item.quantity.value;
        final int price = item.unitPriceMinor.value;
        final int lineTotal = (qty * price).round();
        calculatedTotalMinor += lineTotal;

        final itemCompanion = item.copyWith(
          invoiceId: Value(invoiceId),
          lineTotalMinor: Value(lineTotal),
        );
        await _db.into(_db.invoiceItems).insert(itemCompanion);
      }

      // 3. Update the invoice total
      await (_db.update(_db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).write(
        InvoicesCompanion(totalMinor: Value(calculatedTotalMinor)),
      );

      return invoiceId;
    });
  }

  Stream<List<Invoice>> watchInvoices({int? clientId, InvoiceStatus? status}) {
    final query = _db.select(_db.invoices);
    if (clientId != null) {
      query.where((tbl) => tbl.clientId.equals(clientId));
    }
    if (status != null) {
      query.where((tbl) => tbl.status.equals(status.index));
    }
    query.orderBy([(tbl) => OrderingTerm(expression: tbl.issueDate, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<Invoice?> getInvoice(int id) {
    return (_db.select(_db.invoices)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<InvoiceItem>> getItems(int invoiceId) {
    return (_db.select(_db.invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId))).get();
  }

  Future<void> updateInvoiceStatus(int id, InvoiceStatus status) async {
    await (_db.update(_db.invoices)..where((tbl) => tbl.id.equals(id))).write(
      InvoicesCompanion(status: Value(status)),
    );
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(databaseProvider)),
);
