import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../widgets/app_image.dart';

/// شاشة إدارة البانرات — مع إعادة ترتيب وحذف ومعاينة الصور
class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final FirebaseService _firebase = FirebaseService();

  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _loading = true);
    try {
      // استخدام getBannersByOrder للترتيب التصاعدي
      final banners = await _firebase.getBannersByOrder();
      if (mounted) {
        setState(() {
          _banners = banners;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showBannerDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final subtitleC = TextEditingController(text: existing?['subtitle'] ?? '');
    final imageUrlC = TextEditingController(text: existing?['imageUrl'] ?? '');
    final buttonTextC = TextEditingController(text: existing?['buttonText'] ?? 'تسوق الآن');
    final orderC = TextEditingController(text: (existing?['order'] ?? _banners.length).toString());
    String? productId = existing?['productId'];
    String? categoryId = existing?['categoryId'];
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isEdit ? 'تعديل البانر' : 'إضافة بانر جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // معاينة الصورة
                  if (imageUrlC.text.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImage(imageUrl: imageUrlC.text, height: 120, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: subtitleC,
                    decoration: const InputDecoration(labelText: 'النص الفرعي', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subtitles)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageUrlC,
                    decoration: const InputDecoration(labelText: 'رابط الصورة *', hintText: 'https://... أو base64...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.image)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: buttonTextC,
                    decoration: const InputDecoration(labelText: 'نص الزر', border: OutlineInputBorder(), prefixIcon: Icon(Icons.smart_button)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: orderC,
                    decoration: const InputDecoration(labelText: 'الترتيب', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sort)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'معرف المنتج (للبانر المرتبط بمنتج)', hintText: 'prod_01', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                    initialValue: productId ?? '',
                    onChanged: (v) => productId = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'معرف الفئة (للبانر المرتبط بفئة)', hintText: 'mawaz', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                    initialValue: categoryId ?? '',
                    onChanged: (v) => categoryId = v.isEmpty ? null : v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = <String, dynamic>{
                  'title': titleC.text.trim(),
                  'subtitle': subtitleC.text.trim(),
                  'imageUrl': imageUrlC.text.trim(),
                  'buttonText': buttonTextC.text.trim(),
                  'order': int.tryParse(orderC.text.trim()) ?? _banners.length,
                  'isActive': existing?['isActive'] ?? true,
                };
                if (productId != null && productId!.isNotEmpty) data['productId'] = productId;
                if (categoryId != null && categoryId!.isNotEmpty) data['categoryId'] = categoryId;

                try {
                  if (isEdit) {
                    await _firebase.updateBanner(existing['id'], data);
                  } else {
                    await _firebase.addBanner(data);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'تحديث' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) _loadBanners();
  }

  Future<void> _toggleBanner(Map<String, dynamic> banner) async {
    try {
      await _firebase.updateBanner(banner['id'], {'isActive': !(banner['isActive'] ?? true)});
      _loadBanners();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحديث: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف البانر'),
          content: Text('هل تريد حذف "${banner['title'] ?? ''}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _firebase.deleteBanner(banner['id']);
        _loadBanners();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف'), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: AppColors.error),
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
          title: const Text('إدارة البانرات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showBannerDialog(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _banners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_carousel_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('لا توجد بانرات', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showBannerDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة بانر جديد'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBanners,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _banners.length,
                      itemBuilder: (context, index) => _buildBannerCard(_banners[index], index),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner, int index) {
    final isActive = banner['isActive'] as bool? ?? true;
    final title = banner['title'] as String? ?? '';
    final subtitle = banner['subtitle'] as String? ?? '';
    final order = banner['order'] ?? index;
    final imageUrl = banner['imageUrl'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // رقم الترتيب
            Container(
              width: 36, height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${order + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            // صورة مصغرة
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(imageUrl: imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                ),
              ),
            // تفاصيل البانر
            Expanded(
              child: GestureDetector(
                onTap: () => _showBannerDialog(existing: banner),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: GestureDetector(
                            onTap: () => _toggleBanner(banner),
                            child: Text(
                              isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.error),
                            ),
                          ),
                        ),
                        if (banner['productId'] != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.link, size: 12, color: AppColors.info),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // زر الحذف
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withValues(alpha: 0.7)),
              onPressed: () => _deleteBanner(banner),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}
