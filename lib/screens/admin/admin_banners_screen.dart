import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';

/// شاشة إدارة البانرات (الإعلانات)
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
      final banners = await _firebase.getAllBanners();
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

    final titleController = TextEditingController(text: existing?['title'] ?? '');
    final subtitleController = TextEditingController(text: existing?['subtitle'] ?? '');
    final imageUrlController = TextEditingController(text: existing?['imageUrl'] ?? '');
    final buttonTextController = TextEditingController(text: existing?['buttonText'] ?? 'تسوق الآن');
    final orderController = TextEditingController(
      text: (existing?['order'] ?? 0).toString(),
    );
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
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'النص الفرعي',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.subtitles),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الصورة *',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: buttonTextController,
                    decoration: const InputDecoration(
                      labelText: 'نص الزر',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.smart_button),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: orderController,
                    decoration: const InputDecoration(
                      labelText: 'الترتيب',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sort),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'معرف المنتج (للبانر المرتبط بمنتج)',
                      hintText: 'prod_01',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    initialValue: productId ?? '',
                    onChanged: (v) => productId = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'معرف الفئة (للبانر المرتبط بفئة)',
                      hintText: 'thobes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    initialValue: categoryId ?? '',
                    onChanged: (v) => categoryId = v.isEmpty ? null : v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'subtitle': subtitleController.text.trim(),
                  'imageUrl': imageUrlController.text.trim(),
                  'buttonText': buttonTextController.text.trim(),
                  'order': int.tryParse(orderController.text.trim()) ?? 0,
                  'isActive': true,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: $e'), backgroundColor: AppColors.error),
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
                        Icon(Icons.view_carousel_outlined, size: 80,
                            color: AppColors.textSecondary.withValues(alpha: 0.4)),
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
                      itemBuilder: (context, index) {
                        final banner = _banners[index];
                        return _buildBannerCard(banner);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    final isActive = banner['isActive'] as bool? ?? true;
    final title = banner['title'] as String? ?? '';
    final subtitle = banner['subtitle'] as String? ?? '';
    final order = banner['order'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showBannerDialog(existing: banner),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.view_carousel, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('الترتيب: $order', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: () => _toggleBanner(banner),
                child: Text(
                  isActive ? 'نشط' : 'غير نشط',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
