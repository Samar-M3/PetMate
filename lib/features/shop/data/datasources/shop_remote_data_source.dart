import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';

final shopRemoteDataSourceProvider = Provider<ShopRemoteDataSource>(
  (ref) => ShopRemoteDataSource(ref.watch(apiClientProvider)),
);

class ShopRemoteDataSource {
  final ApiClient _api;
  ShopRemoteDataSource(this._api);

  Future<dynamic> categories() => _api.get('/shop/categories');
  Future<dynamic> section(String path) =>
      _api.get('/shop/products/$path', queryParameters: {'limit': 8});
  Future<dynamic> product(String id) => _api.get('/shop/products/$id');
  Future<dynamic> products(Map<String, dynamic> query) =>
      _api.get('/shop/products', queryParameters: query);
  Future<dynamic> cart() => _api.get('/shop/cart');
  Future<dynamic> addCart(
    String productId,
    int quantity, {
    String? variantId,
  }) => _api.post(
    '/shop/cart/items',
    body: {
      'productId': productId,
      'quantity': quantity,
      if (variantId case final String selectedVariant)
        'variantId': selectedVariant,
    },
  );
  Future<dynamic> updateCart(String itemId, int quantity) =>
      _api.patch('/shop/cart/items/$itemId', body: {'quantity': quantity});
  Future<dynamic> removeCart(String itemId) =>
      _api.delete('/shop/cart/items/$itemId');
  Future<dynamic> clearCart() => _api.delete('/shop/cart');
  Future<dynamic> wishlist() => _api.get('/shop/wishlist');
  Future<dynamic> addWishlist(String productId) =>
      _api.post('/shop/wishlist/items', body: {'productId': productId});
  Future<dynamic> removeWishlist(String itemId) =>
      _api.delete('/shop/wishlist/items/$itemId');
}
