import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/shared/pdf/receipt_pdf.dart';
import 'package:fawatir/features/payments/application/receipt_pdf_service.dart';
import 'package:fawatir/features/statements/data/statement_repository.dart';
import 'package:fawatir/features/statements/application/statement_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(clientId));
    final balanceAsync = ref.watch(clientBalanceProvider(clientId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: clientAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          appBar: AppBar(title: const Text('تفاصيل العميل')),
          body: Center(child: Text('خطأ في تحميل العميل: $err')),
        ),
        data: (client) {
          if (client == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('تفاصيل العميل')),
              body: const Center(child: Text('العميل غير موجود')),
            );
          }

          return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: Text(client.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      context.go('/clients/edit/${client.id}');
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  // Upper Card with Client Details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status and Name
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    client.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(client.isActive),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Balance info
                            balanceAsync.when(
                              loading: () => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (err, stack) => Text(
                                'خطأ في حساب الرصيد',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                              data: (balanceMinor) => _buildBalanceCard(balanceMinor, client.accountCurrency),
                            ),

                            const Divider(height: 32),

                            // Additional Info Rows
                            if (client.contactPerson != null && client.contactPerson!.isNotEmpty)
                              _buildDetailRow(Icons.contact_phone, 'الشخص المسؤول', client.contactPerson!),
                            if (client.phone != null && client.phone!.isNotEmpty)
                              _buildDetailRow(Icons.phone, 'رقم الهاتف', client.phone!),
                            if (client.address != null && client.address!.isNotEmpty)
                              _buildDetailRow(Icons.location_on, 'العنوان', client.address!),
                            _buildDetailRow(
                              Icons.monetization_on,
                              'عملة الحساب',
                              '${client.accountCurrency} (${symbolFor(client.accountCurrency)})',
                            ),
                            if (client.notes != null && client.notes!.isNotEmpty)
                              _buildDetailRow(Icons.note, 'ملاحظات', client.notes!),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab Bar
                  const TabBar(
                    labelColor: AppColors.accent,
                    unselectedLabelColor: AppColors.muted,
                    indicatorColor: AppColors.accent,
                    tabs: [
                      Tab(text: 'الفواتير'),
                      Tab(text: 'التحصيلات'),
                      Tab(text: 'كشف الحساب'),
                    ],
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        ClientInvoicesTab(clientId: client.id),
                        ClientPaymentsTab(clientId: client.id),
                        ClientStatementTab(clientId: client.id, accountCurrency: client.accountCurrency),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final text = isActive ? 'نشط' : 'غير نشط';
    final bgColor = isActive ? Colors.green.shade50 : Colors.red.shade50;
    final textColor = isActive ? Colors.green.shade700 : Colors.red.shade700;
    final borderColor = isActive ? Colors.green.shade200 : Colors.red.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBalanceCard(int balanceMinor, String currency) {
    Color cardColor;
    Color textColor;
    String subtitle;
    final formatted = formatMoney(balanceMinor, currency);

    if (balanceMinor > 0) {
      cardColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      subtitle = 'مستحق تحصيله';
    } else if (balanceMinor < 0) {
      cardColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      subtitle = 'رصيد للعميل';
    } else {
      cardColor = Colors.grey.shade50;
      textColor = Colors.grey.shade800;
      subtitle = 'لا توجد مستحقات';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرصيد الحالي',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          Text(
            formatted,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientInvoicesTab extends ConsumerWidget {
  final int clientId;
  const ClientInvoicesTab({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(clientInvoicesProvider(clientId));

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ في تحميل الفواتير: $err')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: AppColors.muted.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد فواتير بعد',
                  style: TextStyle(color: AppColors.muted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invoice = invoices[index];
            final statusColor = _getStatusColor(invoice.status);

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.go('/invoices/${invoice.id}');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${invoice.issueDate.year}/${invoice.issueDate.month.toString().padLeft(2, '0')}/${invoice.issueDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(invoice.totalMinor, invoice.currency),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
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
}

class ClientPaymentsTab extends ConsumerWidget {
  final int clientId;
  const ClientPaymentsTab({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(clientPaymentsProvider(clientId));

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ في تحميل التحصيلات: $err')),
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  size: 48,
                  color: AppColors.muted.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد تحصيلات بعد',
                  style: TextStyle(color: AppColors.muted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final payment = payments[index];
            final dateStr = '${payment.paymentDate.year}/${payment.paymentDate.month.toString().padLeft(2, '0')}/${payment.paymentDate.day.toString().padLeft(2, '0')}';

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatMoney(payment.amountMinor, payment.currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.payment, size: 16, color: AppColors.muted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        payment.method ?? 'طريقة دفع غير محددة',
                                        style: const TextStyle(fontSize: 13, color: AppColors.dark),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (payment.invoiceId != null)
                                FutureBuilder<Invoice?>(
                                  future: ref.read(invoiceRepositoryProvider).getInvoice(payment.invoiceId!),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Text(
                                        'فاتورة: ${snapshot.data!.number}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                            ],
                          ),
                          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                            const Divider(height: 16),
                            Text(
                              payment.notes!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onLongPress: () => _previewReceipt(context, ref, payment),
                      child: IconButton(
                        icon: const Icon(Icons.receipt_long, color: AppColors.accent),
                        tooltip: 'سند قبض (مشاركة، نقرة مطولة للمعاينة)',
                        onPressed: () => _shareReceipt(context, ref, payment),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareReceipt(BuildContext context, WidgetRef ref, Payment payment) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ref.read(receiptPdfServiceProvider)(payment.id);
      final bytes = await buildReceiptPdf(data);
      nav.pop();
      await shareReceiptPdf(bytes, data.receiptNumber);
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء مشاركة السند: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _previewReceipt(BuildContext context, WidgetRef ref, Payment payment) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await ref.read(receiptPdfServiceProvider)(payment.id);
      final bytes = await buildReceiptPdf(data);
      nav.pop();
      await previewReceiptPdf(bytes);
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء معاينة السند: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class ClientStatementTab extends StatefulWidget {
  final int clientId;
  final String accountCurrency;

  const ClientStatementTab({
    super.key,
    required this.clientId,
    required this.accountCurrency,
  });

  @override
  State<ClientStatementTab> createState() => _ClientStatementTabState();
}

class _ClientStatementTabState extends State<ClientStatementTab> {
  DateTime? _fromDate;
  DateTime? _toDate;

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  void _resetFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Period Filter Section
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.muted),
                      label: Text(
                        _fromDate == null ? 'من تاريخ' : _formatDate(_fromDate!),
                        style: const TextStyle(fontSize: 12, color: AppColors.dark),
                      ),
                      onPressed: () => _selectFromDate(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.muted),
                      label: Text(
                        _toDate == null ? 'إلى تاريخ' : _formatDate(_toDate!),
                        style: const TextStyle(fontSize: 12, color: AppColors.dark),
                      ),
                      onPressed: () => _selectToDate(context),
                    ),
                  ),
                  if (_fromDate != null || _toDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      tooltip: 'إعادة ضبط',
                      onPressed: _resetFilter,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Statement Content
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final statementAsync = ref.watch(statementProvider((
                clientId: widget.clientId,
                from: _fromDate,
                to: _toDate,
              )));

              return statementAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ في تحميل كشف الحساب: $err')),
                data: (statement) {
                  if (statement.entries.isEmpty && statement.openingBalanceMinor == 0) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 48,
                            color: AppColors.muted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد عمليات مسجلة في هذه الفترة',
                            style: TextStyle(color: AppColors.muted, fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Opening Balance Card
                        Card(
                          color: Colors.grey.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.line),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الرصيد الافتتاحي:',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted),
                                ),
                                Text(
                                  formatMoney(statement.openingBalanceMinor, statement.accountCurrency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.dark),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ledger Table Card
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.2), // Date
                                1: FlexColumnWidth(3.0), // Ref
                                2: FlexColumnWidth(2.0), // Debit (مدين)
                                3: FlexColumnWidth(2.0), // Credit (دائن)
                                4: FlexColumnWidth(2.5), // Running Balance
                              },
                              children: [
                                // Table Header
                                TableRow(
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.line, width: 1.5)),
                                  ),
                                  children: [
                                    _buildHeaderCell('التاريخ'),
                                    _buildHeaderCell('البيان'),
                                    _buildHeaderCell('مدين', align: TextAlign.right),
                                    _buildHeaderCell('دائن', align: TextAlign.right),
                                    _buildHeaderCell('الرصيد', align: TextAlign.right),
                                  ],
                                ),
                                // Table Body Rows
                                ...statement.entries.map((entry) {
                                  final isInvoice = entry.type == StatementEntryType.invoice;
                                  final rowColor = isInvoice
                                      ? Colors.blue.withValues(alpha: 0.03)
                                      : Colors.green.withValues(alpha: 0.03);

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: rowColor,
                                      border: const Border(bottom: BorderSide(color: AppColors.line, width: 0.5)),
                                    ),
                                    children: [
                                      _buildBodyCell(_formatDate(entry.date), size: 11),
                                      _buildBodyCell(entry.reference, size: 11, bold: true),
                                      _buildBodyCell(
                                        entry.debitMinor > 0
                                            ? formatAmount(entry.debitMinor)
                                            : '-',
                                        align: TextAlign.right,
                                        size: 11,
                                        color: entry.debitMinor > 0 ? Colors.red.shade700 : null,
                                      ),
                                      _buildBodyCell(
                                        entry.creditMinor > 0
                                            ? formatAmount(entry.creditMinor)
                                            : '-',
                                        align: TextAlign.right,
                                        size: 11,
                                        color: entry.creditMinor > 0 ? Colors.green.shade700 : null,
                                      ),
                                      _buildBodyCell(
                                        formatAmount(entry.runningBalanceMinor),
                                        align: TextAlign.right,
                                        size: 11,
                                        bold: true,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Totals Summary Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'إجمالي المدين: ${formatMoney(statement.totalDebitMinor, statement.accountCurrency)}',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'إجمالي الدائن: ${formatMoney(statement.totalCreditMinor, statement.accountCurrency)}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Closing Balance Card
                        Card(
                          color: AppColors.accent.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الرصيد الختامي:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                                ),
                                Text(
                                  formatMoney(statement.closingBalanceMinor, statement.accountCurrency),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.muted.withValues(alpha: 0.8),
          fontSize: 12,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildBodyCell(String text, {TextAlign align = TextAlign.start, double size = 12, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppColors.dark,
        ),
        textAlign: align,
      ),
    );
  }
}
