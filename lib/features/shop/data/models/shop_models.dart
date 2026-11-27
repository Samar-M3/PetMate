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
  final double rating;
  final int reviewCount;
  final Map<String, dynamic>? specifications;
  final double? shippingWeight;
  final String? packageDimensions;

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
    this.rating = 4.8,
    this.reviewCount = 18,
    this.specifications,
    this.shippingWeight,
    this.packageDimensions,
  });

  double get displayPrice => discountedPrice ?? basePrice;
  bool get hasStock => variants.isNotEmpty
      ? variants.any(
          (variant) => variant.isAvailable && variant.availableStock > 0,
        )
      : availableStock > 0;

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : null;
    final store = json['store'] is Map
        ? Map<String, dynamic>.from(json['store'] as Map)
        : null;
    final images = (json['images'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item['imageUrl']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    final count = json['_count'] is Map
        ? Map<String, dynamic>.from(json['_count'] as Map)
        : null;

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
      rating: _number(json['rating']) ?? _number(json['avgRating']) ?? 4.8,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ??
          (count?['reviews'] as num?)?.toInt() ??
          18,
      specifications: json['specifications'] is Map
          ? Map<String, dynamic>.from(json['specifications'] as Map)
          : null,
      shippingWeight: _number(json['shippingWeight']),
      packageDimensions: json['packageDimensions'] as String?,
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

class ShopAddress {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String province;
  final String? postalCode;
  final bool isDefault;

  const ShopAddress({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.province,
    this.postalCode,
    this.isDefault = false,
  });

  factory ShopAddress.fromJson(Map<String, dynamic> json) => ShopAddress(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName']?.toString() ?? '',
    phoneNumber: json['phoneNumber']?.toString() ?? '',
    addressLine1: json['addressLine1']?.toString() ?? '',
    addressLine2: json['addressLine2'] as String?,
    city: json['city']?.toString() ?? '',
    province: json['province']?.toString() ?? '',
    postalCode: json['postalCode'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'addressLine1': addressLine1,
    if (addressLine2 != null && addressLine2!.isNotEmpty)
      'addressLine2': addressLine2,
    'city': city,
    'province': province,
    if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
    'isDefault': isDefault,
  };

  String get formattedSummary =>
      '$addressLine1, $city, $province${postalCode != null ? ' - $postalCode' : ''}';
}

class ShopSellerOrder {
  final String id;
  final String orderId;
  final String storeId;
  final String storeName;
  final double subtotal;
  final double deliveryCharge;
  final String orderStatus;
  final DateTime? receivedAt;
  final DateTime? deliveredAt;
  final List<ShopOrderItem> items;

  const ShopSellerOrder({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.storeName,
    required this.subtotal,
    required this.deliveryCharge,
    required this.orderStatus,
    this.receivedAt,
    this.deliveredAt,
    this.items = const [],
  });

  factory ShopSellerOrder.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map<String, dynamic>?;
    return ShopSellerOrder(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      storeName: store?['name']?.toString() ?? 'PetMate Store',
      subtotal: _number(json['subtotal']) ?? 0,
      deliveryCharge: _number(json['deliveryCharge']) ?? 0,
      orderStatus: json['orderStatus']?.toString() ?? 'PENDING',
      receivedAt: json['receivedAt'] != null
          ? DateTime.tryParse(json['receivedAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShopOrderItem.fromJson)
          .toList(),
    );
  }
}

class ShopOrderItem {
  final String id;
  final String productId;
  final String? variantId;
  final String productName;
  final String? productImage;
  final String? variantName;
  final String? storeName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const ShopOrderItem({
    required this.id,
    required this.productId,
    this.variantId,
    required this.productName,
    this.productImage,
    this.variantName,
    this.storeName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ShopOrderItem.fromJson(Map<String, dynamic> json) {
    final prod = json['product'] as Map<String, dynamic>?;
    final images = prod?['images'] as List?;
    final firstImage = images != null && images.isNotEmpty
        ? (images.first is Map ? images.first['imageUrl']?.toString() : null)
        : null;

    final variant = json['variant'] as Map<String, dynamic>?;
    final store = (json['sellerOrder'] is Map ? json['sellerOrder']['store'] as Map<String, dynamic>? : null) ??
        prod?['store'] as Map<String, dynamic>?;

    return ShopOrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      variantId: json['variantId']?.toString(),
      productName: json['productName']?.toString() ??
          prod?['name']?.toString() ??
          'Pet Product',
      productImage: json['productImage']?.toString() ?? firstImage,
      variantName: variant?['optionKey']?.toString(),
      storeName: store?['name']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: _number(json['unitPrice']) ?? 0,
      totalPrice: _number(json['totalPrice']) ?? 0,
    );
  }
}

class ShopOrder {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double deliveryCharge;
  final double discount;
  final double totalAmount;
  final String? customerNotes;
  final String? fullName;
  final String? phoneNumber;
  final String? deliveryAddressText;
  final String? landmark;
  final String? deliveryInstructions;
  final DateTime createdAt;
  final ShopAddress? deliveryAddress;
  final List<ShopOrderItem> items;
  final List<ShopSellerOrder> sellerOrders;

  const ShopOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryCharge,
    required this.discount,
    required this.totalAmount,
    this.customerNotes,
    this.fullName,
    this.phoneNumber,
    this.deliveryAddressText,
    this.landmark,
    this.deliveryInstructions,
    required this.createdAt,
    this.deliveryAddress,
    this.items = const [],
    this.sellerOrders = const [],
  });

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
    id: json['id']?.toString() ?? '',
    orderNumber: json['orderNumber']?.toString() ?? '',
    status: json['status']?.toString() ?? 'PENDING',
    paymentMethod: json['paymentMethod']?.toString() ?? 'CASH_ON_DELIVERY',
    paymentStatus: json['paymentStatus']?.toString() ?? 'PENDING',
    subtotal: _number(json['subtotal']) ?? 0,
    deliveryCharge: _number(json['deliveryCharge']) ?? 0,
    discount: _number(json['discount']) ?? 0,
    totalAmount: _number(json['totalAmount']) ?? 0,
    customerNotes: json['customerNotes'] as String?,
    fullName: json['fullName'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    deliveryAddressText: json['deliveryAddressText'] as String?,
    landmark: json['landmark'] as String?,
    deliveryInstructions: json['deliveryInstructions'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    deliveryAddress: json['deliveryAddress'] is Map<String, dynamic>
        ? ShopAddress.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
        : null,
    items: (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShopOrderItem.fromJson)
        .toList(),
    sellerOrders: (json['sellerOrders'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShopSellerOrder.fromJson)
        .toList(),
  );

  bool get canBeCancelled => status == 'PENDING' || status == 'CONFIRMED';
}

class ShopReview {
  final String id;
  final int rating;
  final String? title;
  final String? comment;
  final List<String> images;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;

  const ShopReview({
    required this.id,
    required this.rating,
    this.title,
    this.comment,
    this.images = const [],
    required this.createdAt,
    required this.userName,
    this.userAvatar,
  });

  factory ShopReview.fromJson(Map<String, dynamic> json) => ShopReview(
    id: json['id']?.toString() ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 5,
    title: json['title'] as String?,
    comment: json['comment'] as String?,
    images: (json['images'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    userName: json['userName']?.toString() ?? 'Pet Parent',
    userAvatar: json['userAvatar'] as String?,
  );
}

class ShopReviewSummary {
  final List<ShopReview> reviews;
  final int totalReviews;
  final double avgRating;

  const ShopReviewSummary({
    required this.reviews,
    required this.totalReviews,
    required this.avgRating,
  });

  factory ShopReviewSummary.fromJson(Map<String, dynamic> json) =>
      ShopReviewSummary(
        reviews: (json['reviews'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ShopReview.fromJson)
            .toList(),
        totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
        avgRating: _number(json['avgRating']) ?? 5.0,
      );
}

double? _number(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
