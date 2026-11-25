import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/models/shop_models.dart';
import '../../data/repositories/shop_repository.dart';

final shopCategoriesProvider = FutureProvider<List<ShopCategory>>(
  (ref) => ref.watch(shopRepositoryProvider).categories(),
);
final shopFeaturedProvider = FutureProvider<List<ShopProduct>>(
  (ref) => ref.watch(shopRepositoryProvider).section('featured'),
);
final shopNewArrivalsProvider = FutureProvider<List<ShopProduct>>(
  (ref) => ref.watch(shopRepositoryProvider).section('new-arrivals'),
);
final shopRecommendedProvider = FutureProvider<List<ShopProduct>>(
  (ref) => ref.watch(shopRepositoryProvider).section('recommended'),
);
final shopDealsProvider = FutureProvider<List<ShopProduct>>(
  (ref) async {
    final raw = await ref.watch(shopRepositoryProvider).products({'page': 1, 'limit': 12});
    final all = _products(raw);
    final discounted = all.where((p) => p.discountedPrice != null).toList();
    if (discounted.isNotEmpty) return discounted;
    return all.take(6).toList();
  },
);
final shopProductProvider = FutureProvider.family<ShopProduct, String>(
  (ref, id) => ref.watch(shopRepositoryProvider).product(id),
);

class ShopListingState {
  final List<ShopProduct> items;
  final int page;
  final int total;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<String> brands;
  final Map<String, dynamic> query;
  const ShopListingState({
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.query = const {},
    this.brands = const [],
  });
  bool get hasMore => page < totalPages;
}

class ShopListingNotifier extends Notifier<ShopListingState> {
  int _request = 0;
  @override
  ShopListingState build() => const ShopListingState();

