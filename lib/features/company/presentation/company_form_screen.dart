import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/company/application/company_providers.dart';
import 'package:fawatir/features/company/data/company_repository.dart';

class CompanyFormScreen extends ConsumerStatefulWidget {
  const CompanyFormScreen({super.key});

  @override
  ConsumerState<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends ConsumerState<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bankDetailsController = TextEditingController();
  final _invoicePrefixController = TextEditingController(text: 'INV-');
  final _invoiceCounterController = TextEditingController(text: '0');

  String _selectedCurrency = 'USD';
  String? _logoPath;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankDetailsController.dispose();
    _invoicePrefixController.dispose();
    _invoiceCounterController.dispose();
    super.dispose();
  }

  void _initializeFields(Company company) {
    _nameController.text = company.name;
    _addressController.text = company.address ?? '';
    _phoneController.text = company.phone ?? '';
    _emailController.text = company.email ?? '';
    _bankDetailsController.text = company.bankDetails ?? '';
    _invoicePrefixController.text = company.invoicePrefix;
    _invoiceCounterController.text = company.invoiceCounter.toString();
    _selectedCurrency = company.defaultCurrency;
    _logoPath = company.logoPath;
    _initialized = true;
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final savedFile = await file.copy('${appDir.path}/$fileName');
        setState(() {
          _logoPath = savedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء اختيار الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final companion = CompaniesCompanion(
      name: Value(_nameController.text.trim()),
      logoPath: Value(_logoPath),
      address: Value(_addressController.text.trim().isEmpty ? null : _addressController.text.trim()),
      phone: Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
      email: Value(_emailController.text.trim().isEmpty ? null : _emailController.text.trim()),
      bankDetails: Value(_bankDetailsController.text.trim().isEmpty ? null : _bankDetailsController.text.trim()),
      defaultCurrency: Value(_selectedCurrency),
      invoicePrefix: Value(_invoicePrefixController.text.trim()),
      invoiceCounter: Value(int.tryParse(_invoiceCounterController.text.trim()) ?? 0),
    );

    try {
      await ref.read(companyRepositoryProvider).saveCompany(companion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ بيانات الشركة بنجاح'),
            backgroundColor: AppColors.accent,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
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
    final companyAsync = ref.watch(companyStreamProvider);

    if (!_initialized && companyAsync is AsyncData) {
      final company = companyAsync.value;
      if (company != null) {
        _initializeFields(company);
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بيانات الشركة'),
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
        body: companyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('خطأ في تحميل البيانات: $err')),
          data: (company) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // الشعار
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.zebra,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: AppColors.line, width: 2),
                          ),
                          child: _logoPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14.0),
                                  child: Image.file(
                                    File(_logoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(child: Icon(Icons.broken_image, size: 40)),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.business,
                                    size: 50,
                                    color: AppColors.muted,
                                  ),
                                ),
                        ),
                        CircleAvatar(
                          backgroundColor: AppColors.accent,
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.add_a_photo, size: 18, color: Colors.white),
                            onPressed: _pickLogo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // اسم الشركة
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الشركة *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_center),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم الشركة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // الهاتف والعنوان
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'الهاتف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                      ),
                    ],
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

                  // العملة الافتراضية
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'العملة الافتراضية للفواتير',
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

                  // بادئة الفواتير والعداد
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _invoicePrefixController,
                          decoration: const InputDecoration(
                            labelText: 'بادئة الفواتير',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال بادئة الفواتير';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceCounterController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عداد البداية الفواتير',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال رقم العداد';
                            }
                            if (int.tryParse(val) == null) {
                              return 'يجب إدخال رقم صحيح';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // بيانات التحويل البنكي
                  TextFormField(
                    controller: _bankDetailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'بيانات التحويل البنكي',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
