import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/features/payments/application/payment_providers.dart';
import 'package:fawatir/core/invoice_status_utils.dart';
import 'package:fawatir/core/date_utils.dart';
import 'package:fawatir/shared/widgets/empty_state.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateInvoices(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'توليد فواتير الشهر',
      message: 'هل تريد فحص كافة الاشتراكات وتوليد فواتير مسودة جديدة للاشتراكات المستحقة لهذا الشهر؟ لن يتم تكرار أي فواتير تم توليدها مسبقاً لنفس الشهر.',
      confirmLabel: 'بدء التوليد',
      cancelLabel: 'إلغاء',
      icon: Icons.autorenew,
    );
    if (confirmed != true || !context.mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final createdIds = await repo.generateMonthlyInvoices();
      nav.pop();

      if (createdIds.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('لا توجد اشتراكات مستحقة لتوليد فواتير جديدة لها هذا الشهر'),
            backgroundColor: AppColors.accent,
          ),
        );
      } else {
        ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.draft);
        if (context.mounted) {
          context.push('/invoices/drafts-review', extra: createdIds);
        }
      }
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء توليد الفواتير: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSortBottomSheet(BuildContext context) {
    final currentSort = ref.read(invoiceSortProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'ترتيب الفواتير حسب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                ...InvoiceSortOption.values.map((option) {
                  final isSelected = currentSort == option;
                  return ListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.accent : AppColors.dark,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () {
                      ref.read(invoiceSortProvider.notifier).setSort(option);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDateFilterBottomSheet(BuildContext context) {
    final currentFilter = ref.read(invoiceDateFilterProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'تصفية الفواتير حسب الفترة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...InvoiceDateFilterOption.values.map((opt) {
                  final isSelected = currentFilter.option == opt;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.accent : Colors.grey,
                    ),
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.accent : null,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (opt == InvoiceDateFilterOption.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          initialDateRange: currentFilter.customRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 30)),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          ref.read(invoiceDateFilterProvider.notifier).setFilter(opt, picked);
                        }
                      } else {
                        ref.read(invoiceDateFilterProvider.notifier).setFilter(opt);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthYearLabel(DateTime date) {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${months[date.month]} ${date.year}';
  }

  Widget _buildDueDateBadge(Invoice invoice, InvoiceStatus effectiveStatus) {
    if (invoice.dueDate == null ||
        effectiveStatus == InvoiceStatus.paid ||
        effectiveStatus == InvoiceStatus.cancelled) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(invoice.dueDate!.year, invoice.dueDate!.month, invoice.dueDate!.day);
    final diffDays = due.difference(today).inDays;

    String text;
    Color color;
    Color bgColor;
    IconData icon;

    if (diffDays < 0) {
      text = 'متأخرة بـ ${diffDays.abs()} يوم';
      color = Colors.red.shade700;
      bgColor = Colors.red.shade50;
      icon = Icons.error_outline_rounded;
    } else if (diffDays == 0) {
      text = 'مستحقة اليوم';
      color = Colors.amber.shade900;
      bgColor = Colors.amber.shade50;
      icon = Icons.access_time_rounded;
    } else if (diffDays == 1) {
      text = 'مستحقة غداً';
      color = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      icon = Icons.event_rounded;
    } else if (diffDays <= 7) {
      text = 'مستحقة خلال $diffDays أيام';
      color = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      icon = Icons.event_rounded;
    } else {
      text = 'الاستحقاق: ${formatDate(invoice.dueDate!)}';
      color = AppColors.muted;
      bgColor = AppColors.line.withValues(alpha: 0.3);
      icon = Icons.event_note_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _InvoiceCardShimmer(),
    );
  }

  Color _getStatusColor(InvoiceStatus status) => invoiceStatusColor(status);
  String _getStatusLabel(InvoiceStatus status) => invoiceStatusLabel(status);
  String _formatDate(DateTime date) => formatDate(date);

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(invoiceStatusFilterProvider);
    final filteredInvoicesAsync = ref.watch(filteredInvoicesProvider);
    final clientsMapAsync = ref.watch(clientsMapProvider);
    final searchQuery = ref.watch(invoiceSearchProvider);
    final counts = ref.watch(invoiceCountsProvider);
    final summary = ref.watch(invoicesSummaryProvider);
    final dateFilter = ref.watch(invoiceDateFilterProvider);
    final sortOption = ref.watch(invoiceSortProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير'),
          actions: [
            IconButton(
              icon: Icon(
                dateFilter.option != InvoiceDateFilterOption.all
                    ? Icons.calendar_month
                    : Icons.calendar_month_outlined,
                color: dateFilter.option != InvoiceDateFilterOption.all
                    ? AppColors.accent
                    : null,
              ),
              tooltip: 'تصفية حسب الفترة',
              onPressed: () => _showDateFilterBottomSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'ترتيب الفواتير',
              onPressed: () => _showSortBottomSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.autorenew),
              tooltip: 'توليد فواتير الشهر',
              onPressed: () => _generateInvoices(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextFormField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(invoiceSearchProvider.notifier).setQuery(val);
                },
                decoration: InputDecoration(
                  hintText: 'البحث برقم الفاتورة أو اسم العميل...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(invoiceSearchProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),

            // Financial Summary Cards (T2.3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'إجمالي الفواتير',
                      value: '${summary.totalCount}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.accent,
                      onTap: () {
                        ref.read(invoiceStatusFilterProvider.notifier).setFilter(null);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'مدفوعة',
                      value: '${summary.paidCount}',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green.shade700,
                      onTap: () {
                        ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.paid);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: 'متأخرة',
                      value: '${summary.overdueCount}',
                      icon: Icons.warning_amber_rounded,
                      color: summary.overdueCount > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                      onTap: () {
                        ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.overdue);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Active Date Filter Indicator Banner
            if (dateFilter.option != InvoiceDateFilterOption.all)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            dateFilter.option == InvoiceDateFilterOption.custom && dateFilter.customRange != null
                                ? 'الفترة: ${_formatDate(dateFilter.customRange!.start)} - ${_formatDate(dateFilter.customRange!.end)}'
                                : 'الفترة: ${dateFilter.option.label}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => ref.read(invoiceDateFilterProvider.notifier).reset(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Status Filter Bar with Counters (T2.2)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildFilterChip(
                    context: context,
                    label: 'الكل',
                    count: counts[null] ?? 0,
                    status: null,
                    isSelected: currentFilter == null,
                  ),
                  ...InvoiceStatus.values.map((status) {
                    return _buildFilterChip(
                      context: context,
                      label: _getStatusLabel(status),
                      count: counts[status] ?? 0,
                      status: status,
                      isSelected: currentFilter == status,
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),

            // Invoices List
            Expanded(
              child: filteredInvoicesAsync.when(
                loading: () => _buildInvoiceShimmerList(),
                error: (err, stack) => Center(
                  child: Text('خطأ في تحميل البيانات: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (invoices) {
                  if (invoices.isEmpty) {
                    if (searchQuery.trim().isNotEmpty) {
                      return EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'لا توجد فواتير مطابقة',
                        subtitle: 'لم نتمكن من العثور على أي فاتورة تطابق "$searchQuery"',
                        actionLabel: 'مسح البحث',
                        actionIcon: Icons.clear,
                        onAction: () {
                          _searchController.clear();
                          ref.read(invoiceSearchProvider.notifier).setQuery('');
                        },
                      );
                    }
                    if (dateFilter.option != InvoiceDateFilterOption.all) {
                      return EmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'لا توجد فواتير في هذه الفترة',
                        subtitle: 'لم يتم العثور على أي فواتير مسجلة خلال الفترة المحددة',
                        actionLabel: 'إعادة تعيين الفترة',
                        actionIcon: Icons.calendar_today_rounded,
                        onAction: () {
                          ref.read(invoiceDateFilterProvider.notifier).reset();
                        },
                      );
                    }
                    if (currentFilter != null) {
                      return EmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        title: 'لا توجد فواتير بحالة "${_getStatusLabel(currentFilter)}"',
                        subtitle: 'لم يتم العثور على فواتير مطابقة لهذا التصنيف',
                        actionLabel: 'عرض كل الفواتير',
                        actionIcon: Icons.list_alt,
                        onAction: () {
                          ref.read(invoiceStatusFilterProvider.notifier).setFilter(null);
                        },
                      );
                    }
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'لا توجد فواتير بعد',
                      subtitle: 'أنشئ أول فاتورة لعميلك بسهولة وبنود مفصلة مع دعم العملات المختلفة',
                      actionLabel: 'إنشاء فاتورة جديدة',
                      actionIcon: Icons.add,
                      onAction: () {
                        context.go('/invoices/new');
                      },
                    );
                  }

                  return clientsMapAsync.when(
                    loading: () => _buildInvoiceShimmerList(),
                    error: (err, stack) => Center(
                      child: Text('خطأ في تحميل العملاء: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    data: (clientsMap) {
                      final isDateSorting = sortOption == InvoiceSortOption.dateDesc || sortOption == InvoiceSortOption.dateAsc;

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          final clientName = clientsMap[invoice.clientId] ?? 'عميل غير معروف';
                          final effectiveStatus = getEffectiveInvoiceStatus(invoice);
                          final isOverdueValue = isInvoiceOverdue(invoice);
                          final statusColor = _getStatusColor(effectiveStatus);

                          final cardContent = Dismissible(
                            key: ValueKey('invoice_swipe_${invoice.id}'),
                            direction: DismissDirection.horizontal,
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // سحب لليسار: تسجيل تحصيل
                                if (invoice.status == InvoiceStatus.paid || invoice.status == InvoiceStatus.cancelled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('الفاتورة لا تقبل تسجيل تحصيل (مدفوعة أو ملغاة)'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return false;
                                }
                                context.push('/payments/record', extra: {'invoiceId': invoice.id});
                                return false;
                              } else if (direction == DismissDirection.startToEnd) {
                                // سحب لليمين: معاينة PDF
                                context.push('/invoices/${invoice.id}/pdf');
                                return false;
                              }
                              return false;
                            },
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerRight,
                              child: const Row(
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'معاينة PDF',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerLeft,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'تسجيل تحصيل',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.payments_rounded, color: Colors.white),
                                ],
                              ),
                            ),
                            child: Card(
                              elevation: 0.8,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isOverdueValue
                                      ? Colors.red.shade200
                                      : AppColors.line.withValues(alpha: 0.6),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  context.go('/invoices/${invoice.id}');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.receipt_rounded,
                                                  size: 18,
                                                  color: statusColor,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                invoice.number,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            formatMoney(invoice.totalMinor, invoice.currency),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 15, color: AppColors.muted),
                                              const SizedBox(width: 4),
                                              Text(
                                                clientName,
                                                style: const TextStyle(
                                                  color: AppColors.dark,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.muted),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDate(invoice.issueDate),
                                                style: const TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              _getStatusLabel(effectiveStatus),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          _buildDueDateBadge(invoice, effectiveStatus),
                                        ],
                                      ),

                                      // Mini Payment Progress Bar (T5.1)
                                      Consumer(
                                        builder: (context, ref, child) {
                                          if (effectiveStatus == InvoiceStatus.draft ||
                                              effectiveStatus == InvoiceStatus.cancelled) {
                                            return const SizedBox.shrink();
                                          }
                                          final remainingAsync = ref.watch(invoiceRemainingProvider(invoice.id));
                                          final remaining = remainingAsync.value ?? invoice.totalMinor;
                                          final paid = (invoice.totalMinor - remaining).clamp(0, invoice.totalMinor);
                                          final ratio = invoice.totalMinor > 0 ? (paid / invoice.totalMinor).clamp(0.0, 1.0) : 0.0;
                                          final percent = (ratio * 100).toInt();

                                          if (paid <= 0 && effectiveStatus != InvoiceStatus.partiallyPaid) {
                                            return const SizedBox.shrink();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Column(
                                              children: [
                                                const Divider(height: 12),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          ratio >= 1.0 ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                                                          size: 13,
                                                          color: ratio >= 1.0 ? Colors.green.shade700 : Colors.orange.shade700,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          ratio >= 1.0
                                                              ? 'مسددة بالكامل (100%)'
                                                              : 'مسدد $percent% (${formatMoney(paid, invoice.currency)})',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: ratio >= 1.0 ? Colors.green.shade700 : Colors.orange.shade800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (remaining > 0)
                                                      Text(
                                                        'متبقي: ${formatMoney(remaining, invoice.currency)}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: LinearProgressIndicator(
                                                    value: ratio,
                                                    minHeight: 4,
                                                    backgroundColor: Colors.grey.shade200,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      ratio >= 1.0 ? Colors.green : Colors.orange.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                          // Monthly Grouping Header (T5.3)
                          if (isDateSorting) {
                            final showHeader = index == 0 ||
                                (invoices[index - 1].issueDate.year != invoice.issueDate.year ||
                                 invoices[index - 1].issueDate.month != invoice.issueDate.month);

                            if (showHeader) {
                              final monthInvoices = invoices.where((inv) =>
                                  inv.issueDate.year == invoice.issueDate.year &&
                                  inv.issueDate.month == invoice.issueDate.month);
                              final monthCount = monthInvoices.length;
                              final monthTotalMinor = monthInvoices.fold<int>(0, (sum, inv) => sum + inv.totalMinor);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 8, 4, 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.accent),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getMonthYearLabel(invoice.issueDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.accent.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$monthCount ${monthCount == 1 ? 'فاتورة' : (monthCount == 2 ? 'فاتورتان' : 'فواتير')}',
                                                style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          formatMoney(monthTotalMinor, invoice.currency),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.dark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  cardContent,
                                ],
                              );
                            }
                          }

                          return cardContent;
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.post_add_rounded),
          label: const Text(
            'فاتورة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            context.go('/invoices/new');
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required int count,
    required InvoiceStatus? status,
    required bool isSelected,
  }) {
    final title = '$label ($count)';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(title),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            ref.read(invoiceStatusFilterProvider.notifier).setFilter(status);
          }
        },
        selectedColor: AppColors.accent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.dark,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        showCheckmark: false,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceCardShimmer extends StatefulWidget {
  const _InvoiceCardShimmer();

  @override
  State<_InvoiceCardShimmer> createState() => _InvoiceCardShimmerState();
}

class _InvoiceCardShimmerState extends State<_InvoiceCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.35 + (_controller.value * 0.45);
        final baseColor = Colors.grey.shade300.withValues(alpha: opacity);

        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.line.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 110,
                          height: 16,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 75,
                      height: 18,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 70,
                  height: 20,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
