// show: FirebaseAuth فقط — لأن firebase_auth يصدّر أيضاً AuthProvider
// الذي يتعارض مع AuthProvider الخاص بالتطبيق
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/in_store_provider.dart';
import '../../services/in_store_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/barcode_scanner_sheet.dart';
import '../../widgets/fitting_room_status_chip.dart';

/// الوضع الذكي داخل الفرع 🏬
///
/// يتيح للعميل داخل المعرض:
/// - مسح بطاقة المنتج (باركود/QR) لمعرفة التوفّر الحقيقي في المخزن
/// - معاينة إطلالة بالفيديو من تبويب «اكتشف»
/// - طلب إحضار القطعة لغرفة القياس بضغطة واحدة
class InStoreScreen extends StatelessWidget {
  const InStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الوضع الذكي داخل الفرع 🏬'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Consumer<InStoreProvider>(
          builder: (context, store, _) {
            final auth = context.watch<AuthProvider>();
            // معرّف المستخدم يجب أن يطابق request.auth.uid في قواعد Firestore
            final uid =
                FirebaseAuth.instance.currentUser?.uid ?? auth.userId ?? '';
            return Column(
              children: [
                // حالة طلب غرفة القياس — تظهر فقط لصاحب حساب مسجّل
                if (uid.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: FittingRoomStatusChip(userId: uid),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _BranchSelector(store: store),
                      const SizedBox(height: 14),
                      _ScanCard(store: store),
                      const SizedBox(height: 16),
                      if (store.error.isNotEmpty)
                        _ErrorCard(message: store.error),
                      if (store.scannedProduct != null) ...[
                        _ProductResultCard(store: store),
                        const SizedBox(height: 14),
                        _StylistVideoCard(store: store),
                        const SizedBox(height: 16),
                        _FittingRoomRequestCard(store: store),
                      ] else if (store.error.isEmpty && !store.scanning) ...[
                        const _EmptyHint(),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================================================================
// اختيار الفرع
// ====================================================================
class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.store});
  final InStoreProvider store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: store.branches.isEmpty
                ? const Text('جارِ تحميل الفروع…',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<StoreBranch>(
                      value: store.branch,
                      isExpanded: true,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.textPrimary),
                      items: store.branches
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.name,
                                    style: const TextStyle(fontSize: 13.5)),
                              ))
                          .toList(),
                      onChanged: (b) {
                        if (b != null) store.selectBranch(b);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// بطاقة المسح
// ====================================================================
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.store});
  final InStoreProvider store;

