import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/invoices/application/invoice_pdf_service.dart';
import 'package:fawatir/features/payments/application/payment_providers.dart';
import 'package:fawatir/features/payments/application/receipt_pdf_service.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/shared/pdf/invoice_pdf.dart';
import 'package:fawatir/shared/pdf/receipt_pdf.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

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
    final invoiceAsync = ref.watch(invoiceByIdProvider(invoiceId));
    final itemsAsync = ref.watch(invoiceItemsProvider(invoiceId));
    final remainingAsync = ref.watch(invoiceRemainingProvider(invoiceId));
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoiceId));

    final invoice = invoiceAsync.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الفاتورة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'مشاركة PDF',
              onPressed: () => _sharePdf(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'معاينة PDF',
              onPressed: () => _previewPdf(context, ref),
            ),
            if (invoice != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'خيارات الفاتورة',
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push('/invoices/${invoice.id}/edit');
                  } else if (value == 'send') {
                    await _changeInvoiceStatus(
                      context,
                      ref,
                      invoice.id,
                      invoice.clientId,
                      InvoiceStatus.sent,
                      'تم اعتماد الفاتورة وتحويلها إلى مرسلة',
                    );
                  } else if (value == 'cancel') {
                    final confirmed = await _confirmCancelInvoice(context);
                    if (confirmed == true && context.mounted) {
                      await _changeInvoiceStatus(
                        context,
                        ref,
                        invoice.id,
                        invoice.clientId,
                        InvoiceStatus.cancelled,
                        'تم إلغاء الفاتورة بنجاح',
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  if (invoice.status == InvoiceStatus.draft) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.accent, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل الفاتورة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'send',
                      child: Row(
                        children: [
                          Icon(Icons.send, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('اعتماد وإرسال الفاتورة'),
                        ],
                      ),
                    ),
                  ],
                  if (invoice.status != InvoiceStatus.cancelled &&
                      invoice.status != InvoiceStatus.paid)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('إلغاء الفاتورة'),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: invoiceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('خطأ في تحميل الفاتورة: $err', style: const TextStyle(color: Colors.red)),
          ),
          data: (invoice) {
            if (invoice == null) {
              return const Center(
                child: Text('الفاتورة غير موجودة', style: TextStyle(fontSize: 18, color: AppColors.muted)),
              );
            }

            final clientAsync = ref.watch(clientByIdProvider(invoice.clientId));

            return clientAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('خطأ في تحميل بيانات العميل: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (client) {
                final clientName = client?.name ?? 'عميل غير معروف';
                final isOverdueValue = isInvoiceOverdue(invoice);
                final statusColor = _getStatusColor(invoice.status);
                final showFxRate = client != null && invoice.currency != client.accountCurrency;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Status and Overview Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    invoice.number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _getStatusLabel(invoice.status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isOverdueValue) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'متأخرة',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildInfoRow('العميل:', clientName),
                              const SizedBox(height: 8),
                              _buildInfoRow('تاريخ الإصدار:', _formatDate(invoice.issueDate)),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'تاريخ الاستحقاق:',
                                invoice.dueDate != null ? _formatDate(invoice.dueDate!) : 'غير محدد',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('العملة:', '${invoice.currency} (${symbolFor(invoice.currency)})'),
                              if (showFxRate) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'سعر الصرف لعملة الحساب:',
                                  '1 ${invoice.currency} = ${invoice.fxRateToAccount} ${client.accountCurrency}',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Items Section Title
                      const Text(
                        'بنود الفاتورة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                      const SizedBox(height: 10),

                      // Items Table Card
                      itemsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text('خطأ في تحميل البنود: $err', style: const TextStyle(color: Colors.red)),
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('لا توجد بنود في هذه الفاتورة')),
                              ),
                            );
                          }

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(4), // Description
                                  1: FlexColumnWidth(1.5), // Qty
                                  2: FlexColumnWidth(2.5), // Unit Price
                                  3: FlexColumnWidth(2.5), // Line Total
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: AppColors.line, width: 1.5)),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'البند',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted.withValues(alpha: 0.8), fontSize: 13),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'الكمية',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted.withValues(alpha: 0.8), fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'سعر الوحدة',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted.withValues(alpha: 0.8), fontSize: 13),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'المجموع',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted.withValues(alpha: 0.8), fontSize: 13),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...items.map((item) {
                                    return TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: AppColors.line, width: 0.5)),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          child: Text(
                                            item.description,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          child: Text(
                                            item.quantity.toString(),
                                            style: const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          child: Text(
                                            formatMoney(item.unitPriceMinor, invoice.currency),
                                            style: const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                                          child: Text(
                                            formatMoney(item.lineTotalMinor, invoice.currency),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Grand Total & Remaining Card
                      Card(
                        color: AppColors.accent.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'إجمالي الفاتورة:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                  Text(
                                    formatMoney(invoice.totalMinor, invoice.currency),
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ],
                              ),
                              remainingAsync.maybeWhen(
                                data: (remaining) {
                                  if (remaining < invoice.totalMinor) {
                                    final paid = invoice.totalMinor - remaining;
                                    return Column(
                                      children: [
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'المسدد:',
                                              style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              formatMoney(paid, invoice.currency),
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'المتبقي:',
                                              style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              formatMoney(remaining, invoice.currency),
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Notes
                      if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
                        const Text(
                          'ملاحظات:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            invoice.notes!,
                            style: const TextStyle(fontSize: 14, color: AppColors.dark),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Recorded Payments Section
                      paymentsAsync.maybeWhen(
                        data: (payments) {
                          if (payments.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'التحصيلات المسجلة',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                              const SizedBox(height: 8),
                              ...payments.map((p) {
                                final pDate =
                                    '${p.paymentDate.year}/${p.paymentDate.month.toString().padLeft(2, '0')}/${p.paymentDate.day.toString().padLeft(2, '0')}';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: AppColors.line.withValues(alpha: 0.6)),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Color(0xFFE8F5E9),
                                      child: Icon(Icons.check,
                                          color: Colors.green, size: 16),
                                    ),
                                    title: Text(
                                      formatMoney(p.amountMinor, p.currency),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '${p.method ?? 'دفعة'} • $pDate',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.muted),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (p.notes != null &&
                                            p.notes!.trim().isNotEmpty)
                                          Tooltip(
                                            message: p.notes!,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4.0),
                                              child: Icon(Icons.info_outline,
                                                  size: 18,
                                                  color: AppColors.muted),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.receipt_long,
                                              color: AppColors.accent,
                                              size: 20),
                                          tooltip: 'إصدار سند قبض',
                                          onPressed: () => _shareReceipt(
                                              context, ref, p.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      // Actions Section
                      const Text(
                        'الإجراءات',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text('مشاركة الفاتورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: () => _sharePdf(context, ref),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.print),
                              label: const Text('معاينة وطباعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: () => _previewPdf(context, ref),
                            ),
                          ),
                        ],
                      ),
                      if (invoice.status == InvoiceStatus.draft) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(color: AppColors.accent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('تعديل الفاتورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                onPressed: () => context.push('/invoices/${invoice.id}/edit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.verified),
                                label: const Text('اعتماد وإرسال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                onPressed: () => _changeInvoiceStatus(
                                  context,
                                  ref,
                                  invoice.id,
                                  invoice.clientId,
                                  InvoiceStatus.sent,
                                  'تم اعتماد الفاتورة وتحويلها إلى مرسلة',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (invoice.status != InvoiceStatus.draft &&
                          invoice.status != InvoiceStatus.cancelled &&
                          invoice.status != InvoiceStatus.paid) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add_card),
                            label: const Text('تسجيل تحصيل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            onPressed: () => context.push('/invoices/${invoice.id}/pay'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sharePdf(BuildContext context, WidgetRef ref) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ref.read(invoicePdfServiceProvider)(invoiceId);
      final bytes = await buildInvoicePdf(data);
      nav.pop();
      await shareInvoicePdf(bytes, data.number);
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء مشاركة الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _previewPdf(BuildContext context, WidgetRef ref) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ref.read(invoicePdfServiceProvider)(invoiceId);
      final bytes = await buildInvoicePdf(data);
      nav.pop();
      await previewInvoicePdf(bytes);
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء معاينة الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareReceipt(BuildContext context, WidgetRef ref, int paymentId) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ref.read(receiptPdfServiceProvider)(paymentId);
      final bytes = await buildReceiptPdf(data);
      nav.pop();
      await shareReceiptPdf(bytes, data.receiptNumber);
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء مشاركة سند القبض: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeInvoiceStatus(
    BuildContext context,
    WidgetRef ref,
    int id,
    int clientId,
    InvoiceStatus newStatus,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(invoiceRepositoryProvider).updateInvoiceStatus(id, newStatus);
      ref.invalidate(invoiceByIdProvider(id));
      ref.invalidate(invoiceRemainingProvider(id));
      ref.invalidate(invoicesListProvider);
      ref.invalidate(clientInvoicesProvider(clientId));
      ref.invalidate(clientBalanceProvider(clientId));
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء تحديث حالة الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _confirmCancelInvoice(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد إلغاء الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في إلغاء هذه الفاتورة؟ لن يتم احتسابها ضمن مديونية العميل بعد الإلغاء.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، إلغاء الفاتورة'),
            ),
          ],
        ),
      ),
    );
  }
}
