import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/payments/application/payment_providers.dart';
import 'package:fawatir/shared/widgets/app_snackbar.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';
import 'package:fawatir/features/products/application/product_providers.dart';

class InvoiceItemRow {
  final descriptionController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  final costController = TextEditingController();
  int? productId;

  InvoiceItemRow();

  void dispose() {
    descriptionController.dispose();
    qtyController.dispose();
    priceController.dispose();
    costController.dispose();
  }
}

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final int? invoiceId;
  final int? duplicateFromInvoiceId;
  final int? initialClientId;

  const InvoiceFormScreen({
    super.key,
    this.invoiceId,
    this.duplicateFromInvoiceId,
    this.initialClientId,
  });

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
  final _discountController = TextEditingController();
  bool _isDiscountPercent = false;
  final _taxPercentController = TextEditingController();
  final _feesController = TextEditingController();

  final List<InvoiceItemRow> _itemRows = [];
  bool _isSaving = false;
  bool _isInitialized = false;
  bool _canExitWithoutConfirm = false;

  bool get _hasUnsavedChanges {
    if (_canExitWithoutConfirm) return false;
    if (_selectedClient != null) return true;
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_discountController.text.trim().isNotEmpty) return true;
    if (_taxPercentController.text.trim().isNotEmpty) return true;
    if (_feesController.text.trim().isNotEmpty) return true;
    for (final row in _itemRows) {
      if (row.descriptionController.text.trim().isNotEmpty) return true;
      if (row.priceController.text.trim().isNotEmpty) return true;
      if (row.costController.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_onItemChanged);
    _taxPercentController.addListener(_onItemChanged);
    _feesController.addListener(_onItemChanged);
    if (widget.invoiceId == null && widget.duplicateFromInvoiceId == null) {
      _addItemRow(); // Start with one item row by default for new invoices
    }
  }

  void _initFromInvoice(Invoice invoice, List<InvoiceItem> items, List<Client> clients, {bool isDuplicating = false}) {
    if (_isInitialized) return;

    try {
      _selectedClient = clients.firstWhere((c) => c.id == invoice.clientId);
    } catch (_) {
      _selectedClient = null;
    }

    _invoiceCurrency = invoice.currency;
    _issueDate = isDuplicating ? DateTime.now() : invoice.issueDate;
    if (isDuplicating) {
      _dueDate = invoice.dueDate != null
          ? DateTime.now().add(invoice.dueDate!.difference(invoice.issueDate))
          : null;
    } else {
      _dueDate = invoice.dueDate;
    }
    _fxRateController.text = invoice.fxRateToAccount.toString();
    _notesController.text = invoice.notes ?? '';

    if (invoice.transactionFeesMinor > 0) {
      _feesController.text = (invoice.transactionFeesMinor / 100.0).toStringAsFixed(2);
    } else {
      _feesController.text = '';
    }

    if (invoice.discountPercent > 0) {
      _isDiscountPercent = true;
      _discountController.text = invoice.discountPercent.toString();
    } else if (invoice.discountMinor > 0) {
      _isDiscountPercent = false;
      _discountController.text = (invoice.discountMinor / 100.0).toStringAsFixed(2);
    } else {
      _discountController.text = '';
    }

    if (invoice.taxPercent > 0) {
      _taxPercentController.text = invoice.taxPercent.toString();
    } else {
      _taxPercentController.text = '';
    }

    for (final r in _itemRows) {
      r.dispose();
    }
    _itemRows.clear();

    if (items.isNotEmpty) {
      for (final item in items) {
        final row = InvoiceItemRow();
        row.descriptionController.text = item.description;
        row.qtyController.text = item.quantity.toString();
        row.priceController.text = (item.unitPriceMinor / 100.0).toStringAsFixed(2);
        if (item.costPriceMinor > 0) {
          row.costController.text = (item.costPriceMinor / 100.0).toStringAsFixed(2);
        }
        row.productId = item.productId;
        row.qtyController.addListener(_onItemChanged);
        row.priceController.addListener(_onItemChanged);
        row.costController.addListener(_onItemChanged);
        _itemRows.add(row);
      }
    } else {
      _addItemRow();
    }

    _isInitialized = true;
  }

  @override
  void dispose() {
    _discountController.removeListener(_onItemChanged);
    _taxPercentController.removeListener(_onItemChanged);
    _feesController.removeListener(_onItemChanged);
    _discountController.dispose();
    _taxPercentController.dispose();
    _feesController.dispose();
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
    row.costController.addListener(_onItemChanged);
    setState(() {
      _itemRows.add(row);
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length > 1) {
      final row = _itemRows.removeAt(index);
      row.qtyController.removeListener(_onItemChanged);
      row.priceController.removeListener(_onItemChanged);
      row.costController.removeListener(_onItemChanged);
      row.dispose();
      _onItemChanged();
    }
  }

  void _onItemChanged() {
    setState(() {}); // Recalculate totals
  }

  void _pickProductForItem(InvoiceItemRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerModal(
        currency: _invoiceCurrency,
        onSelected: (product) {
          setState(() {
            row.descriptionController.text = product.name;
            row.priceController.text = (product.defaultPriceMinor / 100.0).toStringAsFixed(2);
            if (product.defaultCostMinor > 0) {
              row.costController.text = (product.defaultCostMinor / 100.0).toStringAsFixed(2);
            }
            row.productId = product.id;
          });
          _onItemChanged();
        },
      ),
    );
  }

  int get _totalCostMinor {
    int total = 0;
    for (final row in _itemRows) {
      final qty = double.tryParse(row.qtyController.text.trim()) ?? 0.0;
      final costStr = row.costController.text.trim();
      final costMinor = parseToMinor(costStr);
      total += (qty * costMinor).round();
    }
    return total;
  }

  int get _transactionFeesMinor {
    final text = _feesController.text.trim();
    if (text.isEmpty) return 0;
    return parseToMinor(text);
  }

  int get _estimatedProfitMinor {
    return _totalMinor - _totalCostMinor - _transactionFeesMinor;
  }

  int get _subtotalMinor {
    int total = 0;
    for (final row in _itemRows) {
      final qty = double.tryParse(row.qtyController.text.trim()) ?? 0.0;
      final priceStr = row.priceController.text.trim();
      final priceMinor = parseToMinor(priceStr);
      total += (qty * priceMinor).round();
    }
    return total;
  }

  int get _discountMinor {
    final text = _discountController.text.trim();
    if (text.isEmpty) return 0;
    if (_isDiscountPercent) {
      final percent = double.tryParse(text) ?? 0.0;
      if (percent <= 0) return 0;
      final val = (_subtotalMinor * percent / 100).round();
      return val > _subtotalMinor ? _subtotalMinor : val;
    } else {
      final minor = parseToMinor(text);
      return minor > _subtotalMinor ? _subtotalMinor : minor;
    }
  }

  int get _taxMinor {
    final text = _taxPercentController.text.trim();
    if (text.isEmpty) return 0;
    final percent = double.tryParse(text) ?? 0.0;
    if (percent <= 0) return 0;
    final net = (_subtotalMinor - _discountMinor).clamp(0, double.infinity).toInt();
    return (net * percent / 100).round();
  }

  int get _totalMinor {
    final net = (_subtotalMinor - _discountMinor).clamp(0, double.infinity).toInt();
    return net + _taxMinor;
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

  Future<void> _saveInvoice({required InvoiceStatus targetStatus}) async {
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

    if (_dueDate != null) {
      final issueOnly = DateTime(_issueDate.year, _issueDate.month, _issueDate.day);
      final dueOnly = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      if (dueOnly.isBefore(issueOnly)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تاريخ الاستحقاق يجب أن يكون بعد أو نفس تاريخ الإصدار'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    for (int i = 0; i < _itemRows.length; i++) {
      final row = _itemRows[i];
      final desc = row.descriptionController.text.trim();
      final qty = double.tryParse(row.qtyController.text.trim()) ?? 0.0;
      final price = parseToMinor(row.priceController.text.trim());
      if (desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يرجى إدخال وصف البند رقم ${i + 1}'), backgroundColor: Colors.red),
        );
        return;
      }
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الكمية في البند رقم ${i + 1} يجب أن تكون أكبر من الصفر'), backgroundColor: Colors.red),
        );
        return;
      }
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('سعر الوحدة في البند رقم ${i + 1} يجب أن يكون أكبر من الصفر'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final showFxRate = _selectedClient != null && _invoiceCurrency != _selectedClient!.accountCurrency;
    final fxRate = showFxRate ? (double.tryParse(_fxRateController.text.trim()) ?? 1.0) : 1.0;
    if (showFxRate && fxRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سعر الصرف يجب أن يكون أكبر من الصفر'), backgroundColor: Colors.red),
      );
      return;
    }

    if (targetStatus == InvoiceStatus.sent) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'اعتماد الفاتورة',
        message: 'سيتم اعتماد الفاتورة وتغيير حالتها إلى "مرسلة"، ولن يمكن تعديل بياناتها أو بنودها بعد ذلك. هل أنت متأكد من الاعتماد؟',
        confirmLabel: 'نعم، اعتماد الفاتورة',
        cancelLabel: 'تراجع',
        icon: Icons.send_rounded,
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isSaving = true;
    });

    final isEditing = widget.invoiceId != null;

    try {
      final repo = ref.read(invoiceRepositoryProvider);

      final items = _itemRows.map((row) {
        final desc = row.descriptionController.text.trim();
        final qty = double.tryParse(row.qtyController.text.trim()) ?? 1.0;
        final price = parseToMinor(row.priceController.text.trim());
        final cost = parseToMinor(row.costController.text.trim());

        return InvoiceItemsCompanion(
          invoiceId: isEditing ? Value(widget.invoiceId!) : const Value.absent(),
          productId: Value(row.productId),
          description: Value(desc),
          quantity: Value(qty),
          unitPriceMinor: Value(price),
          costPriceMinor: Value(cost),
          lineTotalMinor: const Value(0),
        );
      }).toList();

      if (isEditing) {
        final existingInvoice = ref.read(invoiceByIdProvider(widget.invoiceId!)).value;
        final number = existingInvoice?.number ?? '';

        final discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
        final taxVal = double.tryParse(_taxPercentController.text.trim()) ?? 0.0;

        final invoiceCompanion = InvoicesCompanion(
          id: Value(widget.invoiceId!),
          number: Value(number),
          clientId: Value(_selectedClient!.id),
          issueDate: Value(_issueDate),
          dueDate: Value(_dueDate),
          status: Value(targetStatus),
          currency: Value(_invoiceCurrency),
          fxRateToAccount: Value(fxRate),
          discountMinor: Value(_discountMinor),
          discountPercent: Value(_isDiscountPercent ? discountVal : 0.0),
          taxMinor: Value(_taxMinor),
          taxPercent: Value(taxVal),
          transactionFeesMinor: Value(_transactionFeesMinor),
          notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        );

        await repo.updateInvoiceWithItems(widget.invoiceId!, invoiceCompanion, items);

        ref.invalidate(invoiceByIdProvider(widget.invoiceId!));
        ref.invalidate(invoiceItemsProvider(widget.invoiceId!));
        ref.invalidate(invoiceRemainingProvider(widget.invoiceId!));
        ref.invalidate(invoiceProfitProvider(widget.invoiceId!));
        ref.invalidate(invoicesListProvider);
        if (_selectedClient != null) {
          ref.invalidate(clientInvoicesProvider(_selectedClient!.id));
          ref.invalidate(clientBalanceProvider(_selectedClient!.id));
        }

        if (mounted) {
          final msg = targetStatus == InvoiceStatus.sent
              ? 'تم اعتماد وإصدار الفاتورة رقم $number بنجاح'
              : 'تم حفظ تعديلات الفاتورة رقم $number بنجاح';
          AppSnackBar.showSuccess(context, msg);
          _canExitWithoutConfirm = true;
          Navigator.of(context).pop();
        }
      } else {
        final number = await repo.nextInvoiceNumber();
        final discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
        final taxVal = double.tryParse(_taxPercentController.text.trim()) ?? 0.0;

        final invoice = InvoicesCompanion.insert(
          number: number,
          clientId: _selectedClient!.id,
          issueDate: _issueDate,
          dueDate: Value(_dueDate),
          status: Value(targetStatus),
          currency: _invoiceCurrency,
          fxRateToAccount: Value(fxRate),
          discountMinor: Value(_discountMinor),
          discountPercent: Value(_isDiscountPercent ? discountVal : 0.0),
          taxMinor: Value(_taxMinor),
          taxPercent: Value(taxVal),
          transactionFeesMinor: Value(_transactionFeesMinor),
          notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        );

        await repo.createInvoiceWithItems(invoice, items);

        ref.invalidate(invoicesListProvider);
        if (_selectedClient != null) {
          ref.invalidate(clientInvoicesProvider(_selectedClient!.id));
          ref.invalidate(clientBalanceProvider(_selectedClient!.id));
        }

        if (mounted) {
          final msg = targetStatus == InvoiceStatus.sent
              ? 'تم إنشاء واعتماد الفاتورة رقم $number بنجاح'
              : 'تم حفظ الفاتورة رقم $number كمسودة بنجاح';
          AppSnackBar.showSuccess(context, msg);
          _canExitWithoutConfirm = true;
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'حدث خطأ أثناء الحفظ: $e');
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
    final isEditing = widget.invoiceId != null;
    final isDuplicating = widget.duplicateFromInvoiceId != null;

    if (isEditing) {
      final invoiceAsync = ref.watch(invoiceByIdProvider(widget.invoiceId!));
      final itemsAsync = ref.watch(invoiceItemsProvider(widget.invoiceId!));

      if (invoiceAsync.isLoading || itemsAsync.isLoading) {
        return const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      final invoice = invoiceAsync.value;
      final items = itemsAsync.value;

      if (invoice == null) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('تعديل الفاتورة')),
            body: const Center(child: Text('الفاتورة غير موجودة')),
          ),
        );
      }

      if (invoice.status != InvoiceStatus.draft) {
        final paymentsAsync = ref.watch(invoicePaymentsProvider(widget.invoiceId!));
        final payments = paymentsAsync.value ?? [];
        final hasPayments = payments.isNotEmpty;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text('الفاتورة ${invoice.number}')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasPayments ? Icons.lock_outline : Icons.history_rounded,
                      size: 64,
                      color: hasPayments ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasPayments ? 'لا يمكن تعديل هذه الفاتورة' : 'الفاتورة معتمدة وليست مسودة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasPayments
                          ? 'توجد ${payments.length} دفعات مسجلة على هذه الفاتورة. لحماية القيود المالية لا يمكن تعديلها أو إعادتها لمسودة قبل تسوية دفعاتها.'
                          : 'التعديل المباشر متاح للفواتير المسودة فقط.\nيمكنك إعادة هذه الفاتورة إلى حالة "مسودة" للبدء في تعديل بنودها ومبالغها.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    if (!hasPayments) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('إعادة إلى مسودة والبدء في التعديل'),
                        onPressed: () async {
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
                                  'سيتم تحويل الفاتورة رقم ${invoice.number} إلى "مسودة" لتتمكن من تعديلها.\n\nتنبيه: لن تُحتسب الفاتورة ضمن مديونية العميل حتى يعاد اعتمادها.\n\nهل ترغب في المتابعة؟',
                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('تراجع', style: TextStyle(color: AppColors.muted)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('نعم، إعادة وتعديل'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            final repo = ref.read(invoiceRepositoryProvider);
                            await repo.updateInvoiceStatus(invoice.id, InvoiceStatus.draft);
                            ref.invalidate(invoiceByIdProvider(invoice.id));
                            ref.invalidate(invoiceRemainingProvider(invoice.id));
                            ref.invalidate(invoicesListProvider);
                            ref.invalidate(clientInvoicesProvider(invoice.clientId));
                            ref.invalidate(clientBalanceProvider(invoice.clientId));
                            if (context.mounted) {
                              AppSnackBar.showSuccess(context, 'تمت إعادة الفاتورة إلى مسودة، يمكنك التعديل الآن');
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (!_isInitialized && activeClientsAsync.hasValue && items != null) {
        _initFromInvoice(invoice, items, activeClientsAsync.value!);
      }
    } else if (isDuplicating) {
      final duplicateAsync = ref.watch(invoiceByIdProvider(widget.duplicateFromInvoiceId!));
      final duplicateItemsAsync = ref.watch(invoiceItemsProvider(widget.duplicateFromInvoiceId!));

      if (duplicateAsync.isLoading || duplicateItemsAsync.isLoading) {
        return const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      final dupInvoice = duplicateAsync.value;
      final dupItems = duplicateItemsAsync.value;

      if (!_isInitialized && activeClientsAsync.hasValue && dupInvoice != null && dupItems != null) {
        _initFromInvoice(dupInvoice, dupItems, activeClientsAsync.value!, isDuplicating: true);
      }
    }

    final showFxRate = _selectedClient != null && _invoiceCurrency != _selectedClient!.accountCurrency;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldLeave = await showConfirmDialog(
            context,
            title: 'مغادرة النموذج؟',
            message: 'لديك بيانات غير محفوظة في الفاتورة. هل أنت متأكد من رغبتك في المغادرة وإلغاء البيانات المدخلة؟',
            confirmLabel: 'نعم، مغادرة',
            cancelLabel: 'البقاء ومتابعة التحرير',
            isDestructive: true,
            icon: Icons.warning_amber_rounded,
          );
          if (shouldLeave == true && context.mounted) {
            _canExitWithoutConfirm = true;
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing
              ? 'تعديل الفاتورة'
              : (isDuplicating ? 'نسخ الفاتورة (مسودة جديدة)' : 'إنشاء فاتورة جديدة')),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
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
                          Client? currentClient;
                          if (_selectedClient != null) {
                            try {
                              currentClient = clients.firstWhere((c) => c.id == _selectedClient!.id);
                            } catch (_) {
                              currentClient = null;
                            }
                          } else if (widget.initialClientId != null && !isEditing && !isDuplicating) {
                            try {
                              currentClient = clients.firstWhere((c) => c.id == widget.initialClientId);
                              _selectedClient = currentClient;
                              _invoiceCurrency = currentClient.accountCurrency;
                            } catch (_) {
                              currentClient = null;
                            }
                          }

                          return DropdownButtonFormField<Client>(
                            initialValue: currentClient,
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
                            onChanged: isEditing
                                ? null
                                : (client) {
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
                                  decoration: InputDecoration(
                                    labelText: 'وصف البند *',
                                    hintText: 'أو اختر من دليل الأصناف...',
                                    border: const UnderlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.playlist_add_rounded, color: AppColors.accent),
                                      tooltip: 'اختيار من دليل الأصناف',
                                      onPressed: () => _pickProductForItem(row),
                                    ),
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
                              const SizedBox(width: 10),

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
                                    if (d == null || d <= 0) {
                                      return 'أكبر من 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: row.costController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'سعر التكلفة للوحدة (خاص بالأرباح - اختياري)',
                                    hintText: '0.00',
                                    helperText: 'سري لحساب أرباحك، لا يظهر للعميل في الفاتورة والـ PDF',
                                    helperStyle: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700),
                                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                                    suffixText: _invoiceCurrency,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
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
              const SizedBox(height: 16),

              // Discount and Tax Card
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, size: 20, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            'الخصم والضريبة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Discount row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: _isDiscountPercent ? 'نسبة الخصم (%)' : 'مبلغ الخصم ($_invoiceCurrency)',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.discount_outlined),
                                hintText: _isDiscountPercent ? 'مثال: 10' : 'مثال: 50.00',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('مبلغ'),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('%'),
                                ),
                              ],
                              selected: {_isDiscountPercent},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _isDiscountPercent = val.first;
                                });
                              },
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tax row
                      TextFormField(
                        controller: _taxPercentController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'نسبة ضريبة القيمة المضافة (%)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                          hintText: 'مثال: 15 (0 تعني بدون ضريبة)',
                        ),
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: _feesController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'رسوم/عمولة العملية عليك (البنك أو التحويل)',
                          hintText: 'مثال: 1.50',
                          helperText: 'تُخصم من صافي أرباحك الشخصية ولا تُضاف على الفاتورة',
                          prefixIcon: const Icon(Icons.credit_card_outlined),
                          suffixText: _invoiceCurrency,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Grand Total Card
              Card(
                color: AppColors.accent.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المجموع الفرعي:',
                            style: TextStyle(fontSize: 15, color: AppColors.muted),
                          ),
                          Text(
                            formatMoney(_subtotalMinor, _invoiceCurrency),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_discountMinor > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isDiscountPercent
                                  ? 'الخصم (${_discountController.text.trim()}%):'
                                  : 'الخصم:',
                              style: const TextStyle(fontSize: 14, color: Colors.red),
                            ),
                            Text(
                              '- ${formatMoney(_discountMinor, _invoiceCurrency)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                      if (_taxMinor > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الضريبة (${_taxPercentController.text.trim()}%):',
                              style: const TextStyle(fontSize: 14, color: AppColors.muted),
                            ),
                            Text(
                              '+ ${formatMoney(_taxMinor, _invoiceCurrency)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Profit Preview Card
              if (_totalCostMinor > 0 || _transactionFeesMinor > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _estimatedProfitMinor >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _estimatedProfitMinor >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _estimatedProfitMinor >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            color: _estimatedProfitMinor >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تحليل الأرباح التقديرية (سري خاص بك):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _estimatedProfitMinor >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'سري • لن يظهر بالـ PDF',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _transactionFeesMinor > 0
                                ? 'التكلفة: ${formatMoney(_totalCostMinor, _invoiceCurrency)} + رسوم: ${formatMoney(_transactionFeesMinor, _invoiceCurrency)}'
                                : 'التكلفة: ${formatMoney(_totalCostMinor, _invoiceCurrency)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          Text(
                            _totalMinor > 0
                                ? 'صافي الربح: ${formatMoney(_estimatedProfitMinor, _invoiceCurrency)} (${((_estimatedProfitMinor / _totalMinor) * 100).toStringAsFixed(1)}%)'
                                : 'صافي الربح: ${formatMoney(_estimatedProfitMinor, _invoiceCurrency)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _estimatedProfitMinor >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _saveInvoice(targetStatus: InvoiceStatus.draft),
                    icon: const Icon(Icons.drafts_outlined, size: 20),
                    label: const Text(
                      'حفظ كمسودة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveInvoice(targetStatus: InvoiceStatus.sent),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      isEditing ? 'حفظ واعتماد' : 'حفظ واعتماد',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _ProductPickerModal extends ConsumerStatefulWidget {
  final String currency;
  final ValueChanged<Product> onSelected;

  const _ProductPickerModal({
    required this.currency,
    required this.onSelected,
  });

  @override
  ConsumerState<_ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends ConsumerState<_ProductPickerModal> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppColors.accent),
                    SizedBox(width: 8),
                    Text(
                      'اختر صنفاً من الدليل',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الكود...',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
                data: (products) {
                  final filtered = _search.isEmpty
                      ? products
                      : products.where((p) {
                          final nameMatches = p.name.toLowerCase().contains(_search);
                          final codeMatches = p.code?.toLowerCase().contains(_search) ?? false;
                          return nameMatches || codeMatches;
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.muted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _search.isEmpty ? 'لا توجد أصناف في الدليل حالياً' : 'لا توجد أصناف مطابقة للبحث',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يمكنك إضافة أصنافك إلى الدليل لتسهيل اختيارها لاحقاً.',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final profitMinor = p.defaultPriceMinor - p.defaultCostMinor;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                          child: const Icon(Icons.inventory_2_rounded, color: AppColors.accent, size: 18),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            if (p.code != null && p.code!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(p.code!, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          p.defaultCostMinor > 0
                              ? 'سعر البيع: ${formatMoney(p.defaultPriceMinor, widget.currency)} • التكلفة: ${formatMoney(p.defaultCostMinor, widget.currency)}'
                              : 'سعر البيع: ${formatMoney(p.defaultPriceMinor, widget.currency)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        trailing: profitMinor > 0
                            ? Text(
                                '+ ${formatMoney(profitMinor, widget.currency)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              )
                            : null,
                        onTap: () {
                          widget.onSelected(p);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
