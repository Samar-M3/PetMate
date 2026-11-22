import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopListingPage extends ConsumerStatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final String? search;
  const ShopListingPage({
    super.key,
    this.categoryId,
    this.categoryName,
    this.search,
  });
  @override
  ConsumerState<ShopListingPage> createState() => _ShopListingPageState();
}

class _ShopListingPageState extends ConsumerState<ShopListingPage> {
  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  late Map<String, dynamic> _filters;
  List<String> _recent = [];
  String? _brand;
  String _sort = 'newest';
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    if (widget.search != null) _searchController.text = widget.search!;
    _filters = _query();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopListingProvider.notifier).load(_filters);
      _loadRecent();
      if (ref.read(authStateProvider).isAuthenticated) {
        ref.read(shopWishlistProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _query() => {
    if (_categoryId != null) 'categoryId': _categoryId,
    if (_searchController.text.trim().isNotEmpty)
      'search': _searchController.text.trim(),
    if (_brand != null) 'brand': _brand,
    if (_minController.text.trim().isNotEmpty)
      'minPrice': _minController.text.trim(),
    if (_maxController.text.trim().isNotEmpty)
      'maxPrice': _maxController.text.trim(),
    'sortBy': _sort,
  };

  void _apply() {
    setState(() => _filters = _query());
    ref.read(shopListingProvider.notifier).load(_filters);
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _apply();
      if (value.trim().isNotEmpty) _saveRecent(value.trim());
    });
  }

  Future<void> _loadRecent() async {
    final values =
        ref
            .read(sharedPreferencesProvider)
            .getStringList('shop_recent_searches') ??
        [];
    if (mounted) setState(() => _recent = values);
  }

  Future<void> _saveRecent(String value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final list = [
      value,
      ...(prefs.getStringList('shop_recent_searches') ?? []).where(
        (item) => item.toLowerCase() != value.toLowerCase(),
      ),
    ].take(8).toList();
    await prefs.setStringList('shop_recent_searches', list);
    if (mounted) setState(() => _recent = list);
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _brand = null;
      _sort = 'newest';
      _minController.clear();
      _maxController.clear();
    });
    _apply();
  }

  void _openFilters(ShopListingState state, List<ShopCategory> categories) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                _filterControls(state, categories),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _apply();
                  },
                  child: const Text('Apply filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterControls(
    ShopListingState state,
    List<ShopCategory> categories,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String?>(
        initialValue: _categoryId,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All categories'),
          ),
          ...categories.map(
            (category) => DropdownMenuItem<String?>(
              value: category.id,
              child: Text(category.name),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _categoryId = value),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String?>(
        initialValue: _brand,
        decoration: const InputDecoration(labelText: 'Brand'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All brands'),
          ),
          ...state.brands.map(
            (brand) =>
                DropdownMenuItem<String?>(value: brand, child: Text(brand)),
          ),
        ],
        onChanged: (value) => setState(() => _brand = value),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min price'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max price'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _sort,
        decoration: const InputDecoration(labelText: 'Sort by'),
        items: const [
          DropdownMenuItem(value: 'newest', child: Text('Newest first')),
          DropdownMenuItem(
            value: 'price_asc',
            child: Text('Price: low to high'),
          ),
          DropdownMenuItem(
            value: 'price_desc',
            child: Text('Price: high to low'),
          ),
        ],
        onChanged: (value) => setState(() => _sort = value ?? 'newest'),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _clearFilters,
          child: const Text('Clear filters'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopListingProvider);
    final categoryRoots =
        ref.watch(shopCategoriesProvider).asData?.value ??
        const <ShopCategory>[];
    final categories = categoryRoots
        .expand((category) => [category, ...category.children])
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName ??
              (widget.search?.isNotEmpty == true
                  ? 'Search results'
                  : 'All products'),
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => context.push('/shop/wishlist'),
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/shop/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search products, brands, categories',
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    _searchChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          if (_recent.isNotEmpty && _searchController.text.isEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _recent
                    .map(
                      (term) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(term),
                          onPressed: () {
                            _searchController.text = term;
                            _searchChanged(term);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide)
                  SizedBox(
                    width: 280,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _filterControls(state, categories),
                          ElevatedButton(
                            onPressed: _apply,
                            child: const Text('Apply filters'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: _results(state, wide, categories)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openFilters(state, categories),
              icon: const Icon(Icons.tune),
              label: const Text('Filters'),
            ),
    );
  }

  Widget _results(
    ShopListingState state,
    bool wide,
    List<ShopCategory> categories,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            TextButton(
              onPressed: () =>
                  ref.read(shopListingProvider.notifier).load(_filters),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(
        child: Text('No products match your search or filters.'),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final maxExtent = width > 1200
        ? 250.0
        : width > 700
        ? 220.0
        : 190.0;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_categoryId != null)
              Chip(
                label: Text(
                  categories
                          .where((item) => item.id == _categoryId)
                          .firstOrNull
                          ?.name ??
                      widget.categoryName ??
                      'Category',
                ),
                onDeleted: () {
                  setState(() => _categoryId = null);
                  _apply();
                },
              ),
            if (_brand != null)
              Chip(
                label: Text(_brand!),
                onDeleted: () {
                  setState(() => _brand = null);
                  _apply();
                },
              ),
            if (_searchController.text.isNotEmpty)
              Chip(
                label: Text('Search: ${_searchController.text}'),
                onDeleted: () {
                  _searchController.clear();
                  _apply();
                },
              ),
            if (_minController.text.isNotEmpty)
              Chip(
                label: Text('Min ${_minController.text}'),
                onDeleted: () {
                  _minController.clear();
                  _apply();
                },
              ),
            if (_maxController.text.isNotEmpty)
              Chip(
                label: Text('Max ${_maxController.text}'),
                onDeleted: () {
                  _maxController.clear();
                  _apply();
                },
              ),
            if (_categoryId != null ||
                _brand != null ||
                _searchController.text.isNotEmpty ||
                _minController.text.isNotEmpty ||
                _maxController.text.isNotEmpty ||
                _sort != 'newest')
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear all'),
              ),
          ],
        ),
        Text(
          '${state.total} products',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisExtent: 390,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) =>
              ShopProductCard(product: state.items[index]),
        ),
        if (state.error != null)
          Center(
            child: Text(
              state.error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.hasMore)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(shopListingProvider.notifier).loadMore(),
                child: const Text('Load more'),
              ),
            ),
          ),
      ],
    );
  }
}
