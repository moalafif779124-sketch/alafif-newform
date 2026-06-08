import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../services/ai_try_on_service.dart';
import '../../widgets/app_image.dart';

/// شاشة التجربة الافتراضية بالذكاء الاصطناعي
/// تلتقط صور المستخدم، ترسلها للذكاء الاصطناعي، وتعرض النتيجة
class VirtualTryOnScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImage;
  final String categoryId;

  const VirtualTryOnScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.categoryId,
  });

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _personImage;
  String? _resultImageUrl;
  bool _isProcessing = false;
  bool _isApiKeyMissing = false;
  String? _errorMessage;
  Timer? _pollTimer;
  String? _predictionId;

  // مراحل التطبيق
  enum TryOnStep { takePhoto, processing, result }
  TryOnStep _currentStep = TryOnStep.takePhoto;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          title: Text(widget.productName, style: const TextStyle(fontSize: 16)),
          centerTitle: true,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case TryOnStep.takePhoto:
        return _buildPhotoStep();
      case TryOnStep.processing:
        return _buildProcessingStep();
      case TryOnStep.result:
        return _buildResultStep();
    }
  }

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // صورة المنتج
          Container(
            width: 160,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.productImage != null && widget.productImage!.isNotEmpty
                  ? AppImage(
                      imageUrl: widget.productImage!,
                      width: 160, height: 200,
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.inventory_2, size: 56, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'تجربة ذكية',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryLabel(),
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الذكاء الاصطناعي سيقوم بتوليد صورة لك وأنت ترتدي هذا المنتج بواقعية',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'للحصول على أفضل نتيجة: التقط صورة واضحة بكامل الجسم مع خلفية بسيطة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // إذا كان مفتاح API مفقوداً، نعرض حقل الإدخال
          if (_isApiKeyMissing)
            _buildApiKeyInput(),

          // صورة الشخص المختارة
          if (_personImage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: 120, height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_personImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            const Text('صورتك', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
          ],

          // أزرار اختيار الصورة
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPhotoButton(
                icon: Icons.camera_alt_rounded,
                label: 'التقاط صورة',
                onTap: _takePhoto,
              ),
              const SizedBox(width: 16),
              _buildPhotoButton(
                icon: Icons.photo_library_outlined,
                label: 'من المعرض',
                onTap: _pickFromGallery,
              ),
            ],
          ),

          if (_personImage != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _startTryOn,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 22),
                label: Text(
                  _isProcessing ? 'جاري المعالجة...' : 'جرب الآن بالذكاء الاصطناعي',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // صورة المنتج تظهر في الأعلى
            Container(
              width: 120, height: 150,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.productImage != null && widget.productImage!.isNotEmpty
                    ? AppImage(imageUrl: widget.productImage!, fit: BoxFit.contain)
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 40),

            // الرسوم المتحركة
            SizedBox(
              width: 80, height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: const Color(0xFF7C4DFF),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF), size: 32),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'الذكاء الاصطناعي يعمل...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'جاري توليد صورتك بالمنتج\nقد تستغرق العملية 30-60 ثانية',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // شريط تقدم متحرك
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 60),
              builder: (context, value, _) {
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF7C4DFF),
                      minHeight: 4,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStep() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_resultImageUrl != null) ...[
                    Container(
                      constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppImage(
                          imageUrl: _resultImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          backgroundColor: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'فشلت المعالجة',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // أزرار النتيجة
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, const Color(0xFF1A1A2E)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_resultImageUrl != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveResult,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('حفظ الصورة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _currentStep = TryOnStep.takePhoto;
                      _resultImageUrl = null;
                      _errorMessage = null;
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(_resultImageUrl != null ? 'تجربة أخرى' : 'إعادة المحاولة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 150,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildApiKeyInput() {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أدخل مفتاح Replicate API',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'r8_...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                AiTryOnService.replicateApiKey = value;
                setState(() => _isApiKeyMissing = false);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'سجل في replicate.com للحصول على مفتاح مجاني',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 768,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() => _personImage = File(photo.path));
      }
    } catch (e) {
      _showError('فشل التقاط الصورة');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() => _personImage = File(photo.path));
      }
    } catch (e) {
      _showError('فشل اختيار الصورة');
    }
  }

  Future<void> _startTryOn() async {
    if (_personImage == null) return;

    // التحقق من مفتاح API
    if (AiTryOnService.replicateApiKey.isEmpty) {
      setState(() => _isApiKeyMissing = true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _currentStep = TryOnStep.processing;
    });

    // إرسال الطلب
    final result = await AiTryOnService.createTryOn(
      personImagePath: _personImage!.path,
      garmentImageUrl: widget.productImage ?? '',
      category: AiTryOnService.categoryForModel(widget.categoryId),
    );

    if (result.id == null) {
      setState(() {
        _isProcessing = false;
        _currentStep = TryOnStep.takePhoto;
        _errorMessage = result.error;
      });
      return;
    }

    _predictionId = result.id;

    // بدء التحقق الدوري
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPrediction());
  }

  Future<void> _checkPrediction() async {
    if (_predictionId == null) return;

    final result = await AiTryOnService.checkPrediction(_predictionId!);

    if (mounted) {
      if (result.isDone) {
        _pollTimer?.cancel();
        setState(() {
          _isProcessing = false;
          if (result.isSuccess) {
            _resultImageUrl = result.outputUrl;
            _currentStep = TryOnStep.result;
          } else {
            _errorMessage = result.error ?? 'فشلت المعالجة';
            _currentStep = TryOnStep.takePhoto;
          }
        });
      }
      // إذا كانت لا تزال قيد المعالجة، ننتظر الدورية التالية
    }
  }

  Future<void> _saveResult() async {
    if (_resultImageUrl == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'try_on_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');

      // تنزيل وحفظ الصورة
      final response = await http.get(Uri.parse(_resultImageUrl!));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('تم حفظ الصورة ✓'),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getCategoryLabel() {
    switch (widget.categoryId) {
      case 'thobes': return 'ثوب';
      case 'bisht': return 'مشلح';
      case 'shemagh': return 'شماغ / غترة';
      default: return 'منتج';
    }
  }
}
