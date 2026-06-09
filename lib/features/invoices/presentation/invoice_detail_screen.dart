import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_pdf_service.dart';
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
                            onPressed: () => _showRecordPaymentBottomSheet(context, ref, invoice, client),
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

  void _showRecordPaymentBottomSheet(BuildContext context, WidgetRef ref, Invoice invoice, Client? client) async {
    if (client == null) return;

    final remainingMinor = await ref.read(paymentRepositoryProvider).invoiceRemainingMinor(invoice.id);
    final remainingDecimal = remainingMinor / 100.0;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return RecordPaymentSheet(
          invoice: invoice,
          client: client,
          remainingDecimal: remainingDecimal,
          ref: ref,
        );
      },
    );
  }
}

class RecordPaymentSheet extends StatefulWidget {
  final Invoice invoice;
  final Client client;
  final double remainingDecimal;
  final WidgetRef ref;

  const RecordPaymentSheet({
    super.key,
    required this.invoice,
    required this.client,
    required this.remainingDecimal,
    required this.ref,
  });

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late String _currency;
  late DateTime _selectedDate;
  late TextEditingController _dateController;
  late String _method;
  late TextEditingController _notesController;
  late TextEditingController _fxRateController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remainingDecimal > 0 ? widget.remainingDecimal.toStringAsFixed(2) : '',
    );
    _currency = widget.invoice.currency;
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _method = 'تحويل بنكي';
    _notesController = TextEditingController();

    double initialFxRate = 1.0;
    if (_currency == widget.invoice.currency) {
      initialFxRate = widget.invoice.fxRateToAccount;
    }
    _fxRateController = TextEditingController(text: initialFxRate.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _fxRateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final showFxRate = _currency != widget.client.accountCurrency;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تسجيل تحصيل جديد',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  final d = double.tryParse(val);
                  if (d == null || d <= 0) {
                    return 'الرجاء إدخال مبلغ صحيح أكبر من الصفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Currency Dropdown
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'العملة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD - دولار أمريكي')),
                  DropdownMenuItem(value: 'YER', child: Text('YER - ريال يمني')),
                  DropdownMenuItem(value: 'SAR', child: Text('SAR - ريال سعودي')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _currency = val;
                      if (_currency == widget.client.accountCurrency) {
                        _fxRateController.text = '1.0';
                      } else if (_currency == widget.invoice.currency) {
                        _fxRateController.text = widget.invoice.fxRateToAccount.toString();
                      } else {
                        _fxRateController.text = '1.0';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date field
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'تاريخ التحصيل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = _formatDate(picked);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // FxRate Field (Visible only if currencies mismatch)
              if (showFxRate) ...[
                TextFormField(
                  controller: _fxRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'سعر الصرف (1 $_currency = ؟ ${widget.client.accountCurrency})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_exchange),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الرجاء إدخال سعر الصرف';
                    }
                    final d = double.tryParse(val);
                    if (d == null || d <= 0) {
                      return 'الرجاء إدخال سعر صرف صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Method Dropdown
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
                  DropdownMenuItem(value: 'محفظة', child: Text('محفظة')),
                  DropdownMenuItem(value: 'نقد', child: Text('نقد')),
                  DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _method = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text('حفظ التحصيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amountMinor = parseToMinor(_amountController.text);
    final fxRate = double.tryParse(_fxRateController.text) ?? 1.0;
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.ref.read(paymentRepositoryProvider).recordPayment(
        clientId: widget.client.id,
        invoiceId: widget.invoice.id,
        amountMinor: amountMinor,
        currency: _currency,
        date: _selectedDate,
        fxRateToAccount: fxRate,
        method: _method,
        notes: notes,
      );

      // Invalidate providers to refresh
      widget.ref.invalidate(invoiceByIdProvider(widget.invoice.id));
      widget.ref.invalidate(clientByIdProvider(widget.client.id));
      widget.ref.invalidate(clientBalanceProvider(widget.client.id));
      widget.ref.invalidate(clientPaymentsProvider(widget.client.id));
      widget.ref.invalidate(invoicesListProvider);
      widget.ref.invalidate(clientInvoicesProvider(widget.client.id));

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تسجيل التحصيل بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ أثناء حفظ التحصيل: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
