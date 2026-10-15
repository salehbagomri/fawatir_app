import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/products/data/product_repository.dart';

final productsListProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchActiveProducts();
});

final productSearchQueryProvider = NotifierProvider.autoDispose<ProductSearchNotifier, String>(
  ProductSearchNotifier.new,
);

class ProductSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String val) => super.state = val;
  void setQuery(String val) => state = val;
}

final filteredProductsProvider = Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsListProvider);
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();

  return productsAsync.whenData((products) {
    if (query.isEmpty) return products;
    return products.where((p) {
      final nameMatches = p.name.toLowerCase().contains(query);
      final codeMatches = p.code?.toLowerCase().contains(query) ?? false;
      return nameMatches || codeMatches;
    }).toList();
  });
});

final productByIdProvider = FutureProvider.autoDispose.family<Product?, int>((ref, id) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProductById(id);
});