  Future<void> load(Map<String, dynamic> filters) async {
    final request = ++_request;
    state = ShopListingState(isLoading: true, query: Map.of(filters));
    try {
      final result = await ref.read(shopRepositoryProvider).products({
        ...filters,
        'page': 1,
        'limit': 20,
      });
      if (request != _request) return;
      state = ShopListingState(
        items: _products(result),
        page: (result['page'] as num?)?.toInt() ?? 1,
        total: (result['total'] as num?)?.toInt() ?? 0,
        totalPages: (result['totalPages'] as num?)?.toInt() ?? 0,
        brands: (result['brands'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        query: Map.of(filters),
      );
    } catch (error) {
      if (request == _request) {
        state = ShopListingState(
          error: _message(error),
          query: Map.of(filters),
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final request = _request;
    final nextPage = state.page + 1;
    state = ShopListingState(
      items: state.items,
      page: state.page,
      total: state.total,
      totalPages: state.totalPages,
      isLoadingMore: true,
      query: state.query,
    );
    try {
      final result = await ref.read(shopRepositoryProvider).products({
        ...state.query,
        'page': nextPage,
        'limit': 20,
      });
      if (request != _request) return;
      state = ShopListingState(
        items: [...state.items, ..._products(result)],
        page: nextPage,
        total: state.total,
        totalPages: state.totalPages,
        brands: state.brands,
        query: state.query,
      );
    } catch (error) {
      if (request == _request) {
        state = ShopListingState(
          items: state.items,
          page: state.page,
          total: state.total,
          totalPages: state.totalPages,
          brands: state.brands,
          error: _message(error),
          query: state.query,
        );
      }
    }
  }
}

final shopListingProvider =
    NotifierProvider<ShopListingNotifier, ShopListingState>(
      ShopListingNotifier.new,
    );

List<ShopProduct> _products(Map<String, dynamic> data) =>
    (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShopProduct.fromJson(Map<String, dynamic>.from(item)))
        .toList();
String _message(Object error) => error is AppException
    ? error.message
    : 'Unable to load shop data. Please try again.';

class ShopCartState {
  final List<ShopCartLine> items;
  final bool loading;
  final String? error;
  final double subtotal;
  final int totalQuantity;
  const ShopCartState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.subtotal = 0,
    this.totalQuantity = 0,
  });

  int get totalCount => totalQuantity > 0
      ? totalQuantity
      : items.fold(0, (sum, i) => sum + i.quantity);
}

class ShopCartNotifier extends Notifier<ShopCartState> {
  @override
  ShopCartState build() => const ShopCartState();
  Future<void> load() async {
    state = const ShopCartState(loading: true);
    try {
      _setCart(await ref.read(shopRepositoryProvider).cart());
    } catch (error) {
      state = ShopCartState(error: _message(error));
    }
  }

  void _setCart(Map<String, dynamic> data) {
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => ShopCartLine.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    state = ShopCartState(
      items: items,
      subtotal: _number(data['subtotal']),
      totalQuantity: (data['totalQuantity'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> add(
    String productId, {
    String? variantId,
    int quantity = 1,
  }) async {
    await ref
        .read(shopRepositoryProvider)
        .addCart(productId, quantity, variantId: variantId);
    await load();
  }

  Future<void> update(String id, int quantity) async {
    await ref.read(shopRepositoryProvider).updateCart(id, quantity);
    await load();
  }

  Future<void> updateQuantity(String id, int quantity) => update(id, quantity);

  Future<void> remove(String id) async {
    await ref.read(shopRepositoryProvider).removeCart(id);
    await load();
  }

  Future<void> clear() async {
    await ref.read(shopRepositoryProvider).clearCart();
    await load();
  }
}

final shopCartProvider = NotifierProvider<ShopCartNotifier, ShopCartState>(
  ShopCartNotifier.new,
);

class ShopWishlistState {
  final List<ShopWishlistLine> items;
  final bool loading;
  final String? error;
  const ShopWishlistState({
    this.items = const [],
    this.loading = false,
    this.error,
  });
  bool contains(String productId) =>
      items.any((item) => item.product.id == productId);
}

class ShopWishlistNotifier extends Notifier<ShopWishlistState> {
  @override
  ShopWishlistState build() => const ShopWishlistState();
  Future<void> load() async {
    state = const ShopWishlistState(loading: true);
    try {
      final data = await ref.read(shopRepositoryProvider).wishlist();
      state = ShopWishlistState(
        items: (data['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (row) =>
                  ShopWishlistLine.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (error) {
      state = ShopWishlistState(error: _message(error));
    }
  }

  Future<void> add(String productId) async {
    await ref.read(shopRepositoryProvider).addWishlist(productId);
    await load();
  }

  Future<void> remove(String itemId) async {
    await ref.read(shopRepositoryProvider).removeWishlist(itemId);
    await load();
  }
}

final shopWishlistProvider =
    NotifierProvider<ShopWishlistNotifier, ShopWishlistState>(
      ShopWishlistNotifier.new,
    );

// Addresses Provider & Notifier
class ShopAddressesState {
  final List<ShopAddress> items;
  final bool isLoading;
  final String? error;

  const ShopAddressesState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ShopAddress? get defaultAddress => items.firstWhere(
    (a) => a.isDefault,
    orElse: () =>
        items.firstOrNull ??
        const ShopAddress(
          id: '',
          fullName: '',
          phoneNumber: '',
          addressLine1: '',
          city: '',
          province: '',
        ),
  );
}

class ShopAddressesNotifier extends Notifier<ShopAddressesState> {
  @override
  ShopAddressesState build() => const ShopAddressesState();

  Future<void> load() async {
    state = ShopAddressesState(items: state.items, isLoading: true);
    try {
      final items = await ref.read(shopRepositoryProvider).addresses();
      state = ShopAddressesState(items: items);
    } catch (e) {
      state = ShopAddressesState(items: state.items, error: _message(e));
    }
  }

  Future<ShopAddress?> add(ShopAddress address) async {
    try {
      final created = await ref
          .read(shopRepositoryProvider)
          .createAddress(address);
      await load();
      return created;
    } catch (e) {
      state = ShopAddressesState(items: state.items, error: _message(e));
      return null;
    }
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    try {
      await ref.read(shopRepositoryProvider).updateAddress(id, patch);
      await load();
    } catch (e) {
      state = ShopAddressesState(items: state.items, error: _message(e));
    }
  }

  Future<void> delete(String id) async {
    try {
      await ref.read(shopRepositoryProvider).deleteAddress(id);
      await load();
    } catch (e) {
      state = ShopAddressesState(items: state.items, error: _message(e));
    }
  }

  Future<void> setDefault(String id) async {
    try {
      await ref.read(shopRepositoryProvider).setDefaultAddress(id);
      await load();
    } catch (e) {
      state = ShopAddressesState(items: state.items, error: _message(e));
    }
  }
}

final shopAddressesProvider =
    NotifierProvider<ShopAddressesNotifier, ShopAddressesState>(
      ShopAddressesNotifier.new,
    );

// Orders Provider & Notifier
class ShopOrdersState {
  final List<ShopOrder> items;
  final bool isLoading;
  final bool isPlacingOrder;
  final String? error;

  const ShopOrdersState({
    this.items = const [],
    this.isLoading = false,
    this.isPlacingOrder = false,
    this.error,
  });
}

class ShopOrdersNotifier extends Notifier<ShopOrdersState> {
  @override
  ShopOrdersState build() => const ShopOrdersState();

  Future<void> load() async {
    state = ShopOrdersState(items: state.items, isLoading: true);
    try {
      final items = await ref.read(shopRepositoryProvider).orders();
      state = ShopOrdersState(items: items);
    } catch (e) {
      state = ShopOrdersState(items: state.items, error: _message(e));
    }
  }

  Future<ShopOrder?> placeOrder({
    required String deliveryAddressId,
    required String paymentMethod,
    String? customerNotes,
  }) async {
    state = ShopOrdersState(items: state.items, isPlacingOrder: true);
    try {
      final order = await ref
          .read(shopRepositoryProvider)
          .createOrder(
            deliveryAddressId: deliveryAddressId,
            paymentMethod: paymentMethod,
            customerNotes: customerNotes,
          );
      // Refresh cart and orders list
      ref.invalidate(shopCartProvider);
      await load();
      return order;
    } catch (e) {
      state = ShopOrdersState(items: state.items, error: _message(e));
      return null;
    }
  }

  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    try {
      await ref
          .read(shopRepositoryProvider)
          .cancelOrder(orderId, reason: reason);
      await load();
      return true;
    } catch (e) {
      state = ShopOrdersState(items: state.items, error: _message(e));
      return false;
    }
  }
}

final shopOrdersProvider =
    NotifierProvider<ShopOrdersNotifier, ShopOrdersState>(
      ShopOrdersNotifier.new,
    );

final shopOrderDetailProvider = FutureProvider.family<ShopOrder, String>((
  ref,
  id,
) {
  return ref.watch(shopRepositoryProvider).order(id);
});

final shopProductReviewsProvider =
    FutureProvider.family<ShopReviewSummary, String>((ref, id) {
      return ref.watch(shopRepositoryProvider).reviews(id);
    });

double _number(dynamic value) => value == null
    ? 0
    : (value as num?)?.toDouble() ?? double.tryParse(value.toString()) ?? 0;
