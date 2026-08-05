import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../config/delivery_config.dart';
import '../../widgets/app_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/points_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/payment_service.dart';
import '../home/home_screen.dart';

/// شاشة إتمام الطلب (Checkout)
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // =========== TextEditingControllers ===========
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // =========== State Variables ===========
  String? _selectedPaymentMethod = 'cod';
  bool _isDefaultAddress = false;
  bool _isSubmitting = false;

  // =========== التوصيل الإقليمي ===========
  String? _selectedCity = DeliveryConfig.defaultCityId;

  // =========== نقاط الاسترداد ===========
  bool _redeemPoints = false;
  double _pointsDiscount = 0;

  // =========== إثبات التحويل (كريمي/جيب) ===========
  final TextEditingController _transferRefController = TextEditingController();
  String _receiptBase64 = '';
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _transferFormKey = GlobalKey<FormState>();

  /// حساب الخصم بالنقاط: 100 نقطة = 375 ريال، بحد أقصى 20% من المجموع الفرعي
  double _calculatePointsDiscount(int points, double subtotal) {
    if (points <= 0) return 0;
    // قيمة النقاط بالريال
    final pointsValue = (points ~/ PointsProvider.pointsPerUnit) *
        PointsProvider.pointsToYerRate;
    // حد 20% من المجموع الفرعي
    final maxDiscount = subtotal * 0.20;
    return pointsValue < maxDiscount ? pointsValue.toDouble() : maxDiscount;
  }

  /// عدد النقاط المطلوب خصمها مقابل الخصم المحسوب
  int _pointsForDiscount(double discount) {
    return ((discount / PointsProvider.pointsToYerRate) *
            PointsProvider.pointsPerUnit)
        .ceil();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _transferRefController.dispose();
    super.dispose();
  }

  /// حساب تكلفة التوصيل الإقليمية (مجاني للطلبات ≥ 50,000)
  double _getShippingCost(double subtotal) {
    return DeliveryConfig.getShippingCost(_selectedCity, subtotal: subtotal);
  }

  /// نسخ نص إلى الحافظة
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم النسخ ✓'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// اختيار صورة إثبات التحويل (مضغوطة 800×800، جودة 75%)
  Future<void> _pickReceiptImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      debugPrint('⚠️ Receipt pick error: $e');
    }
  }

  // ======================== التحقق من الحقول ========================

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('يرجى إدخال الاسم الكامل');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('يرجى إدخال رقم الجوال');
      return false;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('يرجى إدخال العنوان');
      return false;
    }
    if (_districtController.text.trim().isEmpty) {
      _showSnackBar('يرجى إدخال الحي/المنطقة');
      return false;
    }
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showSnackBar('يرجى اختيار المحافظة / المدينة');
      return false;
    }
    if (_selectedPaymentMethod == null) {
      _showSnackBar('يرجى اختيار طريقة الدفع');
      return false;
    }
    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ======================== تأكيد الطلب ========================

  Future<void> _submitOrder() async {
    if (!_validateFields()) return;

    // ===== تحقق من رقم الحوالة عند التحويل (كريمي/جيب) =====
    if (_selectedPaymentMethod == 'kuraimi' ||
        _selectedPaymentMethod == 'jeeb') {
      if (!_transferFormKey.currentState!.validate()) {
        _showSnackBar('يرجى إدخال رقم الحوالة / السند لإكمال الطلب');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final cartProvider = context.read<CartProvider>();
      final orderProvider = context.read<OrderProvider>();
      final pointsProvider = context.read<PointsProvider>();

      if (cartProvider.items.isEmpty) {
        _showSnackBar('سلة التسوق فارغة');
        setState(() => _isSubmitting = false);
        return;
      }

      // حساب الإجمالي مع الخصم بالنقاط
      final pointsDiscount = _redeemPoints
          ? _calculatePointsDiscount(
              pointsProvider.points, cartProvider.subtotal)
          : 0.0;
      final pointsToDeduct = _redeemPoints
          ? _pointsForDiscount(pointsDiscount)
          : 0;

      final shippingAddress = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'fullAddress': _addressController.text.trim(),
        'district': _districtController.text.trim(),
        'city': DeliveryConfig.cityName(_selectedCity),
        'landmark': _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
      };

      // ===== حفظ العنوان الافتراضي (عند التفعيل) =====
      if (_isDefaultAddress && authProvider.userId != null) {
        try {
          final firebaseService = FirebaseService();
          await firebaseService.firestore
              .collection('addresses')
              .add({
            'userId': authProvider.userId,
            'fullName': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'street': _addressController.text.trim(),
            'district': _districtController.text.trim(),
            'city': DeliveryConfig.cityName(_selectedCity),
            'landmark': _landmarkController.text.trim(),
            'state': 'اليمن',
            'isDefault': true,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (e) {
          debugPrint('Error saving default address: $e');
        }
      }

      // ===== بيانات التوصيل الإقليمي (تُحفظ في مستند الطلب) =====
      final shippingCost = _getShippingCost(cartProvider.subtotal);
      final deliveryInfo = <String, dynamic>{
        'city': DeliveryConfig.cityName(_selectedCity),
        'cityId': _selectedCity,
        'streetAddress': _addressController.text.trim(),
        'district': _districtController.text.trim(),
        'nearestLandmark': _landmarkController.text.trim(),
        'recipientPhone': _phoneController.text.trim(),
        'deliveryNotes': _notesController.text.trim(),
        'shippingCost': shippingCost,
      };

      // إنشاء الطلب
      final orderId = await orderProvider.createOrder(
        userId: authProvider.userId ?? '',
        cartItems: cartProvider.items,
        paymentMethod: _selectedPaymentMethod ?? 'cod',
        shippingAddress: shippingAddress,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (orderId != null && mounted) {
        // ===== حفظ بيانات التوصيل الإقليمي في مستند الطلب =====
        try {
          await FirebaseService().firestore
              .collection('orders')
              .doc(orderId)
              .update(deliveryInfo);
        } catch (e) {
          debugPrint('⚠️ Failed to save delivery info: $e');
        }

        // ===== حفظ إثبات التحويل (كريمي/جيب) =====
        final isTransfer = _selectedPaymentMethod == 'kuraimi' ||
            _selectedPaymentMethod == 'jeeb';
        if (isTransfer) {
          final ref = _transferRefController.text.trim();
          final updates = <String, dynamic>{
            'transactionRef': ref,
            'transferMethod': _selectedPaymentMethod,
            if (_receiptBase64.isNotEmpty)
              'receiptImageBase64': _receiptBase64,
          };
          try {
            await FirebaseService().firestore
                .collection('orders')
                .doc(orderId)
                .update(updates);
          } catch (e) {
            debugPrint('⚠️ Failed to save transfer proof: $e');
          }
        }

        // ===== خصم النقاط المستردة وتسجيل المعاملة =====
        if (pointsToDeduct > 0) {
          await pointsProvider.deductPoints(
            pointsToDeduct,
            orderId: orderId,
            note: 'استرداد نقاط في الطلب $orderId',
          );
        }

        // ===== التحقق اليدوي من التحويل — لا حاجة لشاشات الدفع الخارجية =====
        // (كريمي/جيب يتم التحقق منها يدوياً عبر الواتساب بعد الطلب)

        // حساب الإجمالي قبل تفريغ السلة (باستخدام التوصيل الإقليمي)
        final finalTotal = cartProvider.subtotal +
            cartProvider.tax +
            shippingCost -
            pointsDiscount;

        // تفريغ السلة
        cartProvider.clearCart();

        // إظهار حوار النجاح مع زر الواتساب (للتحويلات)
        _showSuccessDialog(
          orderId,
          total: finalTotal,
          showWhatsApp: isTransfer,
        );
      } else {
        if (mounted) {
          _showSnackBar(
            orderProvider.error ?? 'فشل إنشاء الطلب، حاول مرة أخرى',
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting order: $e');
      setState(() => _isSubmitting = false);
      if (mounted) {
        _showSnackBar('حدث خطأ غير متوقع: $e');
      }
    }
  }

  void _showSuccessDialog(String orderId,
      {double total = 0, bool showWhatsApp = false}) {
    final paymentName = _paymentMethodName(_selectedPaymentMethod);
    final ref = _transferRefController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'تم تأكيد الطلب بنجاح!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: $orderId',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الإجمالي: ${AppConstants.currency} ${_formatPrice(total)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                showWhatsApp
                    ? 'يرجى إرسال إشعار التحويل عبر الواتساب لتأكيد طلبك'
                    : 'سيتم التواصل معك لتأكيد الطلب وتفاصيل التوصيل',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            // ===== زر الواتساب (للتحويلات البنكية) =====
            if (showWhatsApp) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openWhatsApp(
                    orderId: orderId,
                    total: total,
                    paymentName: paymentName,
                    ref: ref,
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text(
                    'ارسال إشعار التحويل عبر الواتساب',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // إغلاق الحوار
                  // التنقل إلى الرئيسية وإزالة جميع الشاشات السابقة
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'العودة إلى الرئيسية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// اسم طريقة الدفع بالعربية
  String _paymentMethodName(String? id) {
    switch (id) {
      case 'kuraimi':
        return 'كريمي إكسبرس';
      case 'jeeb':
        return 'محفظة جيب';
      case 'cod':
        return 'الدفع عند الاستلام';
      default:
        return id ?? '';
    }
  }

  /// فتح الواتساب برسالة جاهزة تحتوي تفاصيل الطلب
  Future<void> _openWhatsApp({
    required String orderId,
    required double total,
    required String paymentName,
    required String ref,
  }) async {
    final message = Uri.encodeComponent(
      'مرحباً، قمت بإجراء طلب جديد:\n'
      'رقم الطلب: #$orderId\n'
      'المبلغ الإجمالي: ${total.toStringAsFixed(0)} YER\n'
      'طريقة الدفع: $paymentName\n'
      'رقم الحوالة: $ref',
    );
    // wa.me/<STORE_PHONE>?text=...
    final phone = AppConstants.companyWhatsApp
        .replaceFirst('https://wa.me/', '')
        .trim();
    final url = 'https://wa.me/$phone?text=$message';
    try {
      final launched = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          _showSnackBar('تعذر فتح الواتساب — تأكد من تثبيته');
        }
      }
    } catch (e) {
      debugPrint('⚠️ WhatsApp launch error: $e');
    }
  }

  // ======================== البناء ========================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إتمام الطلب'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // المحتوى القابل للتمرير
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =========== ١. معلومات التوصيل ===========
                    _buildSectionHeader('معلومات التوصيل', Icons.location_on),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'الاسم الكامل',
                                hintText: 'أدخل الاسم الكامل',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'رقم الجوال',
                                hintText: 'أدخل رقم الجوال',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'العنوان',
                                hintText: 'أدخل العنوان بالتفصيل',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _districtController,
                              decoration: const InputDecoration(
                                labelText: 'الحي/المنطقة',
                                hintText: 'أدخل الحي أو المنطقة',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ===== المحافظة / المدينة (قائمة منسدلة) =====
                            DropdownButtonFormField<String>(
                              value: _selectedCity,
                              decoration: const InputDecoration(
                                labelText: 'المحافظة / المدينة',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              items: DeliveryConfig.cities
                                  .map((city) => DropdownMenuItem(
                                        value: city['id'] as String,
                                        child: Text(
                                          '${city['name']} — ${city['shippingCost']} ريال',
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedCity = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            // ===== أقرب معلم =====
                            TextField(
                              controller: _landmarkController,
                              decoration: const InputDecoration(
                                labelText: 'أقرب معلم / جوار',
                                hintText: 'مثال: جوار الجامع الكبير',
                                prefixIcon: Icon(Icons.place_outlined),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile(
                              title: const Text(
                                'تعيين كعنوان افتراضي',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              value: _isDefaultAddress,
                              onChanged: (value) {
                                setState(() => _isDefaultAddress = value);
                              },
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =========== ٢. طريقة الدفع ===========
                    _buildSectionHeader('طريقة الدفع', Icons.payment),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children:
                              AppConstants.paymentMethods.map((method) {
                            final isSelected =
                                _selectedPaymentMethod == method['id'];
                            return RadioListTile<String>(
                              title: Text(
                                method['name'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                method['description'] as String,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              secondary: _buildPaymentIcon(
                                method['icon'] as String,
                                isSelected,
                              ),
                              value: method['id'] as String,
                              groupValue: _selectedPaymentMethod,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(
                                    () => _selectedPaymentMethod = value);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =========== تفاصيل الحساب + إثبات التحويل (كريمي/جيب) ===========
                    if (_selectedPaymentMethod == 'kuraimi' ||
                        _selectedPaymentMethod == 'jeeb')
                      _buildTransferProofSection(),

                    const SizedBox(height: 16),

                    // =========== ٣. ملخص الطلب ===========
                    _buildSectionHeader('ملخص الطلب', Icons.receipt_long),
                    Consumer2<CartProvider, PointsProvider>(
                      builder: (context, cart, points, _) {
                        final subtotal = cart.subtotal;
                        // التوصيل الإقليمي حسب المحافظة (مجاني ≥ 50,000)
                        final shipping = _getShippingCost(subtotal);
                        final tax = cart.tax;

                        // حساب الخصم بالنقاط (عند التفعيل)
                        final pointsDiscount = _redeemPoints
                            ? _calculatePointsDiscount(points.points, subtotal)
                            : 0.0;
                        final total =
                            subtotal + shipping + tax - pointsDiscount;

                        return Column(
                          children: [
                            Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildSummaryRow(
                                      'المجموع الفرعي',
                                      '${AppConstants.currency} ${_formatPrice(subtotal)}',
                                    ),
                                    const Divider(height: 24),
                                    // ===== بطاقة استرداد النقاط =====
                                    if (points.points >=
                                        PointsProvider.pointsPerUnit)
                                      _buildPointsRedemptionCard(
                                        points, subtotal),
                                    const SizedBox(height: 8),
                                    _buildSummaryRow(
                                      'الخصم بالنقاط',
                                      pointsDiscount > 0
                                          ? '-${AppConstants.currency} ${_formatPrice(pointsDiscount)}'
                                          : '${AppConstants.currency} 0',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSummaryRow(
                                      'التوصيل',
                                      shipping == 0
                                          ? 'مجاني'
                                          : '${AppConstants.currency} ${_formatPrice(shipping)}',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSummaryRow(
                                      'الضريبة (${(AppConstants.taxRate * 100).toInt()}%)',
                                      '${AppConstants.currency} ${_formatPrice(tax)}',
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'الإجمالي',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${AppConstants.currency} ${_formatPrice(total)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // ملاحظة: الإجمالي النهائي يُرسل بعد الخصم
                            if (_redeemPoints)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: Text(
                                  'سيتم خصم ${_pointsForDiscount(pointsDiscount)} نقطة من رصيدك عند تأكيد الطلب',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // =========== ٤. ملاحظات ===========
                    _buildSectionHeader('ملاحظات', Icons.notes),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات إضافية',
                            hintText: 'أي ملاحظات إضافية للطلب...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 100), // مساحة للزر السفلي الثابت
                  ],
                ),
              ),
            ),

            // =========== زر تأكيد الطلب السفلي الثابت ===========
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'تأكيد الطلب',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== Widget Helpers ========================

  /// قسم تفاصيل الحساب وإثبات التحويل (كريمي/جيب)
  Widget _buildTransferProofSection() {
    final isKuraimi = _selectedPaymentMethod == 'kuraimi';
    final accountLabel = isKuraimi ? 'رقم نقطة البيع (كريمي)' : 'معرف محفظة جيب';
    final accountValue =
        isKuraimi ? AppConstants.kuraimiPosNumber : AppConstants.jeebPosNumber;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isKuraimi
                          ? Icons.account_balance_wallet_outlined
                          : Icons.wallet_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isKuraimi
                          ? 'كريمي إكسبرس — بيانات التحويل'
                          : 'محفظة جيب — بيانات التحويل',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountValue,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(accountValue),
                        icon: const Icon(Icons.copy,
                            size: 18, color: AppColors.primary),
                        tooltip: 'نسخ',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isKuraimi
                      ? 'حوّل المبلغ إلى الرقم أعلاه ثم أدخل رقم الحوالة وأرفق صورة الإيصال.'
                      : 'حوّل المبلغ إلى معرف جيب أعلاه ثم أدخل رقم العملية وأرفق صورة الإيصال.',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ===== رقم الحوالة =====
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _transferFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رقم الحوالة / السند',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _transferRefController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'مثال: 258741963',
                      prefixIcon: const Icon(Icons.confirmation_number_outlined,
                          size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'أدخل رقم الحوالة لإكمال الطلب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // ===== إرفاق صورة الإيصال =====
                  const Text(
                    'صورة إثبات التحويل',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickReceiptImage,
                    child: Container(
                      height: 90,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _receiptBase64.isNotEmpty
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                      child: _receiptBase64.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppImage(
                                    imageUrl: _receiptBase64,
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _receiptBase64 = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '✓ تم الإرفاق',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 26,
                                    color: AppColors.textSecondary),
                                const SizedBox(height: 4),
                                Text(
                                  'إرفاق صورة الإيصال (اختياري)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بطاقة استرداد النقاط — تبديل + رصيد + قيمة الخصم
  Widget _buildPointsRedemptionCard(
      PointsProvider points, double subtotal) {
    final discount = _calculatePointsDiscount(points.points, subtotal);
    final neededPoints = _pointsForDiscount(discount);
    final pointsValue = ((points.points ~/ PointsProvider.pointsPerUnit) *
            PointsProvider.pointsToYerRate)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _redeemPoints
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _redeemPoints
                    ? Icons.check_circle
                    : Icons.monetization_on_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'استخدام النقاط للخصم',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _redeemPoints,
                onChanged: (v) => setState(() {
                  _redeemPoints = v;
                  _pointsDiscount =
                      v ? _calculatePointsDiscount(points.points, subtotal) : 0;
                }),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'رصيدك: ${points.points} نقطة',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'الخصم: ${AppConstants.currency} ${_formatPrice(discount)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قيمة رصيدك: ${AppConstants.currency} ${_formatPrice(pointsValue)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'تحتاج: $neededPoints نقطة',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الحد الأقصى: 20% من قيمة الطلب (100 نقطة = 375 ريال)',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentIcon(String iconName, bool isSelected) {
    // أيقونة جيب: نستخدم الصورة المرفوعة
    if (iconName == 'jeeb') {
      return _buildImageIcon(AppConstants.jeebIconPath, isSelected);
    }
    // أيقونة كريمي حاسب: نستخدم الصورة المرفوعة
    if (iconName == 'kuraimi') {
      return _buildImageIcon(AppConstants.kuraimiIconPath, isSelected);
    }

    IconData iconData;
    switch (iconName) {
      case 'cash':
        iconData = Icons.money;
        break;
      default:
        iconData = Icons.payment;
    }

    return _buildMaterialIcon(iconData, isSelected);
  }

  /// أيقونة بصورة مرفوعة (جيب، كريمي، إلخ)
  Widget _buildImageIcon(String assetPath, bool isSelected) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          assetPath,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// أيقونة مادية (رمز Material Design)
  Widget _buildMaterialIcon(IconData iconData, bool isSelected) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Icon(
        iconData,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        size: 22,
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
