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

  // Orders
  Future<List<ShopOrder>> orders() async {
    final data = await _remote.orders() as Map<String, dynamic>;
    return _items(data).map((item) => ShopOrder.fromJson(item)).toList();
  }

  Future<ShopOrder> order(String id) async {
    final data = await _remote.order(id) as Map<String, dynamic>;
    return ShopOrder.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<ShopOrder> createOrder({
    required String deliveryAddressId,
    required String paymentMethod,
    String? customerNotes,
  }) async {
    final data = await _remote.createOrder(
      deliveryAddressId: deliveryAddressId,
      paymentMethod: paymentMethod,
      customerNotes: customerNotes,
    ) as Map<String, dynamic>;
    return ShopOrder.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<ShopOrder> cancelOrder(String id, {String? reason}) async {
    final data = await _remote.cancelOrder(id, reason: reason) as Map<String, dynamic>;
    return ShopOrder.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  // Delivery Addresses
  Future<List<ShopAddress>> addresses() async {
    final data = await _remote.addresses() as Map<String, dynamic>;
    return _items(data).map((item) => ShopAddress.fromJson(item)).toList();
  }

  Future<ShopAddress> createAddress(ShopAddress address) async {
    final data = await _remote.createAddress(address.toJson()) as Map<String, dynamic>;
    return ShopAddress.fromJson(Map<String, dynamic>.from(data['address'] as Map));
  }

  Future<ShopAddress> updateAddress(String id, Map<String, dynamic> patch) async {
    final data = await _remote.updateAddress(id, patch) as Map<String, dynamic>;
    return ShopAddress.fromJson(Map<String, dynamic>.from(data['address'] as Map));
  }

  Future<void> deleteAddress(String id) async => _remote.deleteAddress(id);
  Future<void> setDefaultAddress(String id) async => _remote.setDefaultAddress(id);

  // Reviews
  Future<ShopReviewSummary> reviews(String productId) async {
    final data = await _remote.reviews(productId) as Map<String, dynamic>;
    return ShopReviewSummary.fromJson(data);
  }

  Future<void> addReview(
    String productId, {
    required int rating,
    String? title,
    String? comment,
  }) async {
    await _remote.addReview(
      productId,
      rating: rating,
      title: title,
      comment: comment,
    );
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
}
