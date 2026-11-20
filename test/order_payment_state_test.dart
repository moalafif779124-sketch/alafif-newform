import 'package:flutter_test/flutter_test.dart';
import 'package:alafif_newform/models/order.dart';

Order _order(Map<String, dynamic> overrides) => Order.fromMap({
      'id': 'o1',
      'userId': 'u1',
      'orderNumber': 'ANF-1',
      'items': const [],
      'status': 'pending',
      'subtotal': 4000.0,
      'tax': 200.0,
      'shippingCost': 2000.0,
      'discount': 0.0,
      'total': 6200.0,
      'paymentMethod': 'cod',
      'paymentStatus': 'pending',
      'createdAt': 1765160000000,
      'shippingAddress': <String, dynamic>{},
      ...overrides,
    });

void main() {
  group('حالة التحقق من تحويل المحفظة', () {
    test('الدفع عند الاستلام ليس تحويلاً', () {
      final o = _order({});
      expect(o.isTransfer, isFalse);
      expect(o.isAwaitingPaymentReview, isFalse);
      expect(o.paymentVerified, isFalse);
    });

    test('كريمي + سند مُرفق + لم يُتحقق → قيد المراجعة', () {
      final o = _order({
        'paymentMethod': 'kuraimi',
        'transactionRef': 'KUR123456',
      });
      expect(o.isTransfer, isTrue);
      expect(o.isAwaitingPaymentReview, isTrue);
      expect(o.paymentVerified, isFalse);
      expect(o.paymentStatusText, 'بانتظار التحقق من التحويل');
    });

    test('جيب + بلا سند → لا شارة مراجعة', () {
      final o = _order({'paymentMethod': 'jeeb'});
      expect(o.isTransfer, isTrue);
      expect(o.isAwaitingPaymentReview, isFalse);
    });

    test('تحويل تم التحقق منه → مُتحقَّق وليس قيد المراجعة', () {
      final o = _order({
        'paymentMethod': 'jeeb',
        'transactionRef': 'JEEB1',
        'paymentStatus': 'paid',
        'paymentVerifiedAt': 1765161234000,
      });
      expect(o.paymentVerified, isTrue);
      expect(o.isAwaitingPaymentReview, isFalse);
      expect(o.paymentStatusText, 'تم الدفع');
      expect(o.paymentVerifiedAt?.millisecondsSinceEpoch, 1765161234000);
    });

    test('سند نصه فراغات يُعامل كغير مُرفق', () {
      final o = _order({'paymentMethod': 'kuraimi', 'transactionRef': '   '});
      expect(o.transactionRef, isNull);
      expect(o.isAwaitingPaymentReview, isFalse);
    });
  });
}
