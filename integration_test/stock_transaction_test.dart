// اختبار تكاملي حقيقي (على جهاز) لمعاملة خصم المخزون الذرّية.
//
// يثبت ثلاثة أشياء ضد Firestore الإنتاجي:
//  1) الطلب + خصم المخزون يُكتبان في معاملة واحدة ويظهر الخصم فعلاً.
//  2) طلب كمية أكبر من المخزون يُرفض بالكامل (StockUnavailableException)
//     ولا يُنشأ طلب ولا يتغيّر المخزون.
//  3) قواعد Firestore المنشورة تسمح بهذا الخصم للعميل المسجّل.
//
// التشغيل:
//   flutter test integration_test/stock_transaction_test.dart -d <deviceId>
//
// يستخدم منتجاً كبير المخزون، ثم يعلّم الطلب التجريبي ملغياً.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alafif_newform/services/firebase_service.dart';

/// منتج كبير المخزون (بدلات عراسي مصري) — خصم وحدة واحدة لا يؤثر على المتجر.
const String kTestProductId = '7m73npOcttyYi7EGullr';
const String kTestProductName = 'بدلات عراسي مصري';
const String kTestTag = 'TEST-TRANSACTION';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('atomic stock decrement + insufficient-stock abort',
      (WidgetTester tester) async {
    await Firebase.initializeApp();
    final svc = FirebaseService();

    // 1) مصادقة مجهولة — قواعد المنتجات/الطلبات تتطلب مستخدماً مسجّلاً
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    // ignore: avoid_print
    print('AUTH uid=$uid');

    final productRef =
        FirebaseFirestore.instance.collection('products').doc(kTestProductId);
    final beforeSnap = await productRef.get();
    expect(beforeSnap.exists, isTrue, reason: 'منتج الاختبار غير موجود');
    final before = (beforeSnap.data()!['stockQuantity'] as num).toInt();
    // ignore: avoid_print
    print('STOCK before=$before');
    expect(before, greaterThan(5), reason: 'مخزون الاختبار صغير جداً');

    Map<String, dynamic> orderData(String tag) => <String, dynamic>{
          'userId': uid,
          'orderNumber': 'TEST-$tag-${DateTime.now().millisecondsSinceEpoch}',
          'items': <Map<String, dynamic>>[
            {
              'productId': kTestProductId,
              'productName': kTestProductName,
              'size': '',
              'color': '',
              'price': 0,
              'quantity': 1,
            }
          ],
          'status': 'pending',
          'paymentMethod': 'cod',
          'subtotal': 0,
          'shippingCost': 0,
          'discount': 0,
          'total': 0,
          'notes': '$kTestTag — automated stock test, safe to delete',
          'createdAt': FieldValue.serverTimestamp(),
        };

    // 2) السيناريو الناجح: خصم وحدة واحدة
    final orderId = await svc.createOrderWithStock(
      orderData: orderData('ok'),
      stockItems: [
        {
          'productId': kTestProductId,
          'name': kTestProductName,
          'size': '',
          'quantity': 1,
        }
      ],
    );
    // ignore: avoid_print
    print('ORDER created=$orderId');
    expect(orderId.isNotEmpty, isTrue);

    final afterOk = await productRef.get();
    final stockAfterOk = (afterOk.data()!['stockQuantity'] as num).toInt();
    // ignore: avoid_print
    print('STOCK after success=$stockAfterOk (expected ${before - 1})');
    expect(stockAfterOk, before - 1);

    // 3) السيناريو المرفوض: كمية أكبر من المخزون (لا طلب ولا خصم)
    Object? caught;
    try {
      await svc.createOrderWithStock(
        orderData: orderData('fail'),
        stockItems: [
          {
            'productId': kTestProductId,
            'name': kTestProductName,
            'size': '',
            'quantity': stockAfterOk + 5,
          }
        ],
      );
    } catch (e) {
      caught = e;
    }
    // ignore: avoid_print
    print('REJECTED with: $caught');
    expect(caught, isA<StockUnavailableException>());

    final afterFail = await productRef.get();
    final stockAfterFail = (afterFail.data()!['stockQuantity'] as num).toInt();
    // ignore: avoid_print
    print('STOCK after rejection=$stockAfterFail (expected $stockAfterOk)');
    expect(stockAfterFail, stockAfterOk,
        reason: 'الطلب المرفوض يجب ألا يغيّر المخزون');

    // الطلب المرفوض لم يُنشئ مستنداً: طلب تجريبي واحد فقط
    final testOrders = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .where('notes', isGreaterThanOrEqualTo: kTestTag)
        .where('notes', isLessThan: '$kTestTag\uf8ff')
        .get();
    // ignore: avoid_print
    print('TEST ORDERS count=${testOrders.docs.length}');
    expect(testOrders.docs.length, 1,
        reason: 'الطلب المرفوض كان سيُنشئ مستنداً — لا يجب');

    // 4) تنظيف: علّم الطلب التجريبي ملغياً (المخزون يبقى مخصوماً بوحدة واحدة)
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'cancelled', 'cancelReason': kTestTag});
  });
}
