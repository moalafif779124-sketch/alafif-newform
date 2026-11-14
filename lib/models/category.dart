/// نموذج فئة المنتج
class Category {
  final String id;
  final String name;
  final String nameEn;
  final String icon;
  final String? imageUrl;
  final int productCount;
  final bool isActive;

  /// ترتيب الفئة في العرض — يُدار من تطبيق الإدارة (أصغر رقم = أولاً)
  final int order;

  Category({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.icon,
    this.imageUrl,
    this.productCount = 0,
    this.isActive = true,
    this.order = 0,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameEn: map['nameEn'] ?? '',
      icon: map['icon'] ?? '',
      imageUrl: map['imageUrl'],
      productCount: map['productCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      order: (map['order'] is num) ? (map['order'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'icon': icon,
      'imageUrl': imageUrl,
      'productCount': productCount,
      'isActive': isActive,
      'order': order,
    };
  }
}
