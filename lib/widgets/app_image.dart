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

  /// كشف قاعدة 64 — مع مرونة للمسافات البيضاء
  bool get _isBase64 {
    final trimmed = imageUrl.trim();
    return trimmed.startsWith('data:image/');
  }

  /// رابط صحيح قابل للتحميل
  bool get _isValidUrl {
    final trimmed = imageUrl.trim();
    return trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') ||
            trimmed.startsWith('https://') ||
            trimmed.startsWith('data:image/'));
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    // رابط فارغ — ارجع فوراً أيقونة الخطأ بدون سبينر
    if (url.isEmpty) {
      return _errorWidget();
    }

    if (url.startsWith('data:image/')) {
      return _buildBase64(context, url);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return _buildNetwork(url);
    }

    // رابط غير معروف — أيقونة خطأ
    return _errorWidget();
  }

  // ===================== Base64 =====================

  Widget _buildBase64(BuildContext context, String url) {
    try {
      final bytes = _decodeB64(url);

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          color: backgroundColor,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _errorWidget(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('🧩 AppImage base64 error: $e');
      return _errorWidget();
    }
  }

  /// فك تشفير Base64 — يتعامل مع وجود أو غياب البادئة
  Uint8List _decodeB64(String raw) {
    // البحث في الذاكرة المؤقتة
    if (_b64Cache.containsKey(raw)) {
      return _b64Cache[raw]!;
    }

    // تنظيف السلسلة: إزالة البادئة data:image/...;base64,
    String clean;
    if (raw.contains(',')) {
      clean = raw.split(',').last.trim();
    } else {
      clean = raw.trim();
    }

    // إزالة أي مسافات بيضاء أو أسطر جديدة
    clean = clean.replaceAll(RegExp(r'\s'), '');

    final bytes = base64Decode(clean);

    // التخزين في الذاكرة المؤقتة
    if (_b64Cache.length >= _b64CacheMaxEntries) {
      final firstKey = _b64Cache.keys.first;
      _b64Cache.remove(firstKey);
    }
    _b64Cache[raw] = bytes;

    return bytes;
  }

  // ===================== Network =====================

  Widget _buildNetwork(String url) {
    const int defaultThumbWidth = 300;
    final effectiveCacheWidth = cacheWidth ?? defaultThumbWidth;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
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
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('🧩 AppImage network error: $error');
          return _errorWidget();
        },
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: (width ?? 48) * 0.35,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
