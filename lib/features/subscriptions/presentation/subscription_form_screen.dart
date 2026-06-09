import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/subscriptions/application/subscription_providers.dart';
import 'package:fawatir/features/subscriptions/data/subscription_repository.dart';

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  final int clientId;
  final int? subscriptionId;
  const SubscriptionFormScreen({
    super.key,
    required this.clientId,
    this.subscriptionId,
  });

  @override
  ConsumerState<SubscriptionFormScreen> createState() =>
      _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedCurrency = 'USD';
  int _selectedBillingDay = 1;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البدء'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final priceMinor = parseToMinor(_priceController.text);
    if (priceMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال سعر صحيح أكبر من الصفر'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final isEditing = widget.subscriptionId != null;

    final companion = SubscriptionsCompanion(
      id: isEditing ? Value(widget.subscriptionId!) : const Value.absent(),
      clientId: Value(widget.clientId),
      title: Value(_titleController.text.trim()),
      unitPriceMinor: Value(priceMinor),
      currency: Value(_selectedCurrency),
      billingDayOfMonth: Value(_selectedBillingDay),
      startDate: Value(_startDate),
      endDate: Value(_endDate),
      isActive: Value(_isActive),
    );

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      if (isEditing) {
        await repo.updateSubscription(companion);
      } else {
        await repo.addSubscription(companion);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'تم تحديث الاشتراك بنجاح' : 'تم إضافة الاشتراك بنجاح'),
            backgroundColor: AppColors.accent,
          ),
        );
        context.go('/clients/${widget.clientId}/subscriptions');
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
    final isEditing = widget.subscriptionId != null;

    // Load client to get default currency
    final clientAsync = ref.watch(clientByIdProvider(widget.clientId));
    if (!_initialized && !isEditing && clientAsync is AsyncData<Client?>) {
      final client = clientAsync.value;
      if (client != null) {
        _selectedCurrency = client.accountCurrency;
        _initialized = true;
      }
    }

    // Load subscription if editing
    final AsyncValue<Subscription?>? subAsyncValue = isEditing
        ? ref.watch(subscriptionByIdProvider(widget.subscriptionId!))
        : null;

    if (isEditing && subAsyncValue is AsyncData<Subscription?>) {
      final sub = subAsyncValue.value;
      if (!_initialized && sub != null) {
        _titleController.text = sub.title;
        _priceController.text = (sub.unitPriceMinor / 100).toStringAsFixed(2);
        _selectedCurrency = sub.currency;
        _selectedBillingDay = sub.billingDayOfMonth;
        _startDate = sub.startDate;
        _endDate = sub.endDate;
        _isActive = sub.isActive;
        _initialized = true;
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الاشتراك' : 'إضافة اشتراك جديد'),
          actions: [
            _isSaving
                ? const Padding(
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
                : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _saveForm,
                  ),
          ],
        ),
        body: isEditing && subAsyncValue != null
            ? subAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ في تحميل الاشتراك: $err')),
                data: (sub) {
                  if (sub == null) {
                    return const Center(child: Text('الاشتراك غير موجود'));
                  }
                  return _buildForm();
                },
              )
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان الاشتراك *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال عنوان الاشتراك';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر الاشتراك *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال السعر';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'العملة',
                    border: OutlineInputBorder(),
                  ),
                  items: currencySymbols.keys.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCurrency = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedBillingDay,
            decoration: const InputDecoration(
              labelText: 'يوم الفوترة من كل شهر *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: List.generate(28, (i) => i + 1).map((int day) {
              return DropdownMenuItem<int>(
                value: day,
                child: Text('يوم $day'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedBillingDay = val;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectStartDate(context),
            child: IgnorePointer(
              child: TextFormField(
                controller: TextEditingController(text: _formatDate(_startDate)),
                decoration: const InputDecoration(
                  labelText: 'تاريخ البدء *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.date_range),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectEndDate(context),
            child: IgnorePointer(
              child: TextFormField(
                controller: TextEditingController(
                  text: _endDate == null ? 'غير محدد' : _formatDate(_endDate!),
                ),
                decoration: InputDecoration(
                  labelText: 'تاريخ الانتهاء (اختياري)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.date_range),
                  suffixIcon: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _endDate = null;
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('نشط'),
            subtitle: const Text('تشغيل الاشتراك التلقائي للعميل'),
            value: _isActive,
            activeThumbColor: AppColors.accent,
            onChanged: (val) {
              setState(() {
                _isActive = val;
              });
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
