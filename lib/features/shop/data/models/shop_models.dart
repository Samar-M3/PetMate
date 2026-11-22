class ShopCategory {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int productCount;
  final List<ShopCategory> children;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.productCount = 0,
    this.children = const [],
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    final products = count is Map ? count['products'] : null;
    return ShopCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      imageUrl: json['imageUrl'] as String?,
      productCount: products is int ? products : 0,
      children: (json['children'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopCategory.fromJson)
          .toList(),
    );
  }
}

class ShopVariant {
  final String id;
  final Map<String, dynamic> options;
  final String optionKey;
  final double? priceOverride;
  final int availableStock;
  final bool isAvailable;

  const ShopVariant({
    required this.id,
    required this.options,
    required this.optionKey,
    this.priceOverride,
    required this.availableStock,
    required this.isAvailable,
  });

  factory ShopVariant.fromJson(Map<String, dynamic> json) => ShopVariant(
    id: json['id']?.toString() ?? '',
    options: Map<String, dynamic>.from(
      json['optionValues'] as Map? ?? const {},
    ),
    optionKey: json['optionKey']?.toString() ?? '',
    priceOverride: _number(json['priceOverride']),
    availableStock: (json['availableStock'] as num?)?.toInt() ?? 0,
    isAvailable: json['isAvailable'] as bool? ?? false,
  );
}

class ShopProduct {
  final String id;
  final String name;
  final String slug;
  final String? brand;
  final String? description;
  final double basePrice;
  final double? discountedPrice;
  final int? discountPercentage;
  final int availableStock;
  final String status;
  final bool isFeatured;
  final String? categoryName;
  final String? categoryId;
  final String? storeName;
  final String? storeImageUrl;
  final List<String> images;
  final List<ShopVariant> variants;
  final bool? available;
  final String? availabilityReason;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.slug,
    this.brand,
    this.description,
    required this.basePrice,
    this.discountedPrice,
    this.discountPercentage,
    required this.availableStock,
    required this.status,
    required this.isFeatured,
    this.categoryName,
    this.categoryId,
    this.storeName,
    this.storeImageUrl,
    this.images = const [],
    this.variants = const [],
    this.available,
    this.availabilityReason,
  });

  double get displayPrice => discountedPrice ?? basePrice;
  bool get hasStock => variants.isNotEmpty
      ? variants.any(
          (variant) => variant.isAvailable && variant.availableStock > 0,
        )
      : availableStock > 0;

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final store = json['store'] as Map<String, dynamic>?;
    final images = (json['images'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item['imageUrl']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    return ShopProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      basePrice: _number(json['basePrice']) ?? 0,
      discountedPrice: _number(json['discountedPrice']),
      discountPercentage: (json['discountPercentage'] as num?)?.toInt(),
      availableStock: (json['availableStock'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'INACTIVE',
      isFeatured: json['isFeatured'] as bool? ?? false,
      categoryName: category?['name'] as String?,
      categoryId: category?['id'] as String? ?? json['categoryId'] as String?,
      storeName: store?['name'] as String?,
      storeImageUrl: store?['imageUrl'] as String?,
      images: images,
      variants: (json['variants'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopVariant.fromJson)
          .toList(),
      available: json['available'] as bool?,
      availabilityReason: json['availabilityReason'] as String?,
    );
  }
}

class ShopCartLine {
  final String id;
  final ShopProduct product;
  final ShopVariant? variant;
  final int quantity;
  final double unitPrice;
  final double lineSubtotal;
  final int availableStock;
  final bool available;
  final String? availabilityReason;

  const ShopCartLine({
    required this.id,
    required this.product,
    this.variant,
    required this.quantity,
    required this.unitPrice,
    required this.lineSubtotal,
    required this.availableStock,
    required this.available,
    this.availabilityReason,
  });

  factory ShopCartLine.fromJson(Map<String, dynamic> json) => ShopCartLine(
    id: json['id']?.toString() ?? '',
    product: ShopProduct.fromJson(
      Map<String, dynamic>.from(json['product'] as Map? ?? const {}),
    ),
    variant: json['variant'] is Map<String, dynamic>
        ? ShopVariant.fromJson(json['variant'] as Map<String, dynamic>)
        : null,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: _number(json['unitPrice']) ?? 0,
    lineSubtotal: _number(json['lineSubtotal']) ?? 0,
    availableStock: (json['availableStock'] as num?)?.toInt() ?? 0,
    available: json['available'] as bool? ?? false,
    availabilityReason: json['availabilityReason'] as String?,
  );
}

class ShopWishlistLine {
  final String id;
  final ShopProduct product;
  final bool available;
  final String? availabilityReason;

  const ShopWishlistLine({
    required this.id,
    required this.product,
    required this.available,
    this.availabilityReason,
  });

  factory ShopWishlistLine.fromJson(Map<String, dynamic> json) =>
      ShopWishlistLine(
        id: json['id']?.toString() ?? '',
        product: ShopProduct.fromJson(
          Map<String, dynamic>.from(json['product'] as Map? ?? const {}),
        ),
        available: json['available'] as bool? ?? false,
        availabilityReason: json['availabilityReason'] as String?,
      );
}

double? _number(dynamic value) => value == null
    ? null
    : (value as num?)?.toDouble() ?? double.tryParse(value.toString());
