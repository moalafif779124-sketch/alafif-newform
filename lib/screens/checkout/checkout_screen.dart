import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
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
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // =========== State Variables ===========
  String? _selectedPaymentMethod = 'cod';
  bool _isDefaultAddress = false;
  bool _isSubmitting = false;

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

      if (cartProvider.items.isEmpty) {
        _showSnackBar('سلة التسوق فارغة');
        setState(() => _isSubmitting = false);
        return;
      }

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
        // 🔵 إذا كانت طريقة الدفع هي محفظة جيب، نفتح التطبيق
        if (_selectedPaymentMethod == 'jeeb') {
          final paymentService = PaymentService();
          final jeebResult = await paymentService.launchJeebWallet(
            amount: cartProvider.total,
            orderId: orderId,
            posNumber: AppConstants.jeebPosNumber,
          );

          if (jeebResult) {
            // تم فتح محفظة جيب - نخبر المستخدم بتأكيد الدفع
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '✅ تم فتح محفظة جيب. قم بتأكيد الدفع في التطبيق.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // لم يتم العثور على تطبيق جيب
            if (mounted) {
              _showSnackBar(
                  'تطبيق محفظة جيب غير مثبت على الجهاز');
            }
          }
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
                    Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        final subtotal = cart.subtotal;
                        final shipping = cart.shipping;
                        final tax = cart.tax;
                        final total = cart.total;

                        return Card(
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
                                _buildSummaryRow(
                                  'الخصم',
                                  '${AppConstants.currency} 0',
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
            AppConstants.jeebIconPath,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    IconData iconData;
    switch (iconName) {
      case 'kuraimi':
        iconData = Icons.account_balance_wallet;
        break;
      case 'cash':
        iconData = Icons.money;
        break;
      default:
        iconData = Icons.payment;
    }

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
