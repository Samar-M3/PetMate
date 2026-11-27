class SellerCustomerOrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const SellerCustomerOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SellerCustomerOrderItem.fromJson(Map<String, dynamic> json) {
    final prod = json['product'] as Map<String, dynamic>?;
    final images = prod?['images'] as List?;
    final firstImage = images != null && images.isNotEmpty
        ? (images.first is Map ? images.first['imageUrl']?.toString() : null)
        : null;

    final variant = json['variant'] as Map<String, dynamic>?;

    return SellerCustomerOrderItem(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ??
          prod?['name']?.toString() ??
          'Product',
      productImage: json['productImage']?.toString() ?? firstImage,
      variantName: variant?['optionKey']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: _toDouble(json['unitPrice']),
      totalPrice: _toDouble(json['totalPrice']),
    );
  }
}

class SellerCustomerOrder {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String? landmark;
  final String? deliveryInstructions;
  final String? paymentMethod;
  final String? paymentStatus;
  final String orderStatus;
  final double subtotal;
  final double deliveryCharge;
  final DateTime createdAt;
  final List<SellerCustomerOrderItem> items;

  const SellerCustomerOrder({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.landmark,
    this.deliveryInstructions,
    this.paymentMethod,
    this.paymentStatus,
    required this.orderStatus,
    required this.subtotal,
    required this.deliveryCharge,
    required this.createdAt,
    this.items = const [],
  });

  factory SellerCustomerOrder.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    final user = order?['user'] as Map<String, dynamic>?;

    final customerName = order?['fullName']?.toString() ??
        user?['fullName']?.toString() ??
        'Customer';
    final customerPhone = order?['phoneNumber']?.toString() ??
        user?['phone']?.toString() ??
        '';
    final deliveryAddress = order?['deliveryAddressText']?.toString() ?? '';

    return SellerCustomerOrder(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: order?['orderNumber']?.toString() ?? '',
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      landmark: order?['landmark'] as String?,
      deliveryInstructions: order?['deliveryInstructions'] as String?,
      paymentMethod: order?['paymentMethod'] as String?,
      paymentStatus: order?['paymentStatus'] as String?,
      orderStatus: json['orderStatus']?.toString() ?? 'PENDING',
      subtotal: _toDouble(json['subtotal']),
      deliveryCharge: _toDouble(json['deliveryCharge']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SellerCustomerOrderItem.fromJson)
          .toList(),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
