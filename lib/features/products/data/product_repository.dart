import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';

class ProductRepository {
  final AppDatabase _db;

  ProductRepository(this._db);

  Stream<List<Product>> watchActiveProducts() {
    return (_db.select(_db.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm(expression: p.name, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<List<Product>> getActiveProducts() {
    return (_db.select(_db.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm(expression: p.name, mode: OrderingMode.asc)]))
        .get();
  }

  Future<Product?> getProductById(int id) {
    return (_db.select(_db.products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<int> createProduct(ProductsCompanion product) {
    return _db.into(_db.products).insert(product);
  }

  Future<bool> updateProduct(int id, ProductsCompanion product) {
    return (_db.update(_db.products)..where((p) => p.id.equals(id))).write(product).then((rows) => rows > 0);
  }

  Future<int> deleteProduct(int id) {
    return (_db.delete(_db.products)..where((p) => p.id.equals(id))).go();
  }
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(databaseProvider)),
);
