import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';
import 'package:fawatir/features/company/application/company_providers.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final int? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCurrency = 'USD';
  bool _isActive = true;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeFields(Client client) {
    _nameController.text = client.name;
    _contactController.text = client.contactPerson ?? '';
    _phoneController.text = client.phone ?? '';
    _addressController.text = client.address ?? '';
    _notesController.text = client.notes ?? '';
    _selectedCurrency = client.accountCurrency;
    _isActive = client.isActive;
    _initialized = true;
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final isEditing = widget.clientId != null;

    final companion = ClientsCompanion(
      id: isEditing ? Value(widget.clientId!) : const Value.absent(),
      name: Value(_nameController.text.trim()),
      contactPerson: Value(_contactController.text.trim().isEmpty ? null : _contactController.text.trim()),
      phone: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
      address: Value(_addressController.text.trim().isEmpty ? null : _addressController.text.trim()),
      notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      accountCurrency: Value(_selectedCurrency),
      isActive: Value(_isActive),
    );

    try {
      final repo = ref.read(clientRepositoryProvider);
      if (isEditing) {
        await repo.updateClient(companion);
      } else {
        await repo.addClient(companion);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'تم تحديث بيانات العميل بنجاح' : 'تم إضافة العميل بنجاح'),
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
    final isEditing = widget.clientId != null;

    // Load defaults
    final companyAsync = ref.watch(companyStreamProvider);
    if (!_initialized && !isEditing && companyAsync is AsyncData) {
      final company = companyAsync.value;
      if (company != null) {
        _selectedCurrency = company.defaultCurrency;
        _initialized = true;
      }
    }

    // Load client if editing (avoiding nullable property warnings by keeping clientAsync local and checking type)
    final AsyncValue<Client?>? clientAsyncValue = isEditing
        ? ref.watch(clientByIdProvider(widget.clientId!))
        : null;

    if (isEditing && clientAsyncValue is AsyncData<Client?>) {
      final client = clientAsyncValue.value;
      if (!_initialized && client != null) {
        _initializeFields(client);
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد'),
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
        body: isEditing && clientAsyncValue != null
            ? clientAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ في تحميل العميل: $err')),
                data: (client) {
                  if (client == null) {
                    return const Center(child: Text('العميل غير موجود'));
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
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم العميل *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال اسم العميل';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactController,
            decoration: const InputDecoration(
              labelText: 'اسم جهة الاتصال / الشخص المسؤول',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.contact_phone),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'عملة الحساب',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monetization_on),
            ),
            items: currencySymbols.keys.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text('$value (${symbolFor(value)})'),
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
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('نشط'),
            subtitle: const Text('تفعيل العميل لإصدار الفواتير له'),
            value: _isActive,
            activeThumbColor: AppColors.accent,
            onChanged: (val) {
              setState(() {
                _isActive = val;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
