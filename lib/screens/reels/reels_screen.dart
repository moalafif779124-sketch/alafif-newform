import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../services/firebase_service.dart';
import '../catalog/product_detail_screen.dart';

/// شاشة "اكتشف" — بث فيديوهات المنتجات بأسلوب Reels (تمرير عمودي)
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final FirebaseService _firebase = FirebaseService();
  List<Product> _products = [];
  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _firebase.getReelsProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _products.isEmpty
                ? _buildEmptyState()
                : PageView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: _products.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) => _ReelPage(
                      key: ValueKey(_products[index].id),
                      product: _products[index],
                      isActive: index == _currentPage,
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('اكتشف'),
        centerTitle: true,
        backgroundColor: AppColors.background,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'لا توجد فيديوهات بعد',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'عند إضافة المنتجات مع فيديو ستظهر هنا',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }
}

/// صفحة Reel واحدة — فيديو بملء الشاشة + تفاصيل المنتج
class _ReelPage extends StatefulWidget {
  final Product product;
  final bool isActive;

  const _ReelPage({super.key, required this.product, required this.isActive});

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = widget.product.videoUrl.trim();
      if (url.isEmpty) {
        setState(() => _failed = true);
        return;
      }
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      if (widget.isActive) {
        await controller.play();
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('⚠️ Reel init failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(_ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      final c = _controller;
      if (c == null || !_ready) return;
      if (widget.isActive) {
        c.play();
      } else {
        c.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ===== الفيديو (تغطية كاملة) =====
        if (_failed)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white54, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'تعذر تشغيل الفيديو',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.product.videoUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (!_ready)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          GestureDetector(
            onTap: _toggleMute,
            child: Container(
              color: Colors.black,
              child: Center(
                child: _controller!.value.size.width > 0
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

        // ===== أيقونة كتم/تشغيل الصوت =====
        if (_ready && !_failed)
          Positioned(
            bottom: 140,
            left: 14,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

        // ===== معلومات المنتج + تسوق الآن =====
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${widget.product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                      style: const TextStyle(
                        color: AppColors.rating,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.product.hasOldPrice) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${widget.product.oldPrice!.toStringAsFixed(0)} ${AppConstants.currency}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    if (widget.product.rating > 0) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.star_rounded,
                          color: AppColors.rating, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        widget.product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(product: widget.product),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text(
                      'تسوق الآن',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
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
      ],
    );
  }
}
