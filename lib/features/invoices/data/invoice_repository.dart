import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';

class InvoiceRepository {
  final AppDatabase _db;

  InvoiceRepository(this._db);

  static ({int subtotal, int discount, int tax, int total}) calculateTotals({
    required int subtotalMinor,
    double discountPercent = 0.0,
    int discountMinor = 0,
    double taxPercent = 0.0,
    int taxMinor = 0,
  }) {
    int finalDiscount = discountMinor;
    if (discountPercent > 0) {
      finalDiscount = (subtotalMinor * discountPercent / 100).round();
    }
    if (finalDiscount > subtotalMinor) {
      finalDiscount = subtotalMinor;
    }
    final netAfterDiscount = subtotalMinor - finalDiscount;
    int finalTax = taxMinor;
    if (taxPercent > 0) {
      finalTax = (netAfterDiscount * taxPercent / 100).round();
    }
    final total = netAfterDiscount + finalTax;
    return (
      subtotal: subtotalMinor,
      discount: finalDiscount,
      tax: finalTax,
      total: total,
    );
  }

  Future<int> createInvoiceWithItems(
      InvoicesCompanion invoice, List<InvoiceItemsCompanion> items) async {
    return _db.transaction(() async {
      // 1. Insert the invoice
      final invoiceId = await _db.into(_db.invoices).insert(invoice);

      // 2. Insert items and calculate line totals
      int subtotalMinor = 0;
      for (final item in items) {
        final double qty = item.quantity.value;
        final int price = item.unitPriceMinor.value;
        final int lineTotal = (qty * price).round();
        subtotalMinor += lineTotal;

        final itemCompanion = item.copyWith(
          invoiceId: Value(invoiceId),
          lineTotalMinor: Value(lineTotal),
        );
        await _db.into(_db.invoiceItems).insert(itemCompanion);
      }

      // 3. Compute discount, tax, and final total
      final discPercent = invoice.discountPercent.present ? invoice.discountPercent.value : 0.0;
      final discMinor = invoice.discountMinor.present ? invoice.discountMinor.value : 0;
      final tPercent = invoice.taxPercent.present ? invoice.taxPercent.value : 0.0;
      final tMinor = invoice.taxMinor.present ? invoice.taxMinor.value : 0;

      final calc = calculateTotals(
        subtotalMinor: subtotalMinor,
        discountPercent: discPercent,
        discountMinor: discMinor,
        taxPercent: tPercent,
        taxMinor: tMinor,
      );

      // 4. Update the invoice with computed totals
      await (_db.update(_db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).write(
        InvoicesCompanion(
          discountMinor: Value(calc.discount),
          taxMinor: Value(calc.tax),
          totalMinor: Value(calc.total),
        ),
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
      if (status == InvoiceStatus.overdue) {
        final now = DateTime.now();
        query.where((tbl) =>
            tbl.dueDate.isNotNull() &
            tbl.dueDate.isSmallerThanValue(now) &
            tbl.status.equals(InvoiceStatus.paid.index).not() &
            tbl.status.equals(InvoiceStatus.cancelled.index).not() &
            tbl.status.equals(InvoiceStatus.draft.index).not());
      } else {
        query.where((tbl) => tbl.status.equals(status.index));
      }
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

  Future<void> updateInvoiceWithItems(
      int invoiceId, InvoicesCompanion invoiceCompanion, List<InvoiceItemsCompanion> items) async {
    return _db.transaction(() async {
      int subtotalMinor = 0;
      final processedItems = <InvoiceItemsCompanion>[];
      for (final item in items) {
        final double qty = item.quantity.value;
        final int price = item.unitPriceMinor.value;
        final int lineTotal = (qty * price).round();
        subtotalMinor += lineTotal;

        processedItems.add(item.copyWith(
          invoiceId: Value(invoiceId),
          lineTotalMinor: Value(lineTotal),
        ));
      }

      final discPercent = invoiceCompanion.discountPercent.present ? invoiceCompanion.discountPercent.value : 0.0;
      final discMinor = invoiceCompanion.discountMinor.present ? invoiceCompanion.discountMinor.value : 0;
      final tPercent = invoiceCompanion.taxPercent.present ? invoiceCompanion.taxPercent.value : 0.0;
      final tMinor = invoiceCompanion.taxMinor.present ? invoiceCompanion.taxMinor.value : 0;

      final calc = calculateTotals(
        subtotalMinor: subtotalMinor,
        discountPercent: discPercent,
        discountMinor: discMinor,
        taxPercent: tPercent,
        taxMinor: tMinor,
      );

      await (_db.update(_db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).write(
        invoiceCompanion.copyWith(
          discountMinor: Value(calc.discount),
          taxMinor: Value(calc.tax),
          totalMinor: Value(calc.total),
        ),
      );

      await (_db.delete(_db.invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId))).go();

      for (final item in processedItems) {
        await _db.into(_db.invoiceItems).insert(item);
      }
    });
  }

  Future<void> deleteInvoice(int invoiceId) async {
    return _db.transaction(() async {
      await (_db.delete(_db.invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId))).go();
      await (_db.delete(_db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).go();
    });
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

class InvoiceProfit {
  final int totalRevenueMinor;
  final int totalCostMinor;
  final int transactionFeesMinor;
  final int netProfitMinor;
  final double profitMarginPercent;

  const InvoiceProfit({
    required this.totalRevenueMinor,
    required this.totalCostMinor,
    required this.transactionFeesMinor,
    required this.netProfitMinor,
    required this.profitMarginPercent,
  });
}

InvoiceProfit calculateInvoiceProfit(Invoice invoice, List<InvoiceItem> items) {
  int totalCost = 0;
  for (final item in items) {
    totalCost += (item.quantity * item.costPriceMinor).round();
  }
  final fees = invoice.transactionFeesMinor;
  final revenue = invoice.totalMinor;
  final netProfit = revenue - totalCost - fees;
  final margin = revenue > 0 ? (netProfit / revenue) * 100 : 0.0;

  return InvoiceProfit(
    totalRevenueMinor: revenue,
    totalCostMinor: totalCost,
    transactionFeesMinor: fees,
    netProfitMinor: netProfit,
    profitMarginPercent: margin,
  );
}
