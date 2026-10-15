import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/company/data/company_repository.dart';
import 'package:fawatir/features/products/application/product_providers.dart';
import 'package:fawatir/features/products/data/product_repository.dart';
import 'package:fawatir/shared/widgets/app_snackbar.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _currency = 'USD';
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() => setState(() {}));
    _costController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFromProduct(Product product) {
    if (_isInitialized) return;
    _nameController.text = product.name;
    _codeController.text = product.code ?? '';
    _priceController.text = (product.defaultPriceMinor / 100.0).toStringAsFixed(2);
    _costController.text = (product.defaultCostMinor / 100.0).toStringAsFixed(2);
    _descriptionController.text = product.description ?? '';
    _currency = product.currency;
    _isInitialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(productRepositoryProvider);
      final priceVal = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final costVal = double.tryParse(_costController.text.trim()) ?? 0.0;
      final priceMinor = (priceVal * 100).round();
      final costMinor = (costVal * 100).round();

      if (widget.productId != null) {
        final companion = ProductsCompanion(
          id: Value(widget.productId!),
          name: Value(_nameController.text.trim()),
          code: Value(_codeController.text.trim().isEmpty ? null : _codeController.text.trim()),
          defaultPriceMinor: Value(priceMinor),
          defaultCostMinor: Value(costMinor),
          description: Value(_descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim()),
          currency: Value(_currency),
        );
        await repo.updateProduct(widget.productId!, companion);
        ref.invalidate(productByIdProvider(widget.productId!));
      } else {
        final companion = ProductsCompanion.insert(
          name: _nameController.text.trim(),
          code: Value(_codeController.text.trim().isEmpty ? null : _codeController.text.trim()),
          defaultPriceMinor: Value(priceMinor),
          defaultCostMinor: Value(costMinor),
          description: Value(_descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim()),
          currency: Value(_currency),
        );
        await repo.createProduct(companion);
      }

      ref.invalidate(productsListProvider);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          widget.productId != null ? 'تم تحديث بيانات الصنف بنجاح' : 'تمت إضافة الصنف بنجاح',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'حدث خطأ أثناء الحفظ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;

    if (isEditing) {
      final productAsync = ref.watch(productByIdProvider(widget.productId!));
      if (productAsync.isLoading) {
        return const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      final product = productAsync.value;
      if (product != null) {
        _initFromProduct(product);
      }
    } else if (!_isInitialized) {
      final companyAsync = ref.watch(companyRepositoryProvider).watchCompany();
      companyAsync.first.then((company) {
        if (company != null && mounted && !_isInitialized) {
          setState(() {
            _currency = company.defaultCurrency;
            _isInitialized = true;
          });
        }
      });
    }

    final priceVal = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final costVal = double.tryParse(_costController.text.trim()) ?? 0.0;
    final profitVal = priceVal - costVal;
    final profitMargin = priceVal > 0 ? (profitVal / priceVal) * 100 : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الصنف' : 'إضافة صنف أو خدمة'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بيانات الصنف الأساسية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الصنف أو الخدمة *',
                          hintText: 'مثال: باقة نت شهرية 50 جيجا',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال اسم الصنف أو الخدمة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'كود / رمز الصنف (اختياري)',
                                hintText: 'مثال: NET-50',
                                prefixIcon: Icon(Icons.qr_code),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: const InputDecoration(
                                labelText: 'العملة',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                                DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                                DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
                                DropdownMenuItem(value: 'AED', child: Text('درهم إماراتي (AED)')),
                                DropdownMenuItem(value: 'EGP', child: Text('جنيه مصري (EGP)')),
                                DropdownMenuItem(value: 'EUR', child: Text('يورو (EUR)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _currency = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pricing & Cost Card
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'التسعير وحساب الأرباح',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'سعر البيع للعميل *',
                                hintText: '65.00',
                                suffixText: _currency,
                                prefixIcon: const Icon(Icons.sell_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'مطلوب';
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null || parsed < 0) {
                                  return 'قيمة غير صحيحة';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'سعر التكلفة عليك',
                                hintText: '55.00',
                                suffixText: _currency,
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final parsed = double.tryParse(value.trim());
                                  if (parsed == null || parsed < 0) {
                                    return 'قيمة غير صحيحة';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Interactive Live Profit Preview Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: profitVal >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: profitVal >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: profitVal >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                              child: Icon(
                                profitVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                color: profitVal >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profitVal >= 0 ? 'الربح المتوقع لكل وحدة:' : 'خسارة متوقعة:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: profitVal >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${profitVal.toStringAsFixed(2)} $_currency  (${profitMargin.toStringAsFixed(1)}% هامش ربح)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: profitVal >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Card
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملاحظات وتفاصيل إضافية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'وصف اختياري للصنف أو تفاصيل المزوّد...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  isEditing ? 'حفظ التعديلات' : 'إضافة الصنف للدليل',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
