import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';
import '../auth/login_screen.dart';

/// شاشة إضافة تقييم للمنتج
class AddReviewScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const AddReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  double _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  // ===== ملاءمة المقاس =====
  static const List<String> _fitOptions = ['مناسب تماماً', 'صغير', 'كبير'];
  String _fitFeedback = '';

  // ===== الصور المرفقة =====
  static const int _maxImages = 5;
  final List<XFile> _selectedImages = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// اختيار صور متعددة من المعرض (حتى 5 صور، مضغوطة 1080px)
  Future<void> _pickPhotos() async {
    try {
      if (_selectedImages.length >= _maxImages) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يمكن إرفاق حتى 5 صور فقط'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      final picked = await _picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (picked.isEmpty) return;
      final remaining = _maxImages - _selectedImages.length;
      setState(() {
        _selectedImages.addAll(picked.take(remaining));
      });
      if (picked.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يمكن إرفاق حتى 5 صور فقط'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Photos pick error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submitReview() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة تعليق'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<ReviewProvider>();
    final success = await provider.addReview(
      productId: widget.productId,
      userId: authProvider.userId ?? '',
      userName: authProvider.user?.fullName ?? 'مستخدم',
      rating: _rating,
      comment: _commentController.text.trim(),
      fitFeedback: _fitFeedback,
      imageFilePaths: _selectedImages.map((f) => f.path).toList(),
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('تم إضافة التقييم بنجاح ✓'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إضافة التقييم، حاول مرة أخرى'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقييم المنتج'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // اسم المنتج
              Text(
                widget.productName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),

              // التقييم بالنجوم
              const Text(
                'قيم هذا المنتج',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 44,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: AppColors.rating,
                ),
                onRatingUpdate: (value) {
                  setState(() => _rating = value);
                },
              ),

              const SizedBox(height: 8),
              Text(
                _ratingText,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 32),

              // حقل التعليق
              TextField(
                controller: _commentController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'كتابة تعليق',
                  hintText: 'شارك تجربتك مع هذا المنتج...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                textDirection: TextDirection.rtl,
              ),

              const SizedBox(height: 32),

              // ===== ملاءمة المقاس (True to Size) =====
              const Text(
                'ما مدى ملاءمة المقاس؟',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _fitOptions.map((option) {
                  final selected = _fitFeedback == option;
                  return ChoiceChip(
                    label: Text(option, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => setState(() => _fitFeedback = option),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ===== صور مرفقة (متعددة) =====
              if (_selectedImages.isEmpty)
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 30, color: AppColors.textSecondary),
                        const SizedBox(height: 4),
                        const Text(
                          'إرفاق صور (اختياري)',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      // زر إضافة المزيد
                      if (index == _selectedImages.length) {
                        return GestureDetector(
                          onTap: _pickPhotos,
                          child: Container(
                            width: 84,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                color: AppColors.textSecondary),
                          ),
                        );
                      }
                      // معاينة الصورة مع زر إزالة
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              io.File(_selectedImages[index].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color:
                                    AppColors.border.withValues(alpha: 0.3),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 13),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 32),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReview,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'جاري الإرسال...' : 'إرسال التقييم',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _ratingText {
    if (_rating >= 4.5) return 'ممتاز';
    if (_rating >= 3.5) return 'جيد جداً';
    if (_rating >= 2.5) return 'جيد';
    if (_rating >= 1.5) return 'مقبول';
    return 'سيء';
  }
}
