/// الثوابت العامة للتطبيق
class AppConstants {
  AppConstants._();

  // =========== معلومات التطبيق ===========
  static const String appName = 'العفيف نيوفورم';
  static const String appNameEn = 'ALAFIF NEWFORM';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'الأناقة الرجالية الفاخرة';

  // =========== معلومات المتجر ===========
  static const String companyName = 'العفيف نيوفورم للملابس الرجالية';
  static const String companyPhone = '+967123456789';
  static const String companyEmail = 'info@alafif-newform.com';
  static const String companyAddress = 'صنعاء، اليمن';
  static const String companyWhatsApp = 'https://wa.me/967123456789';

  // =========== فئات المنتجات ===========
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'thobes',
      'name': 'الثياب',
      'nameEn': 'Thobes',
      'icon': 'thobe',
    },
    {
      'id': 'suits',
      'name': 'البذلات',
      'nameEn': 'Suits',
      'icon': 'suit',
    },
    {
      'id': 'shirts',
      'name': 'القمصان',
      'nameEn': 'Shirts',
      'icon': 'shirt',
    },
    {
      'id': 'trousers',
      'name': 'السراويل',
      'nameEn': 'Trousers',
      'icon': 'trouser',
    },
    {
      'id': 'accessories',
      'name': 'الإكسسوارات',
      'nameEn': 'Accessories',
      'icon': 'accessory',
    },
    {
      'id': 'winter',
      'name': 'المشالح والشتوي',
      'nameEn': 'Mashlah & Winter',
      'icon': 'winter',
    },
  ];

  // =========== خيارات المقاسات ===========
  static const List<String> sizesThobes = ['52', '54', '56', '58', '60', '62'];
  static const List<String> sizesSuits = ['S', 'M', 'L', 'XL', 'XXL', '3XL'];
  static const List<String> sizesShirts = ['S', 'M', 'L', 'XL', 'XXL', '3XL'];
  static const List<String> sizesTrousers = ['30', '32', '34', '36', '38', '40'];

  // =========== خيارات الألوان ===========
  static const List<Map<String, dynamic>> colorOptions = [
    {'name': 'أسود', 'hex': '#000000'},
    {'name': 'أبيض', 'hex': '#FFFFFF'},
    {'name': 'كحلي', 'hex': '#0D1B3E'},
    {'name': 'رمادي', 'hex': '#808080'},
    {'name': 'بيج', 'hex': '#F5F5DC'},
    {'name': 'بني', 'hex': '#8B4513'},
    {'name': '#008000', 'hex': '#008000'},
    {'name': 'أحمر', 'hex': '#B22222'},
  ];

  // =========== خيارات الفرز ===========
  static const List<Map<String, dynamic>> sortOptions = [
    {'id': 'newest', 'label': 'الأحدث'},
    {'id': 'price_asc', 'label': 'السعر: من الأقل إلى الأعلى'},
    {'id': 'price_desc', 'label': 'السعر: من الأعلى إلى الأقل'},
    {'id': 'popular', 'label': 'الأكثر شهرة'},
    {'id': 'name', 'label': 'الاسم'},
  ];

  // =========== جيب (Jeeb Wallet) ===========
  static const String jeebPosNumber = '573157'; // رقم نقطة البيع لمحفظة جيب
  static const String jeebPackageName = 'com.ahd.jaib'; // حزمة تطبيق جيب على أندرويد
  static const String jeebIconPath = 'assets/images/jeeb_icon.png';

  // =========== طرق الدفع ===========
  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'id': 'kuraimi',
      'name': 'كريمي باي',
      'nameEn': 'Kuraimi Pay',
      'icon': 'kuraimi',
      'description': 'الدفع عبر محفظة كريمي',
    },
    {
      'id': 'jeeb',
      'name': 'جيب',
      'nameEn': 'Jeeb',
      'icon': 'jeeb',
      'iconPath': jeebIconPath,
      'description': 'الدفع عبر محفظة جيب - فتح التطبيق مباشرة',
    },
    {
      'id': 'cod',
      'name': 'الدفع عند الاستلام',
      'nameEn': 'Cash on Delivery',
      'icon': 'cash',
      'description': 'الدفع نقداً عند استلام الطلب',
    },
  ];

  // =========== عملة المتجر ===========
  static const String currency = '﷼';
  static const String currencyCode = 'YER';
  static const double taxRate = 0.05; // 5% ضريبة
  static const double shippingCost = 3000; // 3000 ريال توصيل

  // =========== حدود ===========
  static const int maxCartItems = 50;
  static const int productsPerPage = 20;
  static const int maxAddressesPerUser = 5;

  // =========== Firebase Collections ===========
  static const String firebaseProducts = 'products';
  static const String firebaseUsers = 'users';
  static const String firebaseOrders = 'orders';
  static const String firebaseCategories = 'categories';
  static const String firebaseCarts = 'carts';
  static const String firebaseAddresses = 'addresses';
  static const String firebaseBanners = 'banners';
  static const String firebaseReviews = 'reviews';
}
