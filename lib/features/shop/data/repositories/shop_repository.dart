import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/shop_remote_data_source.dart';
import '../models/shop_models.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(ref.watch(shopRemoteDataSourceProvider)),
);

class ShopRepository {
  final ShopRemoteDataSource _remote;
  ShopRepository(this._remote);

  Future<List<ShopCategory>> categories() async {
    final data = await _remote.categories() as Map<String, dynamic>;
    return _items(data).map((item) => ShopCategory.fromJson(item)).toList();
  }

  Future<List<ShopProduct>> section(String path) async {
    final data = await _remote.section(path) as Map<String, dynamic>;
    return _items(data).map((item) => ShopProduct.fromJson(item)).toList();
  }

  Future<ShopProduct> product(String id) async {
    final data = await _remote.product(id) as Map<String, dynamic>;
    return ShopProduct.fromJson(
      Map<String, dynamic>.from(data['product'] as Map),
    );
  }

  Future<Map<String, dynamic>> products(Map<String, dynamic> query) async {
    final data = await _remote.products(query) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> cart() async =>
      await _remote.cart() as Map<String, dynamic>;
  Future<void> addCart(
    String productId,
    int quantity, {
    String? variantId,
  }) async {
    await _remote.addCart(productId, quantity, variantId: variantId);
  }

  Future<void> updateCart(String itemId, int quantity) async {
    await _remote.updateCart(itemId, quantity);
  }

  Future<void> removeCart(String itemId) async => _remote.removeCart(itemId);
  Future<void> clearCart() async => _remote.clearCart();

  Future<Map<String, dynamic>> wishlist() async =>
      await _remote.wishlist() as Map<String, dynamic>;
  Future<void> addWishlist(String productId) async {
    await _remote.addWishlist(productId);
  }

  Future<void> removeWishlist(String itemId) async =>
      _remote.removeWishlist(itemId);

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
}
