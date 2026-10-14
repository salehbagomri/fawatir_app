import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/payments/application/payment_providers.dart';
import 'package:fawatir/features/payments/application/receipt_pdf_service.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/shared/pdf/receipt_pdf.dart';

class PaymentFormScreen extends ConsumerStatefulWidget {
  final int invoiceId;

  const PaymentFormScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _fxRateController = TextEditingController();
  final _notesController = TextEditingController();

  late String _currency;
  late DateTime _selectedDate;
  late String _method;

  bool _initialized = false;
  bool _isSaving = false;

  static const List<Map<String, String>> _supportedCurrencies = [
    {'code': 'USD', 'name': 'دولار أمريكي', 'symbol': '\$'},
    {'code': 'SAR', 'name': 'ريال سعودي', 'symbol': 'ر.س'},
    {'code': 'YER', 'name': 'ريال يمني', 'symbol': 'ر.ي'},
    {'code': 'AED', 'name': 'درهم إماراتي', 'symbol': 'د.إ'},
  ];

  static const List<String> _paymentMethods = [
    'تحويل بنكي',
    'محفظة إلكترونية',
    'نقداً',
    'تحويل شبكة صرافة',
    'شيك',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _currency = 'USD';
    _selectedDate = DateTime.now();
    _dateController.text = _formatDate(_selectedDate);
    _method = _paymentMethods.first;
    _fxRateController.text = '1.0';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _fxRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _initializeValues(Invoice invoice, Client client, int remainingMinor) {
    if (_initialized) return;

    _currency = invoice.currency;
    final remainingDecimal = remainingMinor > 0 ? remainingMinor / 100.0 : 0.0;
    _amountController.text =
        remainingDecimal > 0 ? remainingDecimal.toStringAsFixed(2) : '';

    if (_currency == client.accountCurrency) {
      _fxRateController.text = '1.0';
    } else {
      _fxRateController.text = invoice.fxRateToAccount.toString();
    }

    _initialized = true;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _savePayment(Invoice invoice, Client client) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final amountMinor = parseToMinor(_amountController.text);
    final showFxRate = _currency != client.accountCurrency;
    final fxRate = showFxRate
        ? (double.tryParse(_fxRateController.text) ?? 1.0)
        : 1.0;
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    try {
      final paymentId = await ref.read(paymentRepositoryProvider).recordPayment(
            clientId: client.id,
            invoiceId: invoice.id,
            amountMinor: amountMinor,
            currency: _currency,
            date: _selectedDate,
            fxRateToAccount: fxRate,
            method: _method,
            notes: notes,
          );

      // Refresh all providers
      ref.invalidate(invoiceByIdProvider(invoice.id));
      ref.invalidate(invoiceRemainingProvider(invoice.id));
      ref.invalidate(invoicePaymentsProvider(invoice.id));
      ref.invalidate(clientByIdProvider(client.id));
      ref.invalidate(clientBalanceProvider(client.id));
      ref.invalidate(clientPaymentsProvider(client.id));
      ref.invalidate(invoicesListProvider);
      ref.invalidate(clientInvoicesProvider(client.id));

      if (!mounted) return;

      _showSuccessDialog(paymentId, amountMinor, _currency);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ التحصيل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessDialog(int paymentId, int amountMinor, String currency) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تم تسجيل التحصيل بنجاح',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم حفظ دفعة بمبلغ ${formatMoney(amountMinor, currency)} وتحديث حالة الفاتورة ورصيد العميل.',
                style: const TextStyle(fontSize: 14, color: AppColors.dark),
              ),
              const SizedBox(height: 12),
              const Text(
                'هل ترغب في إصدار ومشاركة سند قبض الآن؟',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                if (mounted) {
                  context.pop(); // Go back to invoice details
                }
              },
              child: const Text(
                'تخطي والعودة',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text('معاينة'),
              onPressed: () async {
                Navigator.of(ctx).pop(); // Close dialog
                await _generateAndPreviewReceipt(paymentId);
                if (mounted) {
                  context.pop(); // Go back to invoice details
                }
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.share, size: 16),
              label: const Text('مشاركة السند'),
              onPressed: () async {
                Navigator.of(ctx).pop(); // Close dialog
                await _generateAndShareReceipt(paymentId);
                if (mounted) {
                  context.pop(); // Go back to invoice details
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShareReceipt(int paymentId) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfData = await ref.read(receiptPdfServiceProvider)(paymentId);
      final bytes = await buildReceiptPdf(pdfData);
      nav.pop(); // close loading dialog
      await shareReceiptPdf(bytes, pdfData.receiptNumber);
    } catch (e) {
      nav.pop(); // close loading dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء مشاركة سند القبض: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAndPreviewReceipt(int paymentId) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfData = await ref.read(receiptPdfServiceProvider)(paymentId);
      final bytes = await buildReceiptPdf(pdfData);
      nav.pop(); // close loading dialog
      await previewReceiptPdf(bytes);
    } catch (e) {
      nav.pop(); // close loading dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء إنشاء سند القبض: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(widget.invoiceId));
    final remainingAsync = ref.watch(invoiceRemainingProvider(widget.invoiceId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل تحصيل'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'حفظ التحصيل',
                onPressed: () {
                  final inv = invoiceAsync.value;
                  if (inv != null) {
                    final client = ref.read(clientByIdProvider(inv.clientId)).value;
                    if (client != null) {
                      _savePayment(inv, client);
                    }
                  }
                },
              ),
          ],
        ),
        body: invoiceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              'خطأ في تحميل بيانات الفاتورة: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (invoice) {
            if (invoice == null) {
              return const Center(
                child: Text('الفاتورة غير موجودة'),
              );
            }

            final clientAsync = ref.watch(clientByIdProvider(invoice.clientId));

            return clientAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'خطأ في تحميل بيانات العميل: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (client) {
                if (client == null) {
                  return const Center(
                    child: Text('بيانات العميل غير موجودة'),
                  );
                }

                return remainingAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'خطأ في حساب المبلغ المتبقي: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  data: (remainingMinor) {
                    _initializeValues(invoice, client, remainingMinor);
                    return _buildForm(invoice, client, remainingMinor);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(Invoice invoice, Client client, int remainingMinor) {
    final showFxRate = _currency != client.accountCurrency;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Invoice & Remaining Balance Card
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt,
                              color: AppColors.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: AppColors.accent,
                                ),
                              ),
                              Text(
                                client.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: remainingMinor <= 0
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          remainingMinor <= 0 ? 'مسددة' : 'غير مكتملة',
                          style: TextStyle(
                            color: remainingMinor <= 0
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إجمالي الفاتورة',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatMoney(invoice.totalMinor, invoice.currency),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: AppColors.line,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'المبلغ المتبقي',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatMoney(remainingMinor, invoice.currency),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: remainingMinor > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (remainingMinor > 0) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.accent,
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: const Text(
                          'سداد كامل المتبقي',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final remDecimal = remainingMinor / 100.0;
                          setState(() {
                            _amountController.text =
                                remDecimal.toStringAsFixed(2);
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'تفاصيل التحصيل',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),

          // Amount Field
          TextFormField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ المستلم *',
              hintText: '0.00',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payments_outlined),
              suffixText: symbolFor(_currency),
              suffixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
              helperText: 'المبلغ المسدد بهذه الدفعة',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'الرجاء إدخال المبلغ المستلم';
              }
              final minor = parseToMinor(val);
              if (minor <= 0) {
                return 'الرجاء إدخال مبلغ صحيح أكبر من الصفر';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Currency Dropdown
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'عملة الدفع *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monetization_on_outlined),
            ),
            items: _supportedCurrencies.map((c) {
              return DropdownMenuItem<String>(
                value: c['code'],
                child: Text('${c['code']} - ${c['name']} (${c['symbol']})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _currency = val;
                  if (_currency == client.accountCurrency) {
                    _fxRateController.text = '1.0';
                  } else if (_currency == invoice.currency) {
                    _fxRateController.text =
                        invoice.fxRateToAccount.toString();
                  } else {
                    _fxRateController.text = '1.0';
                  }
                });
              }
            },
          ),
          const SizedBox(height: 18),

          // Exchange Rate Field (Conditional: payment currency != client account currency)
          if (showFxRate) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تختلف عملة الدفع ($_currency) عن عملة حساب العميل (${client.accountCurrency})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fxRateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'سعر الصرف (1 $_currency = ؟ ${client.accountCurrency}) *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.currency_exchange),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'الرجاء إدخال سعر الصرف';
                      }
                      final d = double.tryParse(val);
                      if (d == null || d <= 0) {
                        return 'الرجاء إدخال سعر صرف صحيح أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Payment Date
          TextFormField(
            controller: _dateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'تاريخ التحصيل *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            onTap: _selectDate,
          ),
          const SizedBox(height: 18),

          // Payment Method Dropdown
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(
              labelText: 'طريقة الدفع *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: _paymentMethods.map((m) {
              return DropdownMenuItem<String>(
                value: m,
                child: Text(m),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _method = val;
                });
              }
            },
          ),
          const SizedBox(height: 18),

          // Notes
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              hintText: 'رقم مرجع الحوالة، اسم المودع، إلخ...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_alt_outlined),
            ),
          ),
          const SizedBox(height: 28),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'جارٍ الحفظ...' : 'حفظ التحصيل',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isSaving ? null : () => _savePayment(invoice, client),
            ),
          ),
        ],
      ),
    );
  }
}
