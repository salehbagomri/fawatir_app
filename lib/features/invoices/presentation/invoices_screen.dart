import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/shared/widgets/empty_state.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  Future<void> _generateInvoices(BuildContext context, WidgetRef ref) async {
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

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.partiallyPaid:
        return Colors.orange;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey.shade600;
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(invoiceStatusFilterProvider);
    final invoicesAsync = ref.watch(invoicesListProvider);
    final clientsMapAsync = ref.watch(clientsMapProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير'),
          actions: [
            IconButton(
              icon: const Icon(Icons.autorenew),
              tooltip: 'توليد فواتير الشهر',
              onPressed: () => _generateInvoices(context, ref),
            ),
          ],
        ),
        body: Column(
          children: [
            // Status Filter Bar
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _buildFilterChip(
                    context: context,
                    ref: ref,
                    label: 'الكل',
                    status: null,
                    isSelected: currentFilter == null,
                  ),
                  ...InvoiceStatus.values.map((status) {
                    return _buildFilterChip(
                      context: context,
                      ref: ref,
                      label: _getStatusLabel(status),
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
              child: invoicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('خطأ في تحميل البيانات: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (invoices) {
                  if (invoices.isEmpty) {
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
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text('خطأ في تحميل العملاء: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    data: (clientsMap) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          final clientName = clientsMap[invoice.clientId] ?? 'عميل غير معروف';
                          final isOverdueValue = isInvoiceOverdue(invoice);
                          final statusColor = _getStatusColor(invoice.status);

                          return Card(
                            elevation: 0.8,
                            margin: const EdgeInsets.only(bottom: 10),
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
                                    const SizedBox(height: 12),
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
                                            _getStatusLabel(invoice.status),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (isOverdueValue)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.red.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'متأخرة عن موعدها',
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
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
    required WidgetRef ref,
    required String label,
    required InvoiceStatus? status,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
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
