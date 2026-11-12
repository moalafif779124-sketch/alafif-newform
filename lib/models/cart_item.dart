import 'product.dart';

/// نموذج عنصر في سلة التسوق
class CartItem {
  final String id;
  final Product product;
  final String size;
  final String color;
  final String colorHex;

  /// مصدر القطعة: `stylist` (توصية المصمم الذكي) أو `outfit` (طقم منسّق في
  /// الإدارة) أو '' للقطعة المفردة.
  final String bundleSource;

  /// معرّف الطقم الذي تنتمي إليه القطعة. فارغ = قطعة مفردة لا تدخل في
  /// حساب خصم الطقم (انظر `BundlePricing`).
  final String bundleGroupId;

  int quantity;

  CartItem({
    required this.id,
    required this.product,
    required this.size,
    required this.color,
    this.colorHex = '#000000',
    this.bundleSource = '',
    this.bundleGroupId = '',
    this.quantity = 1,
  });

  /// هل هذه القطعة جزء من طقم مؤهّل لخصم الطقم؟
  bool get isBundled => bundleGroupId.isNotEmpty;

  double get totalPrice => product.price * quantity;

  double get totalEffectivePrice => product.effectivePrice * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map, Product product) {
    return CartItem(
      id: map['id'] ?? '',
      product: product,
      size: map['size'] ?? '',
      color: map['color'] ?? '',
      colorHex: map['colorHex'] ?? '#000000',
      bundleSource: map['bundleSource'] ?? '',
      bundleGroupId: map['bundleGroupId'] ?? '',
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': product.id,
      'size': size,
      'color': color,
      'colorHex': colorHex,
      'bundleSource': bundleSource,
      'bundleGroupId': bundleGroupId,
      'quantity': quantity,
    };
  }
}
