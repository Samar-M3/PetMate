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
  final bool? featured;

  const ShopListingPage({
    super.key,
    this.categoryId,
    this.categoryName,
    this.search,
    this.featured,
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

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopListingProvider.notifier).load(_filters);
      _loadRecent();
      if (ref.read(authStateProvider).isAuthenticated) {
        ref.read(shopWishlistProvider.notifier).load();
        ref.read(shopCartProvider.notifier).load();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(shopListingProvider.notifier).loadMore();
    }
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
    _debounce = Timer(const Duration(milliseconds: 350), () {
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
    final updated = [
      value,
      ..._recent.where((item) => item != value),
    ].take(6).toList();
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('shop_recent_searches', updated);
    if (mounted) setState(() => _recent = updated);
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _brand = null;
      _minController.clear();
      _maxController.clear();
      _sort = 'newest';
      _searchController.clear();
    });
    _apply();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_categoryId != null) count++;
    if (_brand != null) count++;
    if (_minController.text.isNotEmpty || _maxController.text.isNotEmpty) {
      count++;
    }
    if (_sort != 'newest') count++;
    return count;
  }

  void _openFilterBottomSheet(
    ShopListingState state,
    List<ShopCategory> categories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter & Sort',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _clearFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              // Category Picker
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (val) {
                  setSheetState(() => _categoryId = val);
                  setState(() => _categoryId = val);
                },
              ),
              const SizedBox(height: 12),
              // Brand Picker
              DropdownButtonFormField<String?>(
                initialValue: _brand,
                decoration: InputDecoration(
                  labelText: 'Brand',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Brands'),
                  ),
                  ...state.brands.map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  ),
                ],
                onChanged: (val) {
                  setSheetState(() => _brand = val);
                  setState(() => _brand = val);
                },
              ),
              const SizedBox(height: 12),
              // Price Range
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Min (NPR)',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max (NPR)',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sort Option
              DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: InputDecoration(
                  labelText: 'Sort By',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'newest',
                    child: Text('Newest Arrivals'),
                  ),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text('Price: Low to High'),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text('Price: High to Low'),
                  ),
                ],
                onChanged: (val) {
                  setSheetState(() => _sort = val ?? 'newest');
                  setState(() => _sort = val ?? 'newest');
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _apply();
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopListingProvider);
    final categoryRoots =
        ref.watch(shopCategoriesProvider).asData?.value ??
        const <ShopCategory>[];
    final categories = categoryRoots.expand((c) => [c, ...c.children]).toList();
    final cartState = ref.watch(shopCartProvider);
    final wishlistState = ref.watch(shopWishlistProvider);

    final title =
        widget.categoryName ??
        (_categoryId != null
            ? categories
                  .firstWhere(
                    (c) => c.id == _categoryId,
                    orElse: () =>
                        ShopCategory(id: '', name: 'Products', slug: ''),
                  )
                  .name
            : widget.search?.isNotEmpty == true
            ? 'Search Results'
            : 'All Products');

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.textPrimary,
                ),
                if (wishlistState.items.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.terracotta,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${wishlistState.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/shop/wishlist'),
          ),
          IconButton(
            tooltip: 'Cart',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.textPrimary,
                ),
                if (cartState.totalCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartState.totalCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/shop/cart'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb Navigation
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              children: [
                InkWell(
                  onTap: () => context.go('/'),
                  child: const Text('Home', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => context.go('/shop'),
                  child: const Text('Shop', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.categoryName ??
                        (widget.search != null ? 'Search: "${widget.search}"' : 'All Products'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintText: 'Search products or brands...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  backgroundColor: AppColors.terracotta,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      side: BorderSide(
                        color: _activeFilterCount > 0
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openFilterBottomSheet(state, categories),
                    icon: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Filter Chips (Recent / Sort)
          if (_recent.isNotEmpty && _searchController.text.isEmpty)
            Container(
              height: 38,
              color: Colors.white,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final term = _recent[index];
                  return ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: AppColors.cream,
                    label: Text(
                      term,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () {
                      _searchController.text = term;
                      _searchChanged(term);
                    },
                  );
                },
              ),
            ),

          // Results Header: Item count & Active filter summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.isLoading
                      ? 'Loading items...'
                      : '${state.total} products found',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_activeFilterCount > 0)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: const Text(
                      'Clear Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main Product Grid
          Expanded(child: _buildProductGrid(state)),
        ],
      ),
    );
  }

  Widget _buildProductGrid(ShopListingState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(shopListingProvider.notifier).load(_filters),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No products found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'We couldn\'t find any items matching your filters or search keywords.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _clearFilters,
                child: const Text('Reset All Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 2 on mobile (< 600px), 3 on tablet, 4+ on desktop
        final width = constraints.maxWidth;
        final int crossAxisCount = width < 600
            ? 2
            : width < 900
            ? 3
            : 4;

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 2 ? 0.58 : 0.60,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: state.items.length + (state.isLoadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return ShopProductCard(product: state.items[index]);
          },
        );
      },
    );
  }
}
