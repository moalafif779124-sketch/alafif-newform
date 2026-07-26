import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ذاكرة مؤقتة للصور Base64 — تمنع فك التشفير المتكرر لنفس الصورة
final _b64Cache = HashMap<String, Uint8List>();
const int _b64CacheMaxEntries = 50;

/// أداة لعرض الصور مع التخزين المؤقت التلقائي والتصغير في الذاكرة
/// - Base64: مخزنة في ذاكرة مؤقتة بحد أقصى 50 صورة
/// - Network: تستخدم CachedNetworkImage مع memCacheWidth إجباري
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Color? backgroundColor;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.backgroundColor,
    this.cacheWidth,
    this.cacheHeight,
  });

  bool get _isBase64 => imageUrl.startsWith('data:image/');

  @override
  Widget build(BuildContext context) {
    if (_isBase64) {
      return _buildBase64(context);
    }
    return _buildNetwork();
  }

  // ===================== Base64 =====================

  Widget _buildBase64(BuildContext context) {
    try {
      final bytes = _decodeB64(imageUrl);
      // استخدام cacheWidth/cacheHeight لتصغير الصورة في الذاكرة
      final targetW = cacheWidth ?? width?.toInt();
      final targetH = cacheHeight ?? height?.toInt();

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          color: backgroundColor,
          child: Image.memory(
            bytes,
            width: targetW?.toDouble(),
            height: targetH?.toDouble(),
            fit: fit,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _errorWidget(),
          ),
        ),
      );
    } catch (e) {
      return _errorWidget();
    }
  }

  /// فك تشفير Base64 مع تخزين في الذاكرة المؤقتة
  Uint8List _decodeB64(String imageUrl) {
    // البحث في الذاكرة المؤقتة
    if (_b64Cache.containsKey(imageUrl)) {
      return _b64Cache[imageUrl]!;
    }

    final encoded = imageUrl.split(',')[1];
    final bytes = base64Decode(encoded);

    // التخزين مع الحد الأقصى للحجم
    if (_b64Cache.length >= _b64CacheMaxEntries) {
      // إزالة أول عنصر (الأقدم)
      final firstKey = _b64Cache.keys.first;
      _b64Cache.remove(firstKey);
    }
    _b64Cache[imageUrl] = bytes;

    return bytes;
  }

  // ===================== Network =====================

  Widget _buildNetwork() {
    // حجم الصورة المصغرة — ثلث عرض الشاشة كحد أقصى
    const int defaultThumbWidth = 250;
    final effectiveCacheWidth = cacheWidth ?? defaultThumbWidth;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: effectiveCacheWidth,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: backgroundColor ?? Colors.grey[100],
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _errorWidget(),
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
