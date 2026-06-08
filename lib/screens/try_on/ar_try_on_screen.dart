import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../widgets/app_image.dart';

/// شاشة التجربة الافتراضية (Virtual Try-On)
/// تلتقط صورة المستخدم ثم تضع المنتج فوقها مع إمكانية التحريك والتحجيم
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
  File? _userImage;
  bool _hasPhoto = false;

  // Overlay state
  double _overlayScale = 0.4;
  double _overlayOpacity = 0.85;
  Offset _overlayPosition = Offset(0, 0);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          title: Text(widget.productName, style: const TextStyle(fontSize: 16)),
          centerTitle: true,
          actions: [
            if (_hasPhoto) ...[
              IconButton(
                icon: const Icon(Icons.save_alt_rounded),
                onPressed: _saveImage,
                tooltip: 'حفظ الصورة',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _resetOverlay,
                tooltip: 'إعادة تعيين',
              ),
            ],
          ],
        ),
        body: _hasPhoto ? _buildTryOnView() : _buildStartView(),
      ),
    );
  }

  Widget _buildStartView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة المنتج
          Container(
            width: 180,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.productImage != null && widget.productImage!.isNotEmpty
                  ? AppImage(
                      imageUrl: widget.productImage!,
                      width: 180,
                      height: 240,
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.inventory_2, size: 64, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'تجربة افتراضية',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryLabel(),
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'التقط صورة سيلفي كاملة لترى كيف يبدو المنتج عليك',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 40),

          // زر التقاط الصورة
          SizedBox(
            width: 220,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt_rounded, size: 22),
              label: const Text('التقاط صورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white54),
            label: const Text('اختيار من المعرض', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildTryOnView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // صورة المستخدم
        Image.file(
          _userImage!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),

        // المنتج متراكب
        if (widget.productImage != null && widget.productImage!.isNotEmpty)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // تعيين الموضع الافتراضي بناءً على الفئة
                if (_overlayPosition == Offset.zero) {
                  _setDefaultPosition(constraints);
                }

                final overlayWidth = constraints.maxWidth * _overlayScale;
                final overlayHeight = overlayWidth * _getAspectRatio();

                return Positioned(
                  left: constraints.maxWidth / 2 - overlayWidth / 2 + _overlayPosition.dx,
                  top: _overlayPosition.dy,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isDragging = true),
                    onPanUpdate: (details) {
                      setState(() => _overlayPosition += details.delta);
                    },
                    onPanEnd: (_) => setState(() => _isDragging = false),
                    child: Opacity(
                      opacity: _overlayOpacity,
                      child: Container(
                        width: overlayWidth,
                        height: overlayHeight,
                        decoration: BoxDecoration(
                          border: _isDragging
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AppImage(
                          imageUrl: widget.productImage!,
                          width: overlayWidth,
                          height: overlayHeight,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // أدوات التحكم
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildControls(),
        ),
      ],
    );
  }

  void _setDefaultPosition(BoxConstraints constraints) {
    setState(() {
      if (widget.categoryId == 'shemagh') {
        _overlayPosition = Offset(0, constraints.maxHeight * 0.02);
      } else if (widget.categoryId == 'bisht') {
        _overlayPosition = Offset(0, constraints.maxHeight * 0.12);
      } else {
        // thobes and others
        _overlayPosition = Offset(0, constraints.maxHeight * 0.08);
      }
    });
  }

  double _getAspectRatio() {
    switch (widget.categoryId) {
      case 'shemagh':
        return 0.6; // عرضي (عرض > ارتفاع)
      case 'bisht':
        return 1.6; // طويل
      case 'thobes':
        return 2.2; // طويل جداً (ثوب كامل)
      default:
        return 1.5;
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

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط التحكم في الشفافية
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Text('الشفافية', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white10,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _overlayOpacity,
                    min: 0.2, max: 1.0,
                    onChanged: (v) => setState(() => _overlayOpacity = v),
                  ),
                ),
              ),
              Text('${(_overlayOpacity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          // شريط التحكم في الحجم
          Row(
            children: [
              const Icon(Icons.photo_size_select_large, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              const Text('الحجم', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white10,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _overlayScale,
                    min: 0.2, max: 0.8,
                    onChanged: (v) => setState(() => _overlayScale = v),
                  ),
                ),
              ),
              Text('${(_overlayScale * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // تعليمات السحب
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'اسحب المنتج إلى الموضع المناسب على الصورة',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() {
          _userImage = File(photo.path);
          _hasPhoto = true;
          _resetOverlay();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التقاط الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() {
          _userImage = File(photo.path);
          _hasPhoto = true;
          _resetOverlay();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل اختيار الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _resetOverlay() {
    setState(() {
      _overlayPosition = Offset.zero;
      _overlayScale = 0.4;
      _overlayOpacity = 0.85;
    });
  }

  Future<void> _saveImage() async {
    try {
      // حفظ الصورة مع المنتج المتراكب (نسخة بسيطة)
      final dir = await getTemporaryDirectory();
      final fileName = 'try_on_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${dir.path}/$fileName';

      if (_userImage != null) {
        await _userImage!.copy(savedPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('تم حفظ الصورة ✓'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }
}
