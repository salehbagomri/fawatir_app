import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

// Phase 5: Date Range Filter
enum InvoiceDateFilterOption {
  all('كل الأوقات'),
  today('اليوم'),
  thisWeek('هذا الأسبوع'),
  thisMonth('هذا الشهر'),
  lastMonth('الشهر الماضي'),
  custom('مخصص...');

  final String label;
  const InvoiceDateFilterOption(this.label);
}

class InvoiceDateFilterState {
  final InvoiceDateFilterOption option;
  final DateTimeRange? customRange;

  const InvoiceDateFilterState({
    this.option = InvoiceDateFilterOption.all,
    this.customRange,
  });
}

final invoiceDateFilterProvider = NotifierProvider.autoDispose<InvoiceDateFilterNotifier, InvoiceDateFilterState>(
  InvoiceDateFilterNotifier.new,
);

class InvoiceDateFilterNotifier extends Notifier<InvoiceDateFilterState> {
  @override
  InvoiceDateFilterState build() => const InvoiceDateFilterState();

  void setFilter(InvoiceDateFilterOption opt, [DateTimeRange? range]) {
    state = InvoiceDateFilterState(option: opt, customRange: range);
  }

  void reset() {
    state = const InvoiceDateFilterState();
  }
}

final activeClientsProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients().map(
    (clients) => clients.where((c) => c.isActive).toList(),
  );
});

final invoiceStatusFilterProvider = NotifierProvider.autoDispose<InvoiceStatusFilterNotifier, InvoiceStatus?>(
  InvoiceStatusFilterNotifier.new,
);

class InvoiceStatusFilterNotifier extends Notifier<InvoiceStatus?> {
  @override
  InvoiceStatus? build() => null;

  void setFilter(InvoiceStatus? status) {
    state = status;
  }
}

final invoicesListProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final status = ref.watch(invoiceStatusFilterProvider);
  return ref.watch(invoiceRepositoryProvider).watchInvoices(status: status);
});

final invoiceByIdProvider =
    FutureProvider.autoDispose.family<Invoice?, int>((ref, id) =>
        ref.watch(invoiceRepositoryProvider).getInvoice(id));

final invoiceItemsProvider = FutureProvider.autoDispose
    .family<List<InvoiceItem>, int>((ref, id) =>
        ref.watch(invoiceRepositoryProvider).getItems(id));

final clientsMapProvider = StreamProvider.autoDispose<Map<int, String>>((ref) =>
    ref.watch(clientRepositoryProvider).watchClients()
       .map((l) => {for (final c in l) c.id: c.name}));

final clientInvoicesProvider = StreamProvider.autoDispose.family<List<Invoice>, int>((ref, clientId) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices(clientId: clientId);
});

// Phase 2: Search Provider
final invoiceSearchProvider = NotifierProvider.autoDispose<InvoiceSearchNotifier, String>(
  InvoiceSearchNotifier.new,
);

class InvoiceSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

// Phase 2: Sort Provider
enum InvoiceSortOption {
  dateDesc('الأحدث أولاً'),
  dateAsc('الأقدم أولاً'),
  amountDesc('الأعلى قيمة'),
  amountAsc('الأقل قيمة'),
  dueDateAsc('الأقرب استحقاقاً');

  final String label;
  const InvoiceSortOption(this.label);
}

final invoiceSortProvider = NotifierProvider.autoDispose<InvoiceSortNotifier, InvoiceSortOption>(
  InvoiceSortNotifier.new,
);

class InvoiceSortNotifier extends Notifier<InvoiceSortOption> {
  @override
  InvoiceSortOption build() => InvoiceSortOption.dateDesc;

  void setSort(InvoiceSortOption sort) => state = sort;
}

// Phase 2: All Invoices Stream (for counts and stats)
final allInvoicesStreamProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices();
});

// Phase 2: Invoice Counts by Status
final invoiceCountsProvider = Provider.autoDispose<Map<InvoiceStatus?, int>>((ref) {
  final invoicesAsync = ref.watch(allInvoicesStreamProvider);
  final invoices = invoicesAsync.value ?? [];
  final counts = <InvoiceStatus?, int>{
    null: invoices.length,
  };
  for (final s in InvoiceStatus.values) {
    counts[s] = invoices.where((i) => i.status == s).length;
  }
  return counts;
});

