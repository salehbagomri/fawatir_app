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

  Future<String> nextInvoiceNumber() async {
    return _db.transaction(() async {
      var company = await (_db.select(_db.companies)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
      if (company == null) {
        await _db.into(_db.companies).insert(
          const CompaniesCompanion(
            id: Value(1),
            name: Value('شركتي'),
            defaultCurrency: Value('USD'),
            invoicePrefix: Value('INV-'),
            invoiceCounter: Value(0),
          ),
        );
        company = await (_db.select(_db.companies)..where((tbl) => tbl.id.equals(1))).getSingle();
      }

      final newCounter = company.invoiceCounter + 1;
      await (_db.update(_db.companies)..where((tbl) => tbl.id.equals(1))).write(
        CompaniesCompanion(invoiceCounter: Value(newCounter)),
      );

      final counterStr = newCounter.toString().padLeft(4, '0');
      final currentYear = DateTime.now().year;
      final prefix = company.invoicePrefix;
      return '$prefix$currentYear-$counterStr';
    });
  }

  Future<List<int>> generateMonthlyInvoices({DateTime? forMonth}) async {
    final target = forMonth ?? DateTime.now();
    final periodMarker = DateTime(target.year, target.month, 1);
    final monthStart = periodMarker;
    final monthEnd = DateTime(target.year, target.month + 1, 0);

    final subs = await (_db.select(_db.subscriptions)
          ..where((s) => s.isActive.equals(true)))
        .get();

    final createdIds = <int>[];
    for (final s in subs) {
      final started = !s.startDate.isAfter(monthEnd);
      final notEnded = s.endDate == null || !s.endDate!.isBefore(monthStart);
      final notGenerated = s.lastGeneratedPeriod == null ||
          s.lastGeneratedPeriod!.isBefore(periodMarker);
      if (!(started && notEnded && notGenerated)) continue;

      final number = await nextInvoiceNumber();
      final issueDate =
          DateTime(target.year, target.month, s.billingDayOfMonth);
      final invoice = InvoicesCompanion.insert(
        number: number,
        clientId: s.clientId,
        issueDate: issueDate,
        currency: s.currency,
        status: const Value(InvoiceStatus.draft),
        subscriptionId: Value(s.id),
      );

      final items = [
        InvoiceItemsCompanion(
          invoiceId: const Value.absent(),
          description: Value('${s.title} — ${target.month}/${target.year}'),
          quantity: const Value(1.0),
          unitPriceMinor: Value(s.unitPriceMinor),
          lineTotalMinor: const Value(0),
        )
      ];

      final id = await createInvoiceWithItems(invoice, items);
      createdIds.add(id);

      await (_db.update(_db.subscriptions)..where((x) => x.id.equals(s.id)))
          .write(SubscriptionsCompanion(
              lastGeneratedPeriod: Value(periodMarker)));
    }
    return createdIds;
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(databaseProvider)),
);
