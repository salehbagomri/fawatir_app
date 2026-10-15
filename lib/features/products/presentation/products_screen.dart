import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/features/products/application/product_providers.dart';
import 'package:fawatir/features/products/data/product_repository.dart';
import 'package:fawatir/shared/widgets/app_snackbar.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دليل الأصناف والخدمات'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة صنف جديد'),
          onPressed: () => context.push('/products/new'),
        ),
        body: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف بالاسم أو الكود...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => ref.read(productSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (val) => ref.read(productSearchQueryProvider.notifier).state = val,
              ),
            ),
            const Divider(height: 1, color: AppColors.line),

            // Products List
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('خطأ في تحميل الأصناف: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded,
                              size: 72,
                              color: AppColors.muted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty ? 'دليل الأصناف فارغ' : 'لا توجد نتائج مطابقة للبحث',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isEmpty
                                  ? 'أضف الأصناف والخدمات التي تقدمها لتسهيل اختيارها بسرعة في الفواتير وحساب أرباحك تلقائياً.'
                                  : 'جرّب البحث باسم أو رمز آخر.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted, height: 1.4),
                            ),
                            if (searchQuery.isEmpty) ...[
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة أول صنف الآن'),
                                onPressed: () => context.push('/products/new'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: products.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final profitMinor = p.defaultPriceMinor - p.defaultCostMinor;
                      final profitMargin = p.defaultPriceMinor > 0
                          ? (profitMinor / p.defaultPriceMinor) * 100
                          : 0.0;

                      return Card(
                        elevation: 0.8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/products/${p.id}/edit'),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.inventory_2_rounded, color: AppColors.accent, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                if (p.code != null && p.code!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueGrey.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.blueGrey.shade200, width: 0.5),
                                                    ),
                                                    child: Text(
                                                      'كود: ${p.code}',
                                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (action) async {
                                        if (action == 'edit') {
                                          context.push('/products/${p.id}/edit');
                                        } else if (action == 'delete') {
                                          final confirmed = await showConfirmDialog(
                                            context,
                                            title: 'حذف الصنف',
                                            message: 'هل أنت متأكد من حذف الصنف "${p.name}"؟',
                                            confirmLabel: 'نعم، حذف',
                                            cancelLabel: 'تراجع',
                                            isDestructive: true,
                                          );
                                          if (confirmed == true && context.mounted) {
                                            await ref.read(productRepositoryProvider).deleteProduct(p.id);
                                            ref.invalidate(productsListProvider);
                                            if (context.mounted) {
                                              AppSnackBar.showSuccess(context, 'تم حذف الصنف بنجاح');
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18, color: AppColors.accent),
                                              SizedBox(width: 8),
                                              Text('تعديل'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('حذف', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (p.description != null && p.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    p.description!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Price breakdown
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'سعر البيع: ${formatMoney(p.defaultPriceMinor, p.currency)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.dark),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'التكلفة: ${formatMoney(p.defaultCostMinor, p.currency)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                    // Profit pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: profitMinor >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: profitMinor >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            profitMinor >= 0 ? Icons.trending_up : Icons.trending_down,
                                            size: 15,
                                            color: profitMinor >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ربح: ${formatMoney(profitMinor, p.currency)} (${profitMargin.toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: profitMinor >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
