import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// أداة لعرض الصور مع التخزين المؤقت التلقائي والتصغير
/// تدعم Firebase Storage URLs و base64 data URLs
/// تستخدم CachedNetworkImage للصور البعيدة مع Placeholder وصور مصغرة
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
      return _buildBase64();
    }
    return _buildNetwork();
  }

  Widget _buildBase64() {
    try {
      final encoded = imageUrl.split(',')[1];
      final bytes = base64Decode(encoded);
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
            errorBuilder: (_, __, ___) => _errorWidget(),
          ),
        ),
      );
    } catch (e) {
      return _errorWidget();
    }
  }

  Widget _buildNetwork() {
    // صورة مصغرة للعرض الأول — 200 بكسل عرض = ¼ دقة HD
    const int thumbWidth = 200;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth ?? thumbWidth,
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
