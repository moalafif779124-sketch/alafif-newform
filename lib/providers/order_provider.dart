import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../models/bundle_pricing.dart';
import '../services/firebase_service.dart';
import '../services/payment_service.dart';
import '../config/constants.dart';
import '../config/delivery_config.dart';

/// مزود حالة الطلبات
class OrderProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final PaymentService _paymentService = PaymentService();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get orderCount => _orders.length;

  // =================== تحميل الطلبات ===================

  Future<void> loadOrders(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ordersData = await _firebaseService.getUserOrders(userId);
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل الطلبات';
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // =================== إنشاء طلب جديد ===================

  Future<String?> createOrder({
    required String userId,
    required List<CartItem> cartItems,
    required String paymentMethod,
    required Map<String, dynamic> shippingAddress,
    String? notes,
    // التوصيل الفعلي المحسوب في شاشة الدفع (قد يكون مجانياً) وخصم النقاط —
    // يُمرَّران كي يطابق الإجمالي المحفوظ ما رآه العميل تماماً.
    double? shippingCost,
    double pointsDiscount = 0,
    // كود خصم مُتحقَّق منه في شاشة الدفع (CouponService.validate).
    // يُمرَّر كي يطابق الإجمالي المحفوظ ما رآه العميل، ويُسجَّل الكود في الطلب.
    double couponDiscount = 0,
    String? couponCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ===== خصم الطقم (Full-Look) =====
      // يُحسب هنا من عناصر السلة بنفس محرك `BundlePricing` المستخدم في
      // الواجهة — فلا يمكن أن يصل الطلب بخصم معروض وغير محسوب (أو العكس).
      final bundle = BundlePricing.summarize(cartItems);
      final bundleDiscount = bundle.discountAmount;

      // حساب المجموع
      final subtotal = cartItems.fold<double>(
          0, (sum, item) => sum + (item.product.price * item.quantity));
      final tax = (subtotal - bundleDiscount) * AppConstants.taxRate;
      // التوصيل الفعلي — يُمرَّر من شاشة الدفع (مجاني ≥ 50,000 أو حسب المحافظة).
      // كان الكود القديم يضيف AppConstants.shippingCost دائماً فيُرفع الإجمالي
      // المحفوظ فوق ما رآه العميل (السبب الجذري لاختلاف 63,000 ← 66,000).
      final shipping = shippingCost ??
          DeliveryConfig.getShippingCost(DeliveryConfig.defaultCityId,
              subtotal: subtotal);
      final total = subtotal +
          tax +
          shipping -
          bundleDiscount -
          pointsDiscount -
          couponDiscount;

      // إنشاء رقم طلب
      final orderNumber = 'ANF-${DateTime.now().millisecondsSinceEpoch}';

      // تحضير بيانات الطلب
      final orderData = Order(
        id: '', // سيتم تعيينه من Firestore
        userId: userId,
        orderNumber: orderNumber,
        items: cartItems
            .map((item) => OrderItem(
                  productId: item.product.id,
                  productName: item.product.name,
                  productImage:
                      item.product.images.isNotEmpty ? item.product.images.first : '',
                  size: item.size,
                  color: item.color,
                  price: item.product.price,
                  quantity: item.quantity,
                  bundleSource: item.bundleSource,
                  bundleGroupId: item.bundleGroupId,
                ))
            .toList(),
        status: 'pending',
        subtotal: subtotal,
        shippingCost: shipping,
        tax: tax,
        discount: bundleDiscount + pointsDiscount + couponDiscount,
        bundle: bundle.hasBundle ? bundle.toMap() : null,
        total: total,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod == 'cod' ? 'pending' : 'pending',
        shippingAddress: AddressInfo(
          fullName: shippingAddress['fullName'] ?? '',
          phone: shippingAddress['phone'] ?? '',
          fullAddress: shippingAddress['fullAddress'] ?? '',
          landmark: shippingAddress['landmark'],
        ),
        notes: notes,
        createdAt: DateTime.now(),
      );

      // حفظ الطلب + خصم المخزون في معاملة واحدة (ذرّي).
      // إن نقص أي صنف: لا طلب ولا خصم، وتظهر رسالة عربية واضحة للعميل.
      final orderMap = orderData.toMap();
      if (couponCode != null && couponCode.isNotEmpty) {
        orderMap['couponCode'] = couponCode;
        orderMap['couponDiscount'] = couponDiscount;
      }

      final String orderId;
      try {
        orderId = await _firebaseService.createOrderWithStock(
          orderData: orderMap,
          stockItems: cartItems
              .map((item) => <String, dynamic>{
                    'productId': item.product.id,
                    'name': item.product.name,
                    'size': item.size,
                    'quantity': item.quantity,
                  })
              .toList(),
        );
      } on StockUnavailableException catch (e) {
        debugPrint('⛔ stock unavailable: ${e.message}');
        _error = e.message;
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // معالجة الدفع
      final paymentResult = await _paymentService.processPayment(
        method: paymentMethod,
        amount: total,
        orderId: orderId,
        customerPhone: shippingAddress['phone'] ?? '',
        customerName: shippingAddress['fullName'] ?? '',
      );

      // تحديث حالة الدفع
      // الدفع عند الاستلام (cod) لا يُعلَّم «مدفوعاً» أبداً — يبقى معلّقاً حتى
      // استلام النقد عند التسليم (كان يُعلَّم paid خطأً فيُظهر «تم الدفع»).
      if (paymentResult['success'] == true) {
        final isCod = paymentMethod == 'cod';
        await _firebaseService.firestore
            .collection('orders')
            .doc(orderId)
            .update({
          if (!isCod) 'paymentStatus': 'paid',
          if (!isCod) 'paymentReference': paymentResult['transaction_id'],
          'status': 'confirmed',
        });
      }

      // إضافة الطلب إلى القائمة المحلية
      final savedOrder = await _firebaseService.getUserOrders(userId);
      _orders = savedOrder.map((data) => Order.fromMap(data)).toList();

      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _error = 'فشل إنشاء الطلب: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // =================== إلغاء الطلب ===================

  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firebaseService.firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        final oldOrder = _orders[index];
        _orders[index] = Order(
          id: oldOrder.id,
          userId: oldOrder.userId,
          orderNumber: oldOrder.orderNumber,
          items: oldOrder.items,
          status: 'cancelled',
          subtotal: oldOrder.subtotal,
          shippingCost: oldOrder.shippingCost,
          tax: oldOrder.tax,
          discount: oldOrder.discount,
          total: oldOrder.total,
          paymentMethod: oldOrder.paymentMethod,
          paymentStatus: oldOrder.paymentStatus,
          paymentReference: oldOrder.paymentReference,
          shippingAddress: oldOrder.shippingAddress,
          notes: oldOrder.notes,
          createdAt: oldOrder.createdAt,
          updatedAt: DateTime.now(),
          deliveredAt: oldOrder.deliveredAt,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'فشل إلغاء الطلب';
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  // =================== مسح الأخطاء ===================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
