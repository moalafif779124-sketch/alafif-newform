import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// أداة لعرض الصور سواء كانت رابط عادي أو base64
/// تدعم Firebase Storage URLs و base64 data URLs
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Color? backgroundColor;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.backgroundColor,
  });

  bool get _isBase64 => imageUrl.startsWith('data:image/');

  @override
  Widget build(BuildContext context) {
    if (_isBase64) {
      // صورة base64
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
    } else {
      // رابط عادي
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          color: backgroundColor,
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _errorWidget(),
          ),
        ),
      );
    }
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
