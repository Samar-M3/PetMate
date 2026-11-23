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

  // Orders
  Future<dynamic> orders() => _api.get('/shop/orders');
  Future<dynamic> order(String id) => _api.get('/shop/orders/$id');
  Future<dynamic> createOrder({
    required String deliveryAddressId,
    required String paymentMethod,
    String? customerNotes,
  }) =>
      _api.post(
        '/shop/orders',
        body: {
          'deliveryAddressId': deliveryAddressId,
          'paymentMethod': paymentMethod,
          if (customerNotes != null && customerNotes.isNotEmpty)
            'customerNotes': customerNotes,
        },
      );
  Future<dynamic> cancelOrder(String id, {String? reason}) =>
      _api.patch('/shop/orders/$id/cancel', body: {'reason': reason});

  // Delivery Addresses
  Future<dynamic> addresses() => _api.get('/shop/addresses');
  Future<dynamic> createAddress(Map<String, dynamic> data) =>
      _api.post('/shop/addresses', body: data);
  Future<dynamic> updateAddress(String id, Map<String, dynamic> data) =>
      _api.put('/shop/addresses/$id', body: data);
  Future<dynamic> deleteAddress(String id) =>
      _api.delete('/shop/addresses/$id');
  Future<dynamic> setDefaultAddress(String id) =>
      _api.patch('/shop/addresses/$id/default');

  // Reviews
  Future<dynamic> reviews(String productId) =>
      _api.get('/shop/products/$productId/reviews');
  Future<dynamic> addReview(
    String productId, {
    required int rating,
    String? title,
    String? comment,
  }) =>
      _api.post(
        '/shop/products/$productId/reviews',
        body: {
          'rating': rating,
          if (title != null && title.isNotEmpty) 'title': title,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
}
