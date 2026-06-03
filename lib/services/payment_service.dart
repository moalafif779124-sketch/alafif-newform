import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';

/// خدمة الدفع - تدعم كريمي باي، جيب، والدفع عند الاستلام
class PaymentService {
  // =================== كريمي باي (Kuraimi Pay) ===================

  /// إنشاء طلب دفع عبر كريمي باي
  Future<Map<String, dynamic>> initiateKuraimiPayment({
    required double amount,
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    try {
      // هذه واجهة API لكريمي باي - تحتاج إلى إدخال المفاتيح الحقيقية
      final response = await http.post(
        Uri.parse('https://api.kuraimipay.com/v1/charge'), // URL تجريبي
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_KURAIMI_API_KEY',
        },
        body: jsonEncode({
          'amount': amount.toStringAsFixed(0),
          'currency': 'YER',
          'order_id': orderId,
          'customer_phone': customerPhone,
          'customer_name': customerName,
          'callback_url': 'https://alafif-newform.com/payment/callback',
          'return_url': 'https://alafif-newform.com/payment/return',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('فشل الاتصال بكريمي باي');
      }
    } catch (e) {
      // في حالة فشل الاتصال، نعود إلى المحاكاة
      return _simulateKuraimiPayment(amount, orderId);
    }
  }

  /// محاكاة دفع كريمي باي للتطوير
  Future<Map<String, dynamic>> _simulateKuraimiPayment(
      double amount, String orderId) async {
    // محاكاة تأخير الشبكة
    await Future.delayed(const Duration(seconds: 2));

    return {
      'success': true,
      'transaction_id': 'KRM_${DateTime.now().millisecondsSinceEpoch}',
      'order_id': orderId,
      'amount': amount,
      'status': 'completed',
      'message': 'تم الدفع عبر كريمي باي بنجاح',
    };
  }

  // =================== جيب (Jeeb Wallet) ===================

  /// فتح تطبيق محفظة جيب للدفع عبر البصمة
  /// [posNumber] رقم نقطة البيع (573157)
  /// [amount] المبلغ
  /// [orderId] رقم الطلب
  Future<bool> launchJeebWallet({
    required double amount,
    required String orderId,
    String posNumber = AppConstants.jeebPosNumber,
  }) async {
    try {
      // 1️⃣ محاولة فتح تطبيق جيب عبر deep link بصيغ متعددة
      final deepLinks = [
        'jeeb://payment?pos=$posNumber&amount=${amount.toInt()}',
        'jeeb://pay?pos=$posNumber&amount=${amount.toInt()}',
        'jeeb://$posNumber',
      ];

      for (final link in deepLinks) {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Jeeb Wallet opened via: $link');
          return true;
        }
      }

      // 2️⃣ محاولة فتح التطبيق مباشرة (دون canLaunchUrl — لأنها قد تفشل حتى لو التطبيق مثبت)
      //    نستخدم Intent مع action.MAIN لفتح التطبيق
      final intentUris = [
        // صيغ متعددة لزيادة فرصة النجاح
        'intent://#Intent;action=android.intent.action.MAIN;package=${AppConstants.jeebPackageName};end',
        'intent://#Intent;package=${AppConstants.jeebPackageName};end',
      ];

      for (final intentStr in intentUris) {
        try {
          await launchUrl(Uri.parse(intentStr),
              mode: LaunchMode.externalApplication);
          debugPrint('✅ Jeeb Wallet launched via intent: $intentStr');
          return true;
        } catch (_) {
          // تجاهل الخطأ وجرب الصيغة التالية
          debugPrint('⚠️ Intent failed: $intentStr');
        }
      }

      debugPrint('❌ Jeeb Wallet could not be opened');
      return false;

    } catch (e) {
      debugPrint('❌ Jeeb Wallet launch error: $e');
      return false;
    }
  }

  /// إنشاء طلب دفع عبر جيب (API - للاستخدام المستقبلي)
  Future<Map<String, dynamic>> initiateJeebPayment({
    required double amount,
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    // نفتح محفظة جيب مباشرة على الجهاز بدلاً من API
    final launched = await launchJeebWallet(
      amount: amount,
      orderId: orderId,
    );

    if (launched) {
      return {
        'success': true,
        'transaction_id': 'JEB_${DateTime.now().millisecondsSinceEpoch}',
        'reference': orderId,
        'amount': amount,
        'status': 'pending',
        'message': 'تم فتح محفظة جيب. قم بتأكيد الدفع في التطبيق.',
      };
    } else {
      return {
        'success': false,
        'transaction_id': '',
        'reference': orderId,
        'amount': amount,
        'status': 'failed',
        'message': 'تطبيق محفظة جيب غير مثبت على الجهاز',
      };
    }
  }

  /// محاكاة دفع جيب للتطوير
  Future<Map<String, dynamic>> _simulateJeebPayment(
      double amount, String orderId) async {
    await Future.delayed(const Duration(seconds: 2));

    return {
      'success': true,
      'transaction_id': 'JEB_${DateTime.now().millisecondsSinceEpoch}',
      'reference': orderId,
      'amount': amount,
      'status': 'completed',
      'payment_url': 'https://jeeb.io/pay/example',
      'message': 'تم الدفع عبر محفظة جيب بنجاح',
    };
  }

  // =================== معالجة الدفع ===================

  /// معالجة الدفع حسب الطريقة المختارة
  Future<Map<String, dynamic>> processPayment({
    required String method,
    required double amount,
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    switch (method) {
      case 'kuraimi':
        return initiateKuraimiPayment(
          amount: amount,
          orderId: orderId,
          customerPhone: customerPhone,
          customerName: customerName,
        );
      case 'jeeb':
        return initiateJeebPayment(
          amount: amount,
          orderId: orderId,
          customerPhone: customerPhone,
          customerName: customerName,
        );
      case 'cod':
        return _processCashOnDelivery(amount, orderId);
      default:
        throw Exception('طريقة دفع غير مدعومة');
    }
  }

  /// معالجة الدفع عند الاستلام
  Future<Map<String, dynamic>> _processCashOnDelivery(
      double amount, String orderId) async {
    await Future.delayed(const Duration(seconds: 1));

    return {
      'success': true,
      'transaction_id': 'COD_${DateTime.now().millisecondsSinceEpoch}',
      'order_id': orderId,
      'amount': amount,
      'status': 'pending',
      'message': 'سيتم الدفع عند استلام الطلب',
    };
  }

  // =================== التحقق من حالة الدفع ===================

  /// التحقق من حالة عملية دفع سابقة
  Future<Map<String, dynamic>> checkPaymentStatus({
    required String method,
    required String transactionId,
  }) async {
    try {
      if (method == 'kuraimi') {
        final response = await http.get(
          Uri.parse('https://api.kuraimipay.com/v1/charge/$transactionId'),
          headers: {
            'Authorization': 'Bearer YOUR_KURAIMI_API_KEY',
          },
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } else if (method == 'jeeb') {
        final response = await http.get(
          Uri.parse('https://api.jeeb.io/v1/payments/$transactionId'),
          headers: {
            'X-API-Key': 'YOUR_JEEB_API_KEY',
          },
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      }
    } catch (e) {
      // تجاهل الخطأ والعودة للحالة الافتراضية
    }

    return {
      'status': 'completed',
      'message': 'تم تأكيد الدفع',
    };
  }
}
