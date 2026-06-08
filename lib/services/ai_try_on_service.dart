import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ----------------------------------------------------------------
// 🎯 قم بتغيير مفتاح API هذا إلى المفتاح الخاص بك
// سجل في https://replicate.com للحصول على مفتاح مجاني
// ----------------------------------------------------------------
String replicateApiKey = '';

/// حالة طلب الذكاء الاصطناعي
enum PredictionStatus { starting, processing, succeeded, failed }

/// نتيجة طلب الذكاء الاصطناعي
class PredictionResult {
  final String? id;
  final PredictionStatus status;
  final String? outputUrl;
  final String? error;

  PredictionResult({
    this.id,
    required this.status,
    this.outputUrl,
    this.error,
  });

  bool get isDone => status == PredictionStatus.succeeded || status == PredictionStatus.failed;
  bool get isSuccess => status == PredictionStatus.succeeded;
}

/// خدمة التجربة الافتراضية بالذكاء الاصطناعي
/// تستخدم واجهة برمجة التطبيقات لتوليد صورة المستخدم وهو يرتدي المنتج
class AiTryOnService {
  static const String _baseUrl = 'https://api.replicate.com/v1';

  // معرف نموذج IDM-VTON للتجربة الافتراضية
  static const String _modelVersion =
      '906425dbca90663ff5427624839572cc56ea7d380343d13e2a4c4b09d3f0c30f';

  /// إنشاء طلب تجربة افتراضية
  /// [personImagePath] مسار صورة الشخص (محلي)
  /// [garmentImageUrl] رابط صورة المنتج
  /// [category] فئة المنتج (upper_body, lower_body, dresses)
  static Future<PredictionResult> createTryOn({
    required String personImagePath,
    required String garmentImageUrl,
    String category = 'upper_body',
  }) async {
    if (replicateApiKey.isEmpty) {
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'مفتاح API غير مضبط. الرجاء إضافة مفتاح Replicate في الإعدادات.',
      );
    }

    try {
      final file = File(personImagePath);
      if (!await file.exists()) {
        return PredictionResult(
          status: PredictionStatus.failed,
          error: 'لم يتم العثور على صورة الشخص',
        );
      }
      final bytes = await file.readAsBytes();
      final personB64 = base64Encode(bytes);
      final personDataUri = 'data:image/jpeg;base64,$personB64';

      debugPrint('🤖 AI Try-On: إرسال الطلب إلى Replicate...');

      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Bearer $replicateApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': _modelVersion,
          'input': {
            'human_image': personDataUri,
            'garment_image': garmentImageUrl,
            'category': category,
          },
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final predictionId = data['id'] as String?;
        if (predictionId != null) {
          debugPrint('🤖 AI Try-On: تم إنشاء الطلب بنجاح: $predictionId');
          return PredictionResult(
            id: predictionId,
            status: PredictionStatus.processing,
          );
        }
      }

      debugPrint('⚠️ AI Try-On فشل: ${response.statusCode} ${response.body}');
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'فشل الاتصال بالذكاء الاصطناعي (${response.statusCode})',
      );
    } catch (e) {
      debugPrint('⚠️ AI Try-On خطأ: $e');
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'خطأ في الاتصال: $e',
      );
    }
  }

  /// التحقق من حالة الطلب
  static Future<PredictionResult> checkPrediction(String predictionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/predictions/$predictionId'),
        headers: {
          'Authorization': 'Bearer $replicateApiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;

        switch (status) {
          case 'starting':
          case 'processing':
            return PredictionResult(
              id: predictionId,
              status: PredictionStatus.processing,
            );
          case 'succeeded':
            final output = data['output'];
            String? outputUrl;
            if (output is String) {
              outputUrl = output;
            } else if (output is List && output.isNotEmpty) {
              outputUrl = output.first as String;
            }
            return PredictionResult(
              id: predictionId,
              status: PredictionStatus.succeeded,
              outputUrl: outputUrl,
            );
          case 'failed':
          case 'canceled':
            return PredictionResult(
              id: predictionId,
              status: PredictionStatus.failed,
              error: data['error'] as String? ?? 'فشل المعالجة',
            );
          default:
            return PredictionResult(id: predictionId, status: PredictionStatus.processing);
        }
      }

      return PredictionResult(
        id: predictionId,
        status: PredictionStatus.failed,
        error: 'فشل التحقق (${response.statusCode})',
      );
    } catch (e) {
      return PredictionResult(
        id: predictionId,
        status: PredictionStatus.failed,
        error: 'خطأ: $e',
      );
    }
  }

  /// تحويل فئة المنتج إلى فئة النموذج
  static String categoryForModel(String categoryId) {
    switch (categoryId) {
      case 'shemagh':
      case 'accessories':
        return 'upper_body';
      case 'thobes':
      case 'bisht':
        return 'dresses';
      default:
        return 'upper_body';
    }
  }
}
