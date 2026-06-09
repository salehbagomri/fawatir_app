import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

class InvoiceItemRow {
  final descriptionController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();

  InvoiceItemRow();

  void dispose() {
    descriptionController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Client? _selectedClient;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  String _invoiceCurrency = 'USD';
  final _fxRateController = TextEditingController(text: '1.0');
  final _notesController = TextEditingController();

  final List<InvoiceItemRow> _itemRows = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItemRow(); // Start with one item row by default
  }

  @override
  void dispose() {
    for (final row in _itemRows) {
      row.dispose();
    }
    _fxRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItemRow() {
    final row = InvoiceItemRow();
    row.qtyController.addListener(_onItemChanged);
    row.priceController.addListener(_onItemChanged);
    setState(() {
      _itemRows.add(row);
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length > 1) {
      final row = _itemRows.removeAt(index);
      row.qtyController.removeListener(_onItemChanged);
      row.priceController.removeListener(_onItemChanged);
      row.dispose();
      _onItemChanged();
    }
  }

  void _onItemChanged() {
    setState(() {}); // Recalculate totals
  }

  int get _totalMinor {
    int total = 0;
    for (final row in _itemRows) {
      final qty = double.tryParse(row.qtyController.text.trim()) ?? 0.0;
      final priceStr = row.priceController.text.trim();
      final priceMinor = parseToMinor(priceStr);
      total += (qty * priceMinor).round();
    }
    return total;
  }

  Future<void> _selectIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _issueDate = picked;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار العميل'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال بند واحد على الأقل'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      
      // 1. Generate unique invoice number atomic transaction
      final number = await repo.nextInvoiceNumber();

      // 2. Determine exchange rate
      final showFxRate = _selectedClient != null && _invoiceCurrency != _selectedClient!.accountCurrency;
      final fxRate = showFxRate ? (double.tryParse(_fxRateController.text.trim()) ?? 1.0) : 1.0;

      // 3. Create Companions
      final invoice = InvoicesCompanion.insert(
        number: number,
        clientId: _selectedClient!.id,
        issueDate: _issueDate,
        dueDate: Value(_dueDate),
        status: const Value(InvoiceStatus.sent),
        currency: _invoiceCurrency,
        fxRateToAccount: Value(fxRate),
        notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      );

      final items = _itemRows.map((row) {
        final desc = row.descriptionController.text.trim();
        final qty = double.tryParse(row.qtyController.text.trim()) ?? 1.0;
        final price = parseToMinor(row.priceController.text.trim());

        return InvoiceItemsCompanion(
          invoiceId: const Value.absent(), // Assigned in transaction
          description: Value(desc),
          quantity: Value(qty),
          unitPriceMinor: Value(price),
          lineTotalMinor: const Value(0), // Assigned in transaction
        );
      }).toList();

      // 4. Save Invoice & Items in an atomic transaction
      await repo.createInvoiceWithItems(invoice, items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الفاتورة رقم $number بنجاح'),
            backgroundColor: AppColors.accent,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final activeClientsAsync = ref.watch(activeClientsProvider);
    final showFxRate = _selectedClient != null && _invoiceCurrency != _selectedClient!.accountCurrency;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إنشاء فاتورة جديدة'),
          actions: [
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _saveInvoice,
                  ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Client Selection Card
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العميل وعملة الفاتورة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                      ),
                      const SizedBox(height: 12),
                      activeClientsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('خطأ في تحميل العملاء: $err', style: const TextStyle(color: Colors.red)),
                        data: (clients) {
                          return DropdownButtonFormField<Client>(
                            initialValue: _selectedClient,
                            decoration: const InputDecoration(
                              labelText: 'اختر العميل *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: clients.map((client) {
                              return DropdownMenuItem<Client>(
                                value: client,
                                child: Text('${client.name} (${client.accountCurrency})'),
                              );
                            }).toList(),
                            onChanged: (client) {
                              if (client != null) {
                                setState(() {
                                  _selectedClient = client;
                                  _invoiceCurrency = client.accountCurrency;
                                  _fxRateController.text = '1.0';
                                });
                              }
                            },
                            validator: (val) => val == null ? 'يرجى اختيار العميل' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Currency Selection
                      DropdownButtonFormField<String>(
                        initialValue: _invoiceCurrency,
                        decoration: const InputDecoration(
                          labelText: 'عملة الفاتورة *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monetization_on),
                        ),
                        items: currencySymbols.keys.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text('$currency (${symbolFor(currency)})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _invoiceCurrency = val;
                              if (_selectedClient != null && _invoiceCurrency == _selectedClient!.accountCurrency) {
                                _fxRateController.text = '1.0';
                              }
                            });
                          }
                        },
                      ),
                      
                      // Exchange Rate (Shown if currencies differ)
                      if (showFxRate) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fxRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'سعر الصرف *',
                            helperText: '1 $_invoiceCurrency = ؟ ${_selectedClient!.accountCurrency}',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.currency_exchange),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال سعر الصرف';
                            }
                            final rate = double.tryParse(val.trim());
                            if (rate == null || rate <= 0) {
                              return 'يرجى إدخال سعر صرف صحيح أكبر من الصفر';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date Selection Card
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Issue Date
                      Expanded(
                        child: InkWell(
                          onTap: _selectIssueDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ الإصدار *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              '${_issueDate.year}/${_issueDate.month.toString().padLeft(2, '0')}/${_issueDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Due Date
                      Expanded(
                        child: InkWell(
                          onTap: _selectDueDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'تاريخ الاستحقاق',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.calendar_month),
                              suffixIcon: _dueDate != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _dueDate = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            child: Text(
                              _dueDate == null
                                  ? 'اختياري'
                                  : '${_dueDate!.year}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _dueDate == null ? AppColors.muted : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'بنود الفاتورة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addItemRow,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة بند'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dynamic Items List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _itemRows.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final row = _itemRows[index];
                  final qty = double.tryParse(row.qtyController.text.trim()) ?? 0.0;
                  final priceMinor = parseToMinor(row.priceController.text.trim());
                  final lineTotalMinor = (qty * priceMinor).round();

                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item Number Badge
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Description
                              Expanded(
                                child: TextFormField(
                                  controller: row.descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'وصف البند *',
                                    border: UnderlineInputBorder(),
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty ? 'يرجى إدخال الوصف' : null,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Delete Button
                              if (_itemRows.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItemRow(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Quantity
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: row.qtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية *',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'يرجى إدخال الكمية';
                                    }
                                    final d = double.tryParse(val.trim());
                                    if (d == null || d <= 0) {
                                      return 'أكبر من 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Price
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: row.priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'سعر الوحدة *',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'يرجى إدخال السعر';
                                    }
                                    final d = double.tryParse(val.trim());
                                    if (d == null || d < 0) {
                                      return 'قيمة غير سالبة';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Line Total Display
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'المجموع',
                                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatMoney(lineTotalMinor, _invoiceCurrency),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        formatMoney(_totalMinor, _invoiceCurrency),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الفاتورة',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