// Phase 2: Financial Summary
class InvoicesSummaryData {
  final int totalCount;
  final int totalAmountMinor;
  final int paidCount;
  final int overdueCount;

  const InvoicesSummaryData({
    required this.totalCount,
    required this.totalAmountMinor,
    required this.paidCount,
    required this.overdueCount,
  });
}

final invoicesSummaryProvider = Provider.autoDispose<InvoicesSummaryData>((ref) {
  final invoices = ref.watch(allInvoicesStreamProvider).value ?? [];
  int totalMinor = 0;
  int paid = 0;
  int overdue = 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final inv in invoices) {
    if (inv.status != InvoiceStatus.cancelled) {
      totalMinor += inv.totalMinor;
    }
    if (inv.status == InvoiceStatus.paid) {
      paid++;
    }
    final isOverdue = (inv.status == InvoiceStatus.overdue) ||
        ((inv.status == InvoiceStatus.sent || inv.status == InvoiceStatus.partiallyPaid) &&
            inv.dueDate != null &&
            inv.dueDate!.isBefore(today));
    if (isOverdue) {
      overdue++;
    }
  }

  return InvoicesSummaryData(
    totalCount: invoices.length,
    totalAmountMinor: totalMinor,
    paidCount: paid,
    overdueCount: overdue,
  );
});

// Phase 2 & Phase 5: Filtered & Sorted Invoices Provider
final filteredInvoicesProvider = Provider.autoDispose<AsyncValue<List<Invoice>>>((ref) {
  final invoicesAsync = ref.watch(invoicesListProvider);
  final searchQuery = ref.watch(invoiceSearchProvider).trim().toLowerCase();
  final sortOption = ref.watch(invoiceSortProvider);
  final dateFilter = ref.watch(invoiceDateFilterProvider);
  final clientsMap = ref.watch(clientsMapProvider).value ?? {};

  return invoicesAsync.whenData((invoices) {
    var result = invoices.toList();

    // 1. Search Filter (invoice number & client name)
    if (searchQuery.isNotEmpty) {
      result = result.where((inv) {
        final numberMatches = inv.number.toLowerCase().contains(searchQuery);
        final clientName = clientsMap[inv.clientId]?.toLowerCase() ?? '';
        final clientMatches = clientName.contains(searchQuery);
        return numberMatches || clientMatches;
      }).toList();
    }

    // 2. Date Range Filter
    if (dateFilter.option != InvoiceDateFilterOption.all) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime? start;
      DateTime? end;

      switch (dateFilter.option) {
        case InvoiceDateFilterOption.all:
          break;
        case InvoiceDateFilterOption.today:
          start = today;
          end = today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          break;
        case InvoiceDateFilterOption.thisWeek:
          final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
          start = startOfWeek;
          end = startOfWeek.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          break;
        case InvoiceDateFilterOption.thisMonth:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case InvoiceDateFilterOption.lastMonth:
          start = DateTime(now.year, now.month - 1, 1);
          end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
          break;
        case InvoiceDateFilterOption.custom:
          if (dateFilter.customRange != null) {
            start = DateTime(
              dateFilter.customRange!.start.year,
              dateFilter.customRange!.start.month,
              dateFilter.customRange!.start.day,
            );
            end = DateTime(
              dateFilter.customRange!.end.year,
              dateFilter.customRange!.end.month,
              dateFilter.customRange!.end.day,
              23,
              59,
              59,
              999,
            );
          }
          break;
      }

      if (start != null && end != null) {
        result = result.where((inv) {
          return !inv.issueDate.isBefore(start!) && !inv.issueDate.isAfter(end!);
        }).toList();
      }
    }

    // 3. Sorting
    switch (sortOption) {
      case InvoiceSortOption.dateDesc:
        result.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        break;
      case InvoiceSortOption.dateAsc:
        result.sort((a, b) => a.issueDate.compareTo(b.issueDate));
        break;
      case InvoiceSortOption.amountDesc:
        result.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
        break;
      case InvoiceSortOption.amountAsc:
        result.sort((a, b) => a.totalMinor.compareTo(b.totalMinor));
        break;
      case InvoiceSortOption.dueDateAsc:
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
    }

    return result;
  });
});
