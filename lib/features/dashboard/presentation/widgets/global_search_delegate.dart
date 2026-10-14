import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart' show getEffectiveInvoiceStatus;

class SearchResultData {
  final List<Client> clients;
  final List<InvoiceWithClientName> invoices;

  const SearchResultData({
    required this.clients,
    required this.invoices,
  });
}

class InvoiceWithClientName {
  final Invoice invoice;
  final String clientName;

  const InvoiceWithClientName({
    required this.invoice,
    required this.clientName,
  });
}

class AppGlobalSearchDelegate extends SearchDelegate<void> {
  final WidgetRef ref;

  AppGlobalSearchDelegate({required this.ref})
      : super(
          searchFieldLabel: 'ابحث عن عميل أو رقم فاتورة...',
          searchFieldStyle: const TextStyle(
            fontSize: 16,
            color: AppColors.dark,
          ),
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.accent),
        titleTextStyle: const TextStyle(
          color: AppColors.dark,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.muted, fontSize: 15),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: 'مسح',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_forward_rounded),
      tooltip: 'رجوع',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildSearchHints(context);
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchHints(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'البحث الشامل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'ابحث بسهولة عن أي عميل برقم هاتفه أو اسمه،\nأو اعثر على أي فاتورة برقمها.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'أمثلة سريعة للبحث:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(context, 'INV-', Icons.receipt_long_outlined),
              _buildSuggestionChip(context, 'شركة', Icons.business_outlined),
              _buildSuggestionChip(context, '05', Icons.phone_outlined),
              _buildSuggestionChip(context, '77', Icons.phone_android_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String text, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(text),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.dark),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () {
        query = text;
        showResults(context);
      },
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final clean = query.trim();
    if (clean.isEmpty) {
      return _buildSearchHints(context);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<SearchResultData>(
        future: _performSearch(clean),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء البحث: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data;
          final clients = data?.clients ?? [];
          final invoices = data?.invoices ?? [];

          if (clients.isEmpty && invoices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد نتائج تطابق "$clean"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تأكد من صحة الاسم أو رقم الهاتف أو رقم الفاتورة المدخل',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (clients.isNotEmpty) ...[
                _buildSectionHeader('العملاء (${clients.length})', Icons.people_outline_rounded),
                const SizedBox(height: 8),
                ...clients.map((c) => _buildClientTile(context, c)),
                const SizedBox(height: 16),
              ],
              if (invoices.isNotEmpty) ...[
                _buildSectionHeader('الفواتير (${invoices.length})', Icons.receipt_long_outlined),
                const SizedBox(height: 8),
                ...invoices.map((inv) => _buildInvoiceTile(context, inv)),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildClientTile(BuildContext context, Client client) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
          child: Text(
            client.name.isNotEmpty ? client.name.substring(0, 1) : 'ع',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          client.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            if (client.phone != null && client.phone!.isNotEmpty) ...[
              const Icon(Icons.phone, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                client.phone!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                client.accountCurrency,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.muted),
        onTap: () {
          close(context, null);
          context.push('/clients/${client.id}');
        },
      ),
    );
  }

  Widget _buildInvoiceTile(BuildContext context, InvoiceWithClientName item) {
    final inv = item.invoice;
    final effectiveStatus = getEffectiveInvoiceStatus(inv);
    final statusColor = _getStatusColor(effectiveStatus);
    final statusLabel = _getStatusLabel(effectiveStatus);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              inv.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.clientName,
                  style: const TextStyle(fontSize: 13, color: AppColors.dark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatMoney(inv.totalMinor, inv.currency),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.muted),
        onTap: () {
          close(context, null);
          context.push('/invoices/${inv.id}');
        },
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return const Color(0xFF6B7280);
      case InvoiceStatus.sent:
        return const Color(0xFF2563EB);
      case InvoiceStatus.paid:
        return const Color(0xFF059669);
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFD97706);
      case InvoiceStatus.overdue:
        return const Color(0xFFDC2626);
      case InvoiceStatus.cancelled:
        return const Color(0xFF4B5563);
    }
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'مسودة';
      case InvoiceStatus.sent:
        return 'مرسلة';
      case InvoiceStatus.paid:
        return 'مدفوعة';
      case InvoiceStatus.partiallyPaid:
        return 'مدفوعة جزئياً';
      case InvoiceStatus.overdue:
        return 'متأخرة';
      case InvoiceStatus.cancelled:
        return 'ملغاة';
    }
  }

  Future<SearchResultData> _performSearch(String query) async {
    final db = ref.read(databaseProvider);

    // 1. Search clients by name, phone, contactPerson, notes
    final clientsQuery = db.select(db.clients)
      ..where((tbl) =>
          tbl.name.contains(query) |
          tbl.phone.contains(query) |
          tbl.contactPerson.contains(query) |
          tbl.notes.contains(query))
      ..limit(15);
    final clients = await clientsQuery.get();

    // 2. Search invoices by invoice number, notes
    final matchingClientIds = clients.map((c) => c.id).toList();

    drift.Expression<bool> invoicePredicate = db.invoices.number.contains(query) | db.invoices.notes.contains(query);
    if (matchingClientIds.isNotEmpty) {
      invoicePredicate = invoicePredicate | db.invoices.clientId.isIn(matchingClientIds);
    }

    final invoicesQuery = db.select(db.invoices)
      ..where((tbl) => invoicePredicate)
      ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.issueDate, mode: drift.OrderingMode.desc)])
      ..limit(20);
    final invoices = await invoicesQuery.get();

    // Load client names for all found invoices
    final clientIdsToFetch = invoices.map((inv) => inv.clientId).toSet();
    final clientMap = <int, String>{};
    for (final c in clients) {
      clientMap[c.id] = c.name;
    }
    final missingIds = clientIdsToFetch.difference(clientMap.keys.toSet());
    if (missingIds.isNotEmpty) {
      final extraClients = await (db.select(db.clients)..where((tbl) => tbl.id.isIn(missingIds))).get();
      for (final ec in extraClients) {
        clientMap[ec.id] = ec.name;
      }
    }

    final invoicesWithClients = invoices.map((inv) {
      return InvoiceWithClientName(
        invoice: inv,
        clientName: clientMap[inv.clientId] ?? 'عميل #${inv.clientId}',
      );
    }).toList();

    return SearchResultData(
      clients: clients,
      invoices: invoicesWithClients,
    );
  }
}
