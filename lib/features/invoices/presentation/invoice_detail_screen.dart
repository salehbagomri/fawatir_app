import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/company/application/company_providers.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/shared/pdf/invoice_pdf.dart';

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
    final companyAsync = ref.watch(companyStreamProvider);

    final invoice = invoiceAsync.value;
    final client = invoice != null ? ref.watch(clientByIdProvider(invoice.clientId)).value : null;
    final company = companyAsync.value;
    final items = itemsAsync.value ?? [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الفاتورة'),
          actions: [
            if (invoice != null && client != null && company != null) ...[
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'مشاركة PDF',
                onPressed: () => _shareInvoice(context, ref, company, client, invoice, items),
              ),
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'معاينة PDF',
                onPressed: () => _previewInvoice(context, ref, company, client, invoice, items),
              ),
            ]
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

                      // Grand Total Card
                      Card(
                        color: AppColors.accent.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'إجمالي الفاتورة:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                              Text(
                                formatMoney(invoice.totalMinor, invoice.currency),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent),
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
                      ],
                      const SizedBox(height: 24),
                      // Actions Section
                      if (client != null && company != null) ...[
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
                                onPressed: () => _shareInvoice(context, ref, company, client, invoice, items),
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
                                onPressed: () => _previewInvoice(context, ref, company, client, invoice, items),
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

  Future<Uint8List?> _loadLogoBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading logo bytes: $e');
    }
    return null;
  }

  InvoicePdfData _buildPdfData(Company company, Client client, Invoice invoice, List<InvoiceItem> items, Uint8List? logoBytes) {
    return InvoicePdfData(
      company: CompanyInfo(
        name: company.name,
        logoBytes: logoBytes,
        address: company.address,
        phone: company.phone,
        email: company.email,
        bankDetails: company.bankDetails,
      ),
      client: ClientInfo(
        name: client.name,
        contactPerson: client.contactPerson,
        phone: client.phone,
        address: client.address,
      ),
      number: invoice.number,
      issueDate: invoice.issueDate,
      dueDate: invoice.dueDate,
      currency: invoice.currency,
      items: items.map((e) => InvoiceLine(
        description: e.description,
        quantity: e.quantity,
        unitPriceMinor: e.unitPriceMinor,
      )).toList(),
      notes: invoice.notes,
    );
  }

  Future<void> _shareInvoice(BuildContext context, WidgetRef ref, Company company, Client client, Invoice invoice, List<InvoiceItem> items) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final logoBytes = await _loadLogoBytes(company.logoPath);
      final pdfData = _buildPdfData(company, client, invoice, items, logoBytes);
      final pdfBytes = await buildInvoicePdf(pdfData);
      nav.pop(); // Dismiss loading dialog
      await shareInvoicePdf(pdfBytes, invoice.number);
    } catch (e) {
      nav.pop(); // Dismiss loading dialog
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء مشاركة الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _previewInvoice(BuildContext context, WidgetRef ref, Company company, Client client, Invoice invoice, List<InvoiceItem> items) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final logoBytes = await _loadLogoBytes(company.logoPath);
      final pdfData = _buildPdfData(company, client, invoice, items, logoBytes);
      final pdfBytes = await buildInvoicePdf(pdfData);
      nav.pop(); // Dismiss loading dialog
      await previewInvoicePdf(pdfBytes);
    } catch (e) {
      nav.pop(); // Dismiss loading dialog
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء معاينة الفاتورة: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
