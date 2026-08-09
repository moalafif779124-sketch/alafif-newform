import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// خدمة البحث الصوتي — تغليف speech_to_text
/// للتحويل من الكلام إلى نص (عربي — حسب لغة الجهاز)
class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isListening => _speech.isListening;

  /// تهيئة محرك التعرف الصوتي (يطلب إذن الميكروفون تلقائياً)
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) {
        debugPrint('⚠️ Speech error: ${error.errorMsg}');
      },
      onStatus: (status) {
        debugPrint('🎤 Speech status: $status');
      },
    );
    return _initialized;
  }

  /// بدء الاستماع — يستدعي onResult مع النص المعرَّف
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
  }) async {
    if (!_initialized) return;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      // اللغة الافتراضية للجهاز (عربي على هواتف المستخدمين)
    );
  }

  /// إيقاف الاستماع وإرجاع ما تم التقاطه حتى اللحظة
  Future<void> stop() async => _speech.stop();

  /// إلغاء الجلسة بدون نتيجة
  Future<void> cancel() async => _speech.cancel();
}
