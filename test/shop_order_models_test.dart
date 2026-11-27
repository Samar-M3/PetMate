import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/features/shop/data/models/shop_models.dart';
import 'package:petmatee/features/seller/data/models/seller_order_model.dart';
import 'package:petmatee/features/shop/presentation/pages/checkout_page.dart';
import 'package:petmatee/features/seller/presentation/pages/seller_orders_page.dart';
import 'package:petmatee/features/seller/presentation/pages/seller_order_detail_page.dart';

void main() {
  group('ShopOrder & SellerCustomerOrder Models Test', () {
    test('ShopOrder parses JSON with sellerOrders and recipient details correctly', () {
      final json = {
        'id': 'ord-123',
        'orderNumber': 'PM-123456-ABCD',
        'status': 'PENDING',
        'paymentMethod': 'CASH_ON_DELIVERY',
        'paymentStatus': 'UNPAID',
        'subtotal': '1200.00',
        'deliveryCharge': '100.00',
        'discount': '0.00',
        'totalAmount': '1300.00',
        'fullName': 'Aayush Shrestha',
        'phoneNumber': '9801234567',
        'deliveryAddressText': 'Baneshwor, Kathmandu',
        'landmark': 'Near City Hospital',
        'deliveryInstructions': 'Call before delivery',
        'createdAt': '2026-11-26T10:00:00.000Z',
        'items': [
          {
            'id': 'item-1',
            'productId': 'prod-1',
            'productName': 'Royal Canin Maxi Puppy',
            'productImage': 'https://example.com/rc.jpg',
            'quantity': 2,
            'unitPrice': '600.00',
            'totalPrice': '1200.00',
          }
        ],
        'sellerOrders': [
          {
            'id': 'so-1',
            'orderId': 'ord-123',
            'storeId': 'store-1',
            'store': {'name': 'Royal Paws Store'},
            'subtotal': '1200.00',
            'deliveryCharge': '0.00',
            'orderStatus': 'PENDING',
            'items': [
              {
                'id': 'item-1',
                'productId': 'prod-1',
                'productName': 'Royal Canin Maxi Puppy',
                'quantity': 2,
                'unitPrice': '600.00',
                'totalPrice': '1200.00',
              }
            ]
          }
        ]
      };

      final order = ShopOrder.fromJson(json);

      expect(order.id, 'ord-123');
      expect(order.orderNumber, 'PM-123456-ABCD');
      expect(order.fullName, 'Aayush Shrestha');
      expect(order.phoneNumber, '9801234567');
      expect(order.deliveryAddressText, 'Baneshwor, Kathmandu');
      expect(order.landmark, 'Near City Hospital');
      expect(order.paymentStatus, 'UNPAID');
      expect(order.subtotal, 1200.0);
      expect(order.deliveryCharge, 100.0);
      expect(order.totalAmount, 1300.0);
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'Royal Canin Maxi Puppy');
      expect(order.sellerOrders.length, 1);
      expect(order.sellerOrders.first.storeName, 'Royal Paws Store');
      expect(order.sellerOrders.first.orderStatus, 'PENDING');
    });

    test('SellerCustomerOrder parses backend seller response properly', () {
      final json = {
        'id': 'so-99',
        'orderId': 'ord-123',
        'orderStatus': 'RECEIVED',
        'subtotal': '2400.00',
        'deliveryCharge': '0.00',
        'createdAt': '2026-11-26T10:30:00.000Z',
        'order': {
          'id': 'ord-123',
          'orderNumber': 'PM-999999-EFGH',
          'fullName': 'Sita Sharma',
          'phoneNumber': '9841234567',
          'deliveryAddressText': 'Patan, Lalitpur',
          'paymentMethod': 'CASH_ON_DELIVERY',
          'paymentStatus': 'UNPAID',
        },
        'items': [
          {
            'id': 'item-9',
            'productId': 'prod-9',
            'productName': 'Orthopedic Pet Bed Large',
            'productImage': 'https://example.com/bed.jpg',
            'quantity': 1,
            'unitPrice': '2400.00',
            'totalPrice': '2400.00',
          }
        ]
      };

      final sellerOrder = SellerCustomerOrder.fromJson(json);

      expect(sellerOrder.id, 'so-99');
      expect(sellerOrder.orderNumber, 'PM-999999-EFGH');
      expect(sellerOrder.customerName, 'Sita Sharma');
      expect(sellerOrder.customerPhone, '9841234567');
      expect(sellerOrder.deliveryAddress, 'Patan, Lalitpur');
      expect(sellerOrder.orderStatus, 'RECEIVED');
      expect(sellerOrder.subtotal, 2400.0);
      expect(sellerOrder.items.length, 1);
      expect(sellerOrder.items.first.productName, 'Orthopedic Pet Bed Large');
    });

    test('ShopCheckoutPage and SellerOrders pages compile cleanly', () {
      expect(const ShopCheckoutPage(), isNotNull);
      expect(const SellerOrdersPage(), isNotNull);
      expect(const SellerOrderDetailPage(orderId: 'test-1'), isNotNull);
    });
  });
}
