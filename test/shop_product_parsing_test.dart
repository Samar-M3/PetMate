import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/shop/data/models/shop_models.dart';

void main() {
  test('ShopProduct.fromJson parses Prisma Decimal string prices without throwing', () {
    final json = <String, dynamic>{
      'id': 'd0d22963-9060-425a-ab26-6ccaa96d17eb',
      'name': 'food',
      'slug': 'food',
      'sku': 'wrgssssssssss',
      'description': 'aD A AD CF FKHGHI FJ',
      'shortDescription': 'ssssssssssssssssssssssssssaaa',
      'brand': 'sf arw',
      'basePrice': '120',
      'discountedPrice': '100',
      'costPrice': null,
      'currency': 'NPR',
      'availableStock': 10,
      'lowStockThreshold': 5,
      'status': 'ACTIVE',
      'isFeatured': false,
      'categoryId': 'ed207714-3f0b-42f6-afba-03031f3a6255',
      'storeId': '70e561ba-bc0f-4f53-8fa7-dcc1f0ed8ab0',
      'specifications': {
        'petType': 'All Pets',
        'material': 'COTTON',
        'dimensions': '2',
        'ingredients': 'EQF FE WFJ W F',
      },
      'shippingWeight': 5,
      'packageDimensions': '2',
      'images': [
        {
          'id': '70a8d50a-c2f0-4ac5-b7d6-6aac0768b4b2',
          'imageUrl': 'https://res.cloudinary.com/m5e3zxzn/image/upload/v1795583392/petmate-development/products/nsiavvzzx5tafphy9yzm.jpg',
          'displayOrder': 0,
        },
      ],
      'category': {
        'id': 'ed207714-3f0b-42f6-afba-03031f3a6255',
        'name': 'Accessories',
        'slug': 'accessories',
      },
      'store': {
        'id': '70e561ba-bc0f-4f53-8fa7-dcc1f0ed8ab0',
        'name': 'gooo stote',
        'slug': 'gooo-stote',
        'imageUrl': null,
        'status': 'APPROVED',
      },
      'variants': [],
      'discountPercentage': 17,
    };

    final product = ShopProduct.fromJson(json);

    expect(product.id, 'd0d22963-9060-425a-ab26-6ccaa96d17eb');
    expect(product.name, 'food');
    expect(product.basePrice, 120.0);
    expect(product.discountedPrice, 100.0);
    expect(product.displayPrice, 100.0);
    expect(product.discountPercentage, 17);
    expect(product.availableStock, 10);
    expect(product.storeName, 'gooo stote');
    expect(product.categoryName, 'Accessories');
    expect(product.images.length, 1);
    expect(product.shippingWeight, 5.0);
  });
}
