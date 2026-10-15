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
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/shared/pdf/invoice_pdf.dart';
import 'package:fawatir/shared/pdf/receipt_pdf.dart';
import 'package:fawatir/shared/widgets/app_snackbar.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';
import 'package:fawatir/core/invoice_status_utils.dart';
import 'package:fawatir/core/date_utils.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  Color _getStatusColor(InvoiceStatus status) => invoiceStatusColor(status);
  String _getStatusLabel(InvoiceStatus status) => invoiceStatusLabel(status);
  String _formatDate(DateTime date) => formatDate(date);

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
                  } else if (value == 'revert_to_draft') {
                    await _handleRevertToDraft(context, ref, invoice);
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
                    // التحقق من وجود دفعات مسجلة على الفاتورة قبل الإلغاء
                    final payments = await (ref.read(databaseProvider).select(ref.read(databaseProvider).payments)
                          ..where((p) => p.invoiceId.equals(invoice.id)))
                        .get();

                    if (payments.isNotEmpty) {
                      final totalPaid = payments.fold<int>(0, (s, p) => s + p.amountMinor);
                      if (context.mounted) {
                        await showDialog(
                          context: context,
                          builder: (ctx) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('تعذّر إلغاء الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                ],
                              ),
                              content: Text(
                                'توجد ${payments.length} دفعات محصلة مسجلة على هذه الفاتورة بإجمالي ${formatMoney(totalPaid, invoice.currency)}.\n\nلحماية سلامة الحسابات والسجلات المالية، لا يمكن إلغاء فاتورة تم سداد جزء منها أو بالكامل دون تسوية الدفعات المرتبطة بها أولاً.',
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('حسناً، فهمت'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    if (!context.mounted) return;
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
                  } else if (value == 'duplicate') {
                    context.push('/invoices/new', extra: invoice.id);
                  } else if (value == 'delete') {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'حذف الفاتورة المسودة',
                      message: 'هل أنت متأكد من رغبتك في حذف هذه الفاتورة المسودة نهائياً؟ لن يمكن استرجاع هذه الفاتورة أو بنودها بعد الحذف.',
                      confirmLabel: 'نعم، حذف نهائي',
                      cancelLabel: 'تراجع',
                      isDestructive: true,
                      icon: Icons.delete_forever_rounded,
                    );
                    if (confirmed == true && context.mounted) {
                      final repo = ref.read(invoiceRepositoryProvider);
                      await repo.deleteInvoice(invoice.id);
                      ref.invalidate(invoicesListProvider);
                      ref.invalidate(clientInvoicesProvider(invoice.clientId));
                      ref.invalidate(clientBalanceProvider(invoice.clientId));
                      if (context.mounted) {
                        AppSnackBar.showSuccess(context, 'تم حذف الفاتورة المسودة بنجاح');
                        context.go('/invoices');
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, color: AppColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text('نسخ الفاتورة (فاتورة جديدة)'),
                      ],
                    ),
                  ),
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('حذف المسودة نهائياً', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  if (invoice.status != InvoiceStatus.draft &&
                      invoice.status != InvoiceStatus.cancelled)
                    const PopupMenuItem(
                      value: 'revert_to_draft',
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('إعادة إلى مسودة للتعديل'),
                        ],
                      ),
                    ),
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
                final effectiveStatus = getEffectiveInvoiceStatus(invoice);
                final isOverdueValue = isInvoiceOverdue(invoice);
                final statusColor = _getStatusColor(effectiveStatus);
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
                                          _getStatusLabel(effectiveStatus),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isOverdueValue && effectiveStatus != InvoiceStatus.overdue) ...[
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
                              _buildInfoRow('تاريخ الإنشاء في النظام:', formatDateTime(invoice.createdAt)),
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
                              if (invoice.discountMinor > 0 || invoice.taxMinor > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('المجموع الفرعي:', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                    Text(
                                      formatMoney(
                                        (invoice.totalMinor - invoice.taxMinor + invoice.discountMinor),
                                        invoice.currency,
                                      ),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                if (invoice.discountMinor > 0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        invoice.discountPercent > 0
                                            ? 'الخصم (${invoice.discountPercent.toStringAsFixed(invoice.discountPercent.truncateToDouble() == invoice.discountPercent ? 0 : 1)}%):'
                                            : 'الخصم:',
                                        style: const TextStyle(fontSize: 14, color: Colors.red),
                                      ),
                                      Text(
                                        '- ${formatMoney(invoice.discountMinor, invoice.currency)}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ],
                                if (invoice.taxMinor > 0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        invoice.taxPercent > 0
                                            ? 'الضريبة (${invoice.taxPercent.toStringAsFixed(invoice.taxPercent.truncateToDouble() == invoice.taxPercent ? 0 : 1)}%):'
                                            : 'الضريبة:',
                                        style: const TextStyle(fontSize: 14, color: AppColors.muted),
                                      ),
                                      Text(
                                        '+ ${formatMoney(invoice.taxMinor, invoice.currency)}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 16),
                              ],
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
                                  final paid = (invoice.totalMinor - remaining).clamp(0, invoice.totalMinor);
                                  final ratio = invoice.totalMinor > 0 ? (paid / invoice.totalMinor).clamp(0.0, 1.0) : 0.0;
                                  final percent = (ratio * 100).toInt();

                                  return Column(
                                    children: [
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                              SizedBox(width: 6),
                                              Text(
                                                'المسدد:',
                                                style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                                              ),
                                            ],
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
                                          Row(
                                            children: [
                                              Icon(
                                                remaining > 0 ? Icons.timelapse_rounded : Icons.task_alt_rounded,
                                                size: 16,
                                                color: remaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'المتبقي:',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: remaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            formatMoney(remaining, invoice.currency),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: remaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Progress bar
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                remaining == 0
                                                    ? 'تم سداد الفاتورة بالكامل ✓'
                                                    : 'نسبة السداد: $percent%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: remaining == 0 ? Colors.green.shade700 : AppColors.dark,
                                                ),
                                              ),
                                              Text(
                                                remaining == 0 ? '100%' : '$percent%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: remaining == 0
                                                      ? Colors.green.shade700
                                                      : (percent > 0 ? Colors.orange.shade800 : Colors.grey.shade600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 8,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                remaining == 0
                                                    ? Colors.green.shade600
                                                    : (percent > 50 ? Colors.teal : (percent > 0 ? Colors.orange : Colors.grey)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confidential Profit Analytics Card
                      Consumer(
                        builder: (context, ref, _) {
                          final profit = ref.watch(invoiceProfitProvider(invoice.id));
                          if (profit == null) return const SizedBox.shrink();

                          final hasCostOrFees = profit.totalCostMinor > 0 || profit.transactionFeesMinor > 0;
                          final isProfitable = profit.netProfitMinor >= 0;

                          return Card(
                            elevation: 0,
                            color: isProfitable
                                ? Colors.green.shade50.withValues(alpha: 0.6)
                                : Colors.red.shade50.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isProfitable ? Colors.green.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.query_stats_rounded,
                                            size: 20,
                                            color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'تحليل الأرباح والتكاليف',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline, size: 12, color: Colors.amber.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              'سري • لا يظهر بالـ PDF',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'إجمالي المبيعات (الإيراد):',
                                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                                      ),
                                      Text(
                                        formatMoney(profit.totalRevenueMinor, invoice.currency),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'إجمالي تكلفة البنود:',
                                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                                      ),
                                      Text(
                                        '- ${formatMoney(profit.totalCostMinor, invoice.currency)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: profit.totalCostMinor > 0 ? Colors.orange.shade800 : AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (profit.transactionFeesMinor > 0) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'رسوم التحويل / البنك:',
                                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                                        ),
                                        Text(
                                          '- ${formatMoney(profit.transactionFeesMinor, invoice.currency)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'صافي الربح الفعلي:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (profit.totalRevenueMinor > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isProfitable
                                                    ? Colors.green.shade100
                                                    : Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${profit.profitMarginPercent.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isProfitable
                                                      ? Colors.green.shade900
                                                      : Colors.red.shade900,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        '${isProfitable ? '+ ' : ''}${formatMoney(profit.netProfitMinor, invoice.currency)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!hasCostOrFees) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '💡 لم تحدد سعر تكلفة أو رسوم لهذه الفاتورة. يمكنك تعديل الفاتورة لتسجيل التكلفة والرسوم.',
                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
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
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
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
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                  side: BorderSide(color: Colors.orange.shade400),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.history_rounded, size: 18),
                                label: const Text('إعادة لمسودة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                onPressed: () => _handleRevertToDraft(context, ref, invoice),
                              ),
                            ),
                          ],
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
    try {
      await ref.read(invoiceRepositoryProvider).updateInvoiceStatus(id, newStatus);
      ref.invalidate(invoiceByIdProvider(id));
      ref.invalidate(invoiceRemainingProvider(id));
      ref.invalidate(invoicesListProvider);
      ref.invalidate(clientInvoicesProvider(clientId));
      ref.invalidate(clientBalanceProvider(clientId));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'خطأ أثناء تحديث حالة الفاتورة: $e');
      }
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

  Future<void> _handleRevertToDraft(BuildContext context, WidgetRef ref, Invoice invoice) async {
    final payments = await (ref.read(databaseProvider).select(ref.read(databaseProvider).payments)
          ..where((p) => p.invoiceId.equals(invoice.id)))
        .get();

    if (payments.isNotEmpty) {
      final totalPaid = payments.fold<int>(0, (s, p) => s + p.amountMinor);
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.red),
                  SizedBox(width: 8),
                  Text('تعذّر إعادة الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: Text(
                'توجد ${payments.length} دفعات محصلة مسجلة على هذه الفاتورة بإجمالي ${formatMoney(totalPaid, invoice.currency)}.\n\nلحماية سلامة الحسابات والسجلات المالية، لا يمكن إعادة فاتورة مسددة جزئياً أو كلياً إلى مسودة دون تسوية أو حذف الدفعات المرتبطة بها أولاً.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً، فهمت'),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.history_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('إعادة الفاتورة إلى مسودة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(
            'سيتم تحويل الفاتورة رقم ${invoice.number} من معتمدة إلى "مسودة" لتتمكن من تعديل بنودها وأسعارها وتفاصيلها بحرية.\n\nتنبيه: لن تُحتسب الفاتورة ضمن مديونية العميل أثناء وجودها كمسودة حتى تقوم باعتمادها مجدداً.\n\nهل ترغب في المتابعة؟',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('نعم، إعادة وتعديل'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await _changeInvoiceStatus(
        context,
        ref,
        invoice.id,
        invoice.clientId,
        InvoiceStatus.draft,
        'تمت إعادة الفاتورة إلى مسودة بنجاح',
      );
      if (context.mounted) {
        context.push('/invoices/${invoice.id}/edit');
      }
    }
  }
}
