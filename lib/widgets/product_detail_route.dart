import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/product.dart';
import '../screens/catalog/product_detail_screen.dart';

/// مسار مؤقت يحمّل المنتج بالمعرّف ثم يفتح صفحة التفاصيل
/// يُستخدم عند النقر على إشعارات التخفيضات الخاطفة
class ProductDetailRoute extends StatefulWidget {
  final String productId;
  const ProductDetailRoute({super.key, required this.productId});

  @override
  State<ProductDetailRoute> createState() => _ProductDetailRouteState();
}

class _ProductDetailRouteState extends State<ProductDetailRoute> {
  Product? _product;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FirebaseService().getProduct(widget.productId);
      if (data == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _product = Product.fromMap(data));
    } catch (e) {
      debugPrint('⚠️ ProductDetailRoute load failed: $e');
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('المنتج')),
        body: const Center(child: Text('عذراً، المنتج غير متوفر')),
      );
    }
    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المنتج')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ProductDetailScreen(product: _product!);
  }
}
