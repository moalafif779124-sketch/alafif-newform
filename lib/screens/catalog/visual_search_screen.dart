import 'dart:convert';
import 'package:flutter/material.dart';

import '../../config/colors.dart';
import 'catalog_screen.dart';

/// شاشة البحث بالصورة — تعرض الصورة الملتقطة/المختارة
/// وتوجه المستخدم لنتائج البحث (معالجة الصور قيد التطوير)
class VisualSearchScreen extends StatefulWidget {
  /// الصورة بصيغة base64 (data:image/jpeg;base64,...)
  final String imageBase64;

  const VisualSearchScreen({super.key, required this.imageBase64});

  @override
  State<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends State<VisualSearchScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('البحث بالصورة'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ===== الصورة الملتقطة =====
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(
                  widget.imageBase64.replaceFirst(
                    RegExp(r'^data:image/\w+;base64,'),
                    '',
                  ),
                ),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 260,
                  color: AppColors.accentLight,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 60, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ===== حالة المعالجة =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم استلام صورتك بنجاح!\n'
                      'محرك البحث بالصور قيد التجهيز — حالياً يمكنك البحث '
                      'باسم المنتج أو الفئة بدلاً من الصورة.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== البحث بالنص (بديل فوري) =====
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CatalogScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.search, size: 20),
                label: const Text('البحث بالنص بدلاً من الصورة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ===== إعادة اختيار صورة =====
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('إعادة اختيار صورة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