  Future<void> _startScan(BuildContext context) async {
    final code = await BarcodeScannerSheet.open(context);
    if (code == null || code.isEmpty) return;
    if (!context.mounted) return;
    await store.handleScan(code);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'امسح بطاقة المنتج',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'اعرف التوفّر الحقيقي في مخزن الفرع فوراً — كل المقاسات والألوان.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: store.scanning ? null : () => _startScan(context),
              icon: store.scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, size: 19),
              label: Text(
                store.scanning ? 'جارِ البحث…' : 'فتح الماسح الضوئي',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amazonBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
          if (store.rawCode.isNotEmpty && store.scannedProduct == null) ...[
            const SizedBox(height: 10),
            Text(
              'الكود المقروء: ${store.rawCode}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// بطاقة نتيجة المنتج (التوفّر بالمقاسات والألوان)
// ====================================================================
class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.store});
  final InStoreProvider store;

  @override
  Widget build(BuildContext context) {
    final product = store.scannedProduct!;
    final variants = product.stockVariants;
    final totalStock = product.stockQuantity;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product.images.isNotEmpty
                    ? AppImage(
                        imageUrl: product.images.first,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        backgroundColor: AppColors.accentLight,
                      )
                    : Container(
                        width: 84,
                        height: 84,
                        color: AppColors.accentLight,
                        child: const Icon(Icons.checkroom,
                            color: AppColors.textSecondary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.effectivePrice.toStringAsFixed(0)} ريال',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'متوفر في فرعك · إجمالي $totalStock قطعة',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'التوفّر حسب المقاس',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (variants.isEmpty)
            const Text(
              'لا تتوفر بيانات مخزون مفصّلة لهذا المنتج',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variants.entries.map((e) {
                final qty = e.value;
                final available = qty > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: available
                        ? AppColors.success.withValues(alpha: 0.10)
                        : AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: available
                          ? AppColors.success.withValues(alpha: 0.45)
                          : AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: available
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      Text(
                        available ? '$qty متوفر' : 'نفد',
                        style: TextStyle(
                          fontSize: 10,
                          color: available
                              ? AppColors.textSecondary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (product.colorOptions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'الألوان المتوفرة',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: product.colorOptions.map((c) {
                final hex = (c['hex'] ?? '#000000').replaceAll('#', '');
                final color = int.tryParse('FF$hex', radix: 16) ?? 0xFF000000;
                return Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 9.5, color: AppColors.textSecondary),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// فيديو الإطلالة (من تبويب «اكتشف»)
// ====================================================================
class _StylistVideoCard extends StatefulWidget {
  const _StylistVideoCard({required this.store});
  final InStoreProvider store;

  @override
  State<_StylistVideoCard> createState() => _StylistVideoCardState();
}

class _StylistVideoCardState extends State<_StylistVideoCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String _loadedUrl = '';

  @override
  void didUpdateWidget(covariant _StylistVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVideo();
  }

  @override
  void initState() {
    super.initState();
    _syncVideo();
  }

  /// يهيّئ مشغّل الفيديو فقط عند وجود رابط، ويحرّر المشغّل القديم
  /// — الكاميرا/الفيديو لا يعملان إلا عند الحاجة (أداء 60fps).
  void _syncVideo() {
    final url = widget.store.videoUrl;
    if (url.isEmpty || url == _loadedUrl) return;
    _loadedUrl = url;
    _disposeController();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted || _controller != controller) return;
      controller.setLooping(true);
      controller.setVolume(0);
      controller.play();
      setState(() => _ready = true);
    }).catchError((e) {
      debugPrint('⚠️ in-store video init failed: $e');
      if (mounted) setState(() => _ready = false);
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.loadingVideo) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.store.videoUrl.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.play_circle_fill,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            const Text(
              'معاينة الإطلالة',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              _ready ? 'اضغط للتحكم' : 'جارِ التحضير…',
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            final c = _controller;
            if (c == null || !_ready) return;
            setState(() {
              c.value.isPlaying ? c.pause() : c.play();
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.black,
              child: _ready && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const Center(
                      child: Icon(Icons.movie_outlined,
                          color: Colors.white24, size: 40),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// زر «إحضار لغرفة القياس»
// ====================================================================
class _FittingRoomRequestCard extends StatefulWidget {
  const _FittingRoomRequestCard({required this.store});
  final InStoreProvider store;

  @override
  State<_FittingRoomRequestCard> createState() =>
      _FittingRoomRequestCardState();
}

class _FittingRoomRequestCardState extends State<_FittingRoomRequestCard> {
  String? _size;
  String _color = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final product = store.scannedProduct!;
    final variants = product.stockVariants;
    // المقاسات المتوفرة فعلاً هي فقط القابلة للطلب.
    // ملاحظة: كثير من منتجات المتجر (معاوز/فنائل/بجائم) بلا مقاسات إطلاقاً —
    // في هذه الحالة نعرض خيار «مقاس موحّد» لتفعيل الطلب بدل تعطيله.
    final availableSizes = variants.isNotEmpty
        ? variants.entries
            .where((e) => e.value > 0)
            .map((e) => e.key)
            .toList()
        : (product.sizes.isNotEmpty ? product.sizes : const <String>['مقاس موحّد']);
    final isOneSize = variants.isEmpty && product.sizes.isEmpty;
    _size ??= availableSizes.isNotEmpty ? availableSizes.first : null;
    _color = _color.isEmpty && product.colorOptions.isNotEmpty
        ? (product.colorOptions.first['name'] ?? '')
        : _color;

    final sent = store.lastRequestId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checkroom, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'إحضار لغرفة القياس',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'سنُبلغ موظفي الفرع بإحضار القطعة والمقاس إلى غرفة القياس.',
            style: TextStyle(
                fontSize: 12, height: 1.6, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          if (availableSizes.isEmpty)
            const Text(
              'لا يوجد مقاس متوفر حالياً في هذا الفرع',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            )
          else ...[
            Text(isOneSize ? 'القطعة بمقاس موحّد (بدون مقاسات)' : 'اختر المقاس',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSizes.map((s) {
                final selected = _size == s;
                return GestureDetector(
                  onTap: () => setState(() => _size = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.accentLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (product.colorOptions.length > 1) ...[
            const SizedBox(height: 12),
            const Text('اختر اللون',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: product.colorOptions.map((c) {
                final name = c['name'] ?? '';
                final selected = _color == name;
                final hex = (c['hex'] ?? '#000000').replaceAll('#', '');
                final color = int.tryParse('FF$hex', radix: 16) ?? 0xFF000000;
                return GestureDetector(
                  onTap: () => setState(() => _color = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (store.sendingRequest ||
                      sent ||
                      _size == null ||
                      availableSizes.isEmpty)
                  ? null
                  : () => _dispatch(context),
              icon: store.sendingRequest
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(sent ? Icons.check_circle : Icons.notifications_active,
                      size: 20),
              label: Text(
                sent
                    ? 'تم إرسال الطلب ✓'
                    : store.sendingRequest
                        ? 'جارِ الإرسال…'
                        : 'إحضار لغرفة القياس',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    sent ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    sent ? AppColors.success : AppColors.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (sent) ...[
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'سيصلك إشعار عند تجهيز القطعة',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _dispatch(BuildContext context) async {
    final store = context.read<InStoreProvider>();
    final auth = context.read<AuthProvider>();
    // معرّف المستخدم يجب أن يطابق request.auth.uid في قواعد Firestore،
    // لذا نأخذ uid من Firebase Auth مباشرة (يعمل مع تسجيل الدخول أو الزائر).
    final userId = FirebaseAuth.instance.currentUser?.uid ?? auth.userId ?? 'guest';

    final ok = await store.requestFittingRoom(
      size: _size ?? '',
      color: _color,
      userId: userId,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok
                    ? 'تم إبلاغ موظفي الفرع — سنجهّز ${_size ?? ''} لك'
                    : (store.error.isNotEmpty
                        ? store.error
                        : 'تعذّر إرسال الطلب'),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ====================================================================
// بطاقات مساعدة
// ====================================================================
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 44, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'امسح بطاقة أي منتج في المعرض\nلتظهر لك الكميات الحقيقية في مخزن الفرع،\nمع معاينة إطلالة بالفيديو وطلب غرفة القياس.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, height: 1.8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
