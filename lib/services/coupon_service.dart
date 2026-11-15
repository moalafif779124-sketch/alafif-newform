import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// نتيجة التحقق من كود الخصم — رسالة عربية جاهزة للعرض في كل الحالات.
class CouponResult {
  final bool ok;
  final String code;
  final double discount;
  final String message;

  const CouponResult({
    required this.ok,
    required this.code,
    required this.discount,
    required this.message,
  });

  static const idle =
      CouponResult(ok: false, code: '', discount: 0, message: '');
}

/// أكواد الخصم (`coupons/{CODE}`).
///
/// مستند الكود (المعرّف = الكود بأحرف كبيرة):
///   code         string   الكود كما يُعرض في لوحة الإدارة (اختياري)
///   type         string   'percent' | 'fixed'
///   value        number   نسبة (١٠ = ١٠٪) أو مبلغ ثابت بالريال
///   minSubtotal  number   أقل مجموع فرعي يقبل الكود (٠ = بلا حد)
///   maxUses      number   أقصى عدد استخدامات (٠ = بلا حد)
///   usedCount    number   يُزاد تلقائياً عند كل طلب
///   active       bool
///   expiresAt    timestamp (اختياري)
///
/// ملاحظة أمنية: الخادم يرفض أي خصم يتجاوز ٥٠٪ من المجموع الفرعي
/// (قاعدة `orders`)، لذلك السقف مفروض هنا أيضاً كي لا يفشل الطلب بعد الدفع.
class CouponService {
  static const double maxDiscountRatio = 0.5;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<CouponResult> validate(String rawCode, double subtotal,
      {double otherDiscount = 0}) async {
    final code = rawCode.trim().toUpperCase().replaceAll(' ', '');
    if (code.isEmpty) {
      return const CouponResult(
          ok: false, code: '', discount: 0, message: 'أدخل كود الخصم');
    }

    try {
      final snap = await _db.collection('coupons').doc(code).get();
      final d = snap.data();
      if (!snap.exists || d == null) {
        return CouponResult(
            ok: false, code: code, discount: 0, message: 'كود الخصم غير صحيح');
      }
      if (d['active'] != true) {
        return CouponResult(
            ok: false,
            code: code,
            discount: 0,
            message: 'هذا الكود غير مفعّل حالياً');
      }

      final expires = d['expiresAt'];
      if (expires is Timestamp && expires.toDate().isBefore(DateTime.now())) {
        return CouponResult(
            ok: false, code: code, discount: 0, message: 'انتهت صلاحية الكود');
      }

      final maxUses = (d['maxUses'] as num?)?.toInt() ?? 0;
      final used = (d['usedCount'] as num?)?.toInt() ?? 0;
      if (maxUses > 0 && used >= maxUses) {
        return CouponResult(
            ok: false,
            code: code,
            discount: 0,
            message: 'انتهى عدد استخدامات هذا الكود');
      }

      final minSubtotal = (d['minSubtotal'] as num?)?.toDouble() ?? 0;
      if (subtotal < minSubtotal) {
        return CouponResult(
          ok: false,
          code: code,
          discount: 0,
          message:
              'الكود يعمل على طلبات من ${minSubtotal.toStringAsFixed(0)} ريال وأكثر',
        );
      }

      final type = (d['type'] as String?) ?? 'percent';
      final value = (d['value'] as num?)?.toDouble() ?? 0;
      var discount = type == 'fixed' ? value : subtotal * value / 100;

      // سقف ٥٠٪ من المجموع الفرعي — نفس حد قاعدة `orders` على الخادم.
      // يُحسب على (الطقم + النقاط + الكود) مجتمعة: قاعدة الطلب ترفض أي خصم
      // إجمالي يتجاوز ٥٠٪، فلو أخذ الكود ٥٠٪ مع خصم طقم ١٠٪ لفشل الطلب.
      final cap = subtotal * maxDiscountRatio - otherDiscount;
      if (cap <= 0) {
        return CouponResult(
            ok: false,
            code: code,
            discount: 0,
            message: 'الخصومات المطبقة وصلت الحد المسموح — الكود غير قابل للاستخدام');
      }
      if (discount > cap) discount = cap;
      discount = discount.roundToDouble();
      if (discount <= 0) {
        return CouponResult(
            ok: false,
            code: code,
            discount: 0,
            message: 'قيمة الخصم غير صحيحة، تواصل مع المتجر');
      }

      return CouponResult(
        ok: true,
        code: code,
        discount: discount,
        message: type == 'fixed'
            ? 'تم تطبيق الخصم: ${discount.toStringAsFixed(0)} ريال'
            : 'تم تطبيق الخصم: ${value.toStringAsFixed(0)}٪',
      );
    } catch (e) {
      debugPrint('⚠️ coupon validate: $e');
      return CouponResult(
          ok: false,
          code: code,
          discount: 0,
          message: 'تعذّر التحقق من الكود، حاول مرة أخرى');
    }
  }

  /// يزاد عدّاد الاستخدام بعد إنشاء الطلب — القاعدة تسمح بزيادة ١ فقط.
  Future<void> markUsed(String code) async {
    if (code.trim().isEmpty) return;
    try {
      await _db.collection('coupons').doc(code.trim().toUpperCase()).update({
        'usedCount': FieldValue.increment(1),
      });
    } catch (e) {
      // فشل العدّاد لا يجوز أن يُفشل الطلب — الطلب أهم من إحصائية.
      debugPrint('⚠️ coupon markUsed: $e');
    }
  }
}
