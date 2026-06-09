import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db/database.dart';
import '../../../data/db/tables.dart';

/// بيانات ملخّص لوحة المعلومات.
class DashboardStats {
  /// إجمالي المستحق (بعملة كل عميل → مُجمَّع كمبالغ صغرى).
  /// لأن العملات قد تختلف، نُعيد قائمة لكل عملة.
  final Map<String, int> totalOutstandingByCurrency;

  /// المتأخرات — فواتير بتاريخ استحقاق مضى ولم تُدفع/تُلغَ.
  final Map<String, int> overdueByCurrency;

  /// تحصيلات الشهر الحالي (بعملة كل عميل).
  final Map<String, int> monthCollectionsByCurrency;

  /// عدد العملاء النشطين.
  final int activeClientCount;

  /// عدد العملاء الإجمالي.
  final int totalClientCount;

  /// عدد الفواتير المعلّقة (sent, partiallyPaid, overdue).
  final int pendingInvoiceCount;

  /// عدد الفواتير المتأخرة.
  final int overdueInvoiceCount;

  const DashboardStats({
    required this.totalOutstandingByCurrency,
    required this.overdueByCurrency,
    required this.monthCollectionsByCurrency,
    required this.activeClientCount,
    required this.totalClientCount,
    required this.pendingInvoiceCount,
    required this.overdueInvoiceCount,
  });
}

class DashboardRepository {
  final AppDatabase _db;

  DashboardRepository(this._db);

  Future<DashboardStats> getStats() async {
    // ── عدد العملاء ──
    final allClients = await _db.select(_db.clients).get();
    final activeClients =
        allClients.where((c) => c.isActive).toList();

    // ── الفواتير غير الملغاة وغير المسودة ──
    final invoices = await (_db.select(_db.invoices)
          ..where((i) =>
              i.status.equals(InvoiceStatus.cancelled.index).not() &
              i.status.equals(InvoiceStatus.draft.index).not()))
        .get();

    // ── كل المدفوعات ──
    final payments = await _db.select(_db.payments).get();

    // ── حساب إجمالي المستحق لكل عملة حساب عميل ──
    // المستحق = مجموع (الفواتير بعملة الحساب) − مجموع (المدفوعات بعملة الحساب)
    // نحتاج عملة حساب العميل لكل عملية.
    final clientCurrencyMap = <int, String>{};
    for (final c in allClients) {
      clientCurrencyMap[c.id] = c.accountCurrency;
    }

    // مدين كل عملة (فواتير × سعر الصرف)
    final debitByCurrency = <String, double>{};
    for (final inv in invoices) {
      final cur = clientCurrencyMap[inv.clientId] ?? 'USD';
      final amt = inv.totalMinor * inv.fxRateToAccount;
      debitByCurrency[cur] = (debitByCurrency[cur] ?? 0) + amt;
    }

    // دائن كل عملة (مدفوعات × سعر الصرف)
    final creditByCurrency = <String, double>{};
    for (final pay in payments) {
      final cur = clientCurrencyMap[pay.clientId] ?? 'USD';
      final amt = pay.amountMinor * pay.fxRateToAccount;
      creditByCurrency[cur] = (creditByCurrency[cur] ?? 0) + amt;
    }

    // المستحق = مدين − دائن
    final allCurrencies = {...debitByCurrency.keys, ...creditByCurrency.keys};
    final totalOutstanding = <String, int>{};
    for (final cur in allCurrencies) {
      final balance =
          (debitByCurrency[cur] ?? 0) - (creditByCurrency[cur] ?? 0);
      if (balance.round() != 0) {
        totalOutstanding[cur] = balance.round();
      }
    }

    // ── المتأخرات ──
    final now = DateTime.now();
    final overdueInvoices = invoices.where((i) =>
        i.dueDate != null &&
        now.isAfter(i.dueDate!) &&
        i.status != InvoiceStatus.paid);

    int overdueCount = 0;
    final overdueByCurrency = <String, double>{};
    for (final inv in overdueInvoices) {
      overdueCount++;
      final cur = clientCurrencyMap[inv.clientId] ?? 'USD';
      final amt = inv.totalMinor * inv.fxRateToAccount;
      overdueByCurrency[cur] = (overdueByCurrency[cur] ?? 0) + amt;
    }

    // اطرح المدفوع على الفواتير المتأخرة
    final overdueIds = overdueInvoices.map((i) => i.id).toSet();
    final overduePaidByCurrency = <String, double>{};
    for (final pay in payments) {
      if (pay.invoiceId != null && overdueIds.contains(pay.invoiceId)) {
        final cur = clientCurrencyMap[pay.clientId] ?? 'USD';
        final amt = pay.amountMinor * pay.fxRateToAccount;
        overduePaidByCurrency[cur] =
            (overduePaidByCurrency[cur] ?? 0) + amt;
      }
    }

    final overdueNet = <String, int>{};
    final overdueCurrencies = {
      ...overdueByCurrency.keys,
      ...overduePaidByCurrency.keys,
    };
    for (final cur in overdueCurrencies) {
      final net = (overdueByCurrency[cur] ?? 0) -
          (overduePaidByCurrency[cur] ?? 0);
      if (net.round() > 0) {
        overdueNet[cur] = net.round();
      }
    }

    // ── تحصيلات الشهر ──
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final monthPayments = payments.where(
        (p) => !p.paymentDate.isBefore(monthStart) && !p.paymentDate.isAfter(monthEnd));

    final monthCollections = <String, int>{};
    for (final pay in monthPayments) {
      final cur = clientCurrencyMap[pay.clientId] ?? 'USD';
      final amt = (pay.amountMinor * pay.fxRateToAccount).round();
      monthCollections[cur] = (monthCollections[cur] ?? 0) + amt;
    }

    // ── عدد الفواتير المعلّقة ──
    final pendingCount = invoices
        .where((i) =>
            i.status == InvoiceStatus.sent ||
            i.status == InvoiceStatus.partiallyPaid ||
            (i.dueDate != null &&
                now.isAfter(i.dueDate!) &&
                i.status != InvoiceStatus.paid))
        .length;

    return DashboardStats(
      totalOutstandingByCurrency: totalOutstanding,
      overdueByCurrency: overdueNet,
      monthCollectionsByCurrency: monthCollections,
      activeClientCount: activeClients.length,
      totalClientCount: allClients.length,
      pendingInvoiceCount: pendingCount,
      overdueInvoiceCount: overdueCount,
    );
  }

  /// Stream يعيد البيانات عند أي تغيير في الفواتير أو المدفوعات أو العملاء.
  Stream<DashboardStats> watchStats() {
    // نراقب الجداول الثلاثة ونعيد الحساب عند أي تغيير.
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.invoices, _db.payments, _db.clients},
        )
        .watch()
        .asyncMap((_) => getStats());
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(databaseProvider)),
);

final dashboardStatsProvider = StreamProvider<DashboardStats>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchStats(),
);
