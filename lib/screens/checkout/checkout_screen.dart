import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/points_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/payment_service.dart';
import '../home/home_screen.dart';
import '../payment/jeeb_payment_screen.dart' deferred as jeeb;
import '../payment/kuraimi_payment_screen.dart' deferred as kuraimi;

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
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // =========== State Variables ===========
  String? _selectedPaymentMethod = 'cod';
  bool _isDefaultAddress = false;
  bool _isSubmitting = false;

  // =========== نقاط الاسترداد ===========
  bool _redeemPoints = false;
  double _pointsDiscount = 0;

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
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
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
    if (_cityController.text.trim().isEmpty) {
      _showSnackBar('يرجى إدخال المدينة');
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
        'city': _cityController.text.trim(),
        'landmark': null,
      };

      // حفظ العنوان كعنوان افتراضي إذا تم اختياره
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
            'city': _cityController.text.trim(),
            'state': 'أمانة العاصمة',
            'isDefault': true,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (e) {
          debugPrint('Error saving default address: $e');
        }
      }

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
        // ===== خصم النقاط المستردة وتسجيل المعاملة =====
        if (pointsToDeduct > 0) {
          await pointsProvider.deductPoints(
            pointsToDeduct,
            orderId: orderId,
            note: 'استرداد نقاط في الطلب $orderId',
          );
        }

        // 🔵 إذا كانت طريقة الدفع هي محفظة جيب — ننتقل لشاشة الدفع (QR + تعليمات)
        if (_selectedPaymentMethod == 'jeeb') {
          await jeeb.loadLibrary();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => jeeb.JeebPaymentScreen(
                orderId: orderId,
                amount: cartProvider.total,
                posNumber: AppConstants.jeebPosNumber,
              ),
            ),
          );
          return; // JeebPaymentScreen تتعامل مع rest
        }

        // 🔵 إذا كانت طريقة الدفع هي كريمي حاسب — ننتقل لشاشة الدفع
        if (_selectedPaymentMethod == 'kuraimi') {
          await kuraimi.loadLibrary();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => kuraimi.KuraimiPaymentScreen(
                orderId: orderId,
                amount: cartProvider.total,
                posNumber: AppConstants.kuraimiPosNumber,
              ),
            ),
          );
          return;
        }

        // تفريغ السلة
        cartProvider.clearCart();

        // إظهار حوار النجاح
        _showSuccessDialog(orderId);
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

  void _showSuccessDialog(String orderId) {
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
              const SizedBox(height: 8),
              const Text(
                'سيتم التواصل معك لتأكيد الطلب وتفاصيل التوصيل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
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
                            TextField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'المدينة',
                                hintText: 'أدخل المدينة',
                                prefixIcon: Icon(Icons.location_city),
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

                    // =========== ٣. ملخص الطلب ===========
                    _buildSectionHeader('ملخص الطلب', Icons.receipt_long),
                    Consumer2<CartProvider, PointsProvider>(
                      builder: (context, cart, points, _) {
                        final subtotal = cart.subtotal;
                        final shipping = cart.shipping;
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
