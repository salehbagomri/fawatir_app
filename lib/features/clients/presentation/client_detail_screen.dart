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
                        _buildEmptyState('لا يوجد كشف حساب بعد', Icons.history),
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.muted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 16,
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
                        Row(
                          children: [
                            const Icon(Icons.payment, size: 16, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(
                              payment.method ?? 'طريقة دفع غير محددة',
                              style: const TextStyle(fontSize: 13, color: AppColors.dark),
                            ),
                          ],
                        ),
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
            );
          },
        );
      },
    );
  }
}
