import 'dart:math';

/// معرّف طلب ثابت لكل محاولة شراء.
///
/// يُستخدم كمعرّف مستند الطلب في Firestore، فإعادة المحاولة (بعد خطأ شبكة أو
/// بعد العودة من محفظة جيب) تكتب على نفس المستند بدل إنشاء طلب ثانٍ — والمعاملة
/// نفسها ترى المستند موجوداً فترجع فوراً بلا خصم مخزون مرة أخرى.
///
/// يجب أن يطابق [isValidOrderRequestId]: حروف وأرقام إنجليزية فقط، 8..64 حرفاً
/// (قواعد Firestore ترفض '/' وبعض الرموز في معرّفات المستندات).
class OrderRequestId {
  OrderRequestId._();

  static final Random _random = Random.secure();

  /// معرّف جديد: بادئة `req` + طابع زمني base36 + 7 أحرف عشوائية.
  /// المعرّف قصير بما يكفي للقراءة، وفريد عملياً بين كل الأجهزة.
  static String generate([DateTime? now]) {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch.toRadixString(36);
    final a = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    final b = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return 'req$ts$a$b';
  }

  static final RegExp _valid = RegExp(r'^[A-Za-z0-9]{8,64}$');

  /// هل يصلح هذا المعرّف كمعرّف مستند؟ (يرفض الفارغ والرموز والمفرط الطول)
  static bool isValid(String? id) => id != null && _valid.hasMatch(id);
}
