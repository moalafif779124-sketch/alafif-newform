import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ----------------------------------------------------------------
// 🎯 أدخل مفتاح Hugging Face API هنا (مجاني)
// سجل واحصل على مفتاح مجاني من https://huggingface.co/settings/tokens
// ----------------------------------------------------------------
String huggingFaceApiKey = '';

/// رابط Space الخاص بـ IDM-VTON (يمكن تغييره إذا نشرت Space خاص بك)
String idmVtonSpaceUrl = 'https://yisol-idm-vton.hf.space';

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
/// تستخدم Hugging Face Spaces (IDM-VTON) بدلاً من Replicate
class AiTryOnService {
  /// إنشاء طلب تجربة افتراضية عبر Hugging Face Spaces (IDM-VTON Gradio API)
  /// [personImagePath] مسار صورة الشخص (محلي)
  /// [garmentImageUrl] رابط صورة المنتج
  /// [category] فئة المنتج (upper_body, lower_body, dresses)
  static Future<PredictionResult> createTryOn({
    required String personImagePath,
    required String garmentImageUrl,
    String category = 'upper_body',
  }) async {
    if (huggingFaceApiKey.isEmpty) {
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'مفتاح Hugging Face غير مضبط. الرجاء إضافة المفتاح في الإعدادات.',
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

      debugPrint('🤖 AI Try-On (HF): بدء التجربة الافتراضية...');

      // ================================================================
      // الطريقة 1: محاولة Hugging Face Inference API مباشرة
      // ================================================================
      final bytes = await file.readAsBytes();
      final personB64 = base64Encode(bytes);
      final personDataUri = 'data:image/jpeg;base64,$personB64';

      // محاولة استدعاء Hugging Face Inference API مباشرة
      final hfResult = await _callHuggingFaceInference(
        personDataUri: personDataUri,
        garmentImageUrl: garmentImageUrl,
        category: category,
      );
      if (hfResult != null) return hfResult;

      // ================================================================
      // الطريقة 2: Gradio API (IDM-VTON Space)
      // ================================================================
      final gradioResult = await _callGradioApi(
        personDataUri: personDataUri,
        garmentImageUrl: garmentImageUrl,
        category: category,
      );
      if (gradioResult != null) return gradioResult;

      // كل الطرق فشلت
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'فشلت جميع محاولات الاتصال بالذكاء الاصطناعي. تحقق من المفتاح والاتصال بالإنترنت.',
      );
    } catch (e) {
      debugPrint('⚠️ AI Try-On (HF) خطأ: $e');
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'خطأ في الاتصال: $e',
      );
    }
  }

  /// محاولة استدعاء Hugging Face Inference API مباشرة
  static Future<PredictionResult?> _callHuggingFaceInference({
    required String personDataUri,
    required String garmentImageUrl,
    required String category,
  }) async {
    try {
      debugPrint('🤖 HF Inference API: محاولة...');

      final response = await http.post(
        Uri.parse('https://api-inference.huggingface.co/models/yisol/IDM-VTON'),
        headers: {
          'Authorization': 'Bearer $huggingFaceApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': {
            'human_image': personDataUri,
            'garment_image': garmentImageUrl,
            'category': category,
          },
        }),
        // Timeout قصير لأن الـ API قد لا يدعم هذا النموذج
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        debugPrint('🤖 HF Inference API: نجاح');
        final data = jsonDecode(response.body);
        String? outputUrl;

        // الـ API يعيد الصورة مباشرة أو كرابط
        if (data is Map && data['image'] != null) {
          outputUrl = data['image'];
        } else if (data is String) {
          outputUrl = data;
        } else if (data is List && data.isNotEmpty) {
          outputUrl = data.first.toString();
        }

        if (outputUrl != null) {
          return PredictionResult(
            status: PredictionStatus.succeeded,
            outputUrl: outputUrl,
          );
        }
      } else if (response.statusCode != 503 && response.statusCode != 400) {
        // 503 = model loading, سنحاول Gradio API
        debugPrint('⚠️ HF Inference API: ${response.statusCode} - ${response.body}');
      } else {
        debugPrint('⚠️ HF Inference API: ${response.statusCode} - النموذج قد لا يكون متاحاً عبر Inference API');
      }
    } catch (e) {
      debugPrint('⚠️ HF Inference API فشل (سأحاول Gradio API): $e');
    }
    return null;
  }

  /// محاولة استدعاء Gradio API الخاص بـ IDM-VTON Space
  static Future<PredictionResult?> _callGradioApi({
    required String personDataUri,
    required String garmentImageUrl,
    required String category,
  }) async {
    try {
      debugPrint('🤖 Gradio API: محاولة الاتصال بـ $idmVtonSpaceUrl...');

      // رفع صورة الشخص إلى الـ Space
      final personImageBytes = base64Decode(personDataUri.split(',').last);
      final uploadUri = Uri.parse('$idmVtonSpaceUrl/upload');
      final uploadRequest = http.MultipartRequest('POST', uploadUri);
      uploadRequest.files.add(
        http.MultipartFile.fromBytes(
          'files',
          personImageBytes,
          filename: 'person.jpg',
        ),
      );

      final uploadResponse = await uploadRequest.send();
      final uploadBody = await uploadResponse.stream.bytesToString();
      debugPrint('🤖 Gradio Upload: ${uploadResponse.statusCode} - $uploadBody');

      if (uploadResponse.statusCode != 200) {
        // محاولة طريقة Gradio 4.x الجديدة
        return await _callGradioApiV4(
          personDataUri: personDataUri,
          garmentImageUrl: garmentImageUrl,
          category: category,
        );
      }

      // تحليل مسار الملف المرفوع
      List<dynamic> uploadedPaths;
      try {
        uploadedPaths = jsonDecode(uploadBody) as List<dynamic>;
      } catch (_) {
        // قد يكون نصاً عادياً
        return await _callGradioApiV4(
          personDataUri: personDataUri,
          garmentImageUrl: garmentImageUrl,
          category: category,
        );
      }

      if (uploadedPaths.isEmpty) {
        return await _callGradioApiV4(
          personDataUri: personDataUri,
          garmentImageUrl: garmentImageUrl,
          category: category,
        );
      }

      final uploadedPath = uploadedPaths.first.toString();

      // استدعاء التنبؤ
      final predictUri = Uri.parse('$idmVtonSpaceUrl/api/predict/');
      final predictResponse = await http.post(
        predictUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': [
            uploadedPath,
            garmentImageUrl,
            category,
          ],
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('🤖 Gradio Predict: ${predictResponse.statusCode}');

      if (predictResponse.statusCode == 200) {
        final result = jsonDecode(predictResponse.body);
        if (result['data'] is List && (result['data'] as List).isNotEmpty) {
          final output = result['data'].first;
          String? outputUrl;

          if (output is String) {
            outputUrl = output;
          } else if (output is Map && output['url'] != null) {
            outputUrl = output['url'];
          } else if (output is Map && output['path'] != null) {
            // الصورة على الـ Space، نحتاج تحميلها
            outputUrl = '$idmVtonSpaceUrl/file=${output['path']}';
          }

          if (outputUrl != null) {
            // إذا كان المسار محلياً على الـ Space، نحوله لرابط
            if (!outputUrl.startsWith('http')) {
              outputUrl = '$idmVtonSpaceUrl/file=$outputUrl';
            }
            return PredictionResult(
              status: PredictionStatus.succeeded,
              outputUrl: outputUrl,
            );
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Gradio API V3 فشل: $e');
      return await _callGradioApiV4(
        personDataUri: personDataUri,
        garmentImageUrl: garmentImageUrl,
        category: category,
      );
    }
  }

  /// Gradio 4.x API (تنسيق جديد)
  static Future<PredictionResult?> _callGradioApiV4({
    required String personDataUri,
    required String garmentImageUrl,
    required String category,
  }) async {
    try {
      debugPrint('🤖 Gradio API V4: محاولة...');

      // Gradio 4.x يستخدم /gradio_api/call/predict
      final callUri = Uri.parse('$idmVtonSpaceUrl/gradio_api/call/predict');
      final callResponse = await http.post(
        callUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $huggingFaceApiKey',
        },
        body: jsonEncode({
          'data': [
            personDataUri,
            garmentImageUrl,
            category,
          ],
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('🤖 Gradio V4 Call: ${callResponse.statusCode}');

      if (callResponse.statusCode == 200) {
        final result = jsonDecode(callResponse.body);
        if (result['data'] is List && (result['data'] as List).isNotEmpty) {
          final output = result['data'].first;
          String? outputUrl = _extractImageUrl(output);
          if (outputUrl != null) {
            return PredictionResult(
              status: PredictionStatus.succeeded,
              outputUrl: outputUrl,
            );
          }
        }
      }

      // Gradio 4.x قد يعيد event_id للاستقصاء
      if (callResponse.statusCode == 200) {
        try {
          final data = jsonDecode(callResponse.body);
          if (data['event_id'] != null) {
            // استقصاء النتيجة
            return await _pollGradioEvent(data['event_id']);
          }
        } catch (_) {}
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Gradio API V4 فشل: $e');
      return null;
    }
  }

  /// استقصاء حدث Gradio (لـ Gradio 4.x)
  static Future<PredictionResult?> _pollGradioEvent(String eventId) async {
    try {
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final response = await http.get(
          Uri.parse('$idmVtonSpaceUrl/gradio_api/call/predict/$eventId'),
        );
        if (response.statusCode == 200) {
          final body = response.body.trim();
          // تنسيق SSE: "data: {...}\n\n"
          for (final line in body.split('\n')) {
            if (line.startsWith('data: ')) {
              try {
                final data = jsonDecode(line.substring(6));
                if (data['data'] is List && (data['data'] as List).isNotEmpty) {
                  final output = data['data'].first;
                  if (output is Map && output['status'] == 'complete') continue;
                  if (output is Map && output['error'] != null) {
                    return PredictionResult(
                      status: PredictionStatus.failed,
                      error: output['error'].toString(),
                    );
                  }
                  String? url = _extractImageUrl(output);
                  if (url != null) {
                    return PredictionResult(
                      status: PredictionStatus.succeeded,
                      outputUrl: url,
                    );
                  }
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Gradio Poll فشل: $e');
    }
    return null;
  }

  /// استخراج رابط الصورة من استجابة Gradio
  static String? _extractImageUrl(dynamic output) {
    if (output is String) {
      return output.startsWith('http') ? output : null;
    }
    if (output is Map) {
      if (output['url'] is String) return output['url'];
      if (output['path'] is String) return '$idmVtonSpaceUrl/file=${output['path']}';
    }
    return null;
  }

  /// التحقق من حالة الطلب (للتوافق مع الكود القديم - غير مستخدم حالياً)
  static Future<PredictionResult> checkPrediction(String predictionId) async {
    // Hugging Face Gradio API متزامن، لا حاجة للاستقصاء
    return PredictionResult(
      id: predictionId,
      status: PredictionStatus.failed,
      error: 'لا يدعم الاستقصاء مع Hugging Face API',
    );
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
