import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/constants.dart';
import '../../config/colors.dart';
import '../../services/payment_service.dart';

/// شاشة دفع كريمي حاسب — تعرض QR code + رقم نقطة البيع + تعليمات
class KuraimiPaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String posNumber;

  const KuraimiPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.posNumber = AppConstants.kuraimiPosNumber,
  });

  @override
  State<KuraimiPaymentScreen> createState() => _KuraimiPaymentScreenState();
}

class _KuraimiPaymentScreenState extends State<KuraimiPaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;

  /// محتوى QR Code — رابط دفع كريمي
  String get _qrContent =>
      'kuraimi://payment?pos=${widget.posNumber}&amount=${widget.amount.toInt()}';

  /// نسخ رقم نقطة البيع
  void _copyPosNumber() {
    Clipboard.setData(ClipboardData(text: widget.posNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم نسخ رقم نقطة البيع'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// محاولة فتح تطبيق كريمي حاسب
  Future<void> _openKuraimiApp() async {
    setState(() => _isProcessing = true);
    try {
      // محاولة فتح تطبيق كريمي إن وجد
      final installed = await _paymentService.isJeebAppInstalled(); // TODO: تغيير بعد معرفة package name
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(installed
                ? 'تم العثور على تطبيق كريمي'
                : 'تطبيق كريمي غير مثبت — استخدم الرقم اليدوي'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الدفع عبر كريمي حاسب'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 🎉 أيقونة نجاح
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  AppConstants.kuraimiIconPath,
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم تأكيد الطلب!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: #${widget.orderId}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 💰 المبلغ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'المبلغ المطلوب',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.amount.toInt()} ﷼',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🔢 رقم نقطة البيع
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pin, color: Colors.amber, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'رقم نقطة البيع (POS)',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _copyPosNumber,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.posNumber,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.copy_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اضغط للنسخ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 📱 QR Code
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'امسح رمز QR للدفع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'من داخل تطبيق كريمي حاسب',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: _qrContent,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.textPrimary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _qrContent,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 📋 تعليمات
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📌 تعليمات الدفع:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12),
                    _InstructionRow(
                      number: '1',
                      text: 'افتح تطبيق كريمي حاسب',
                    ),
                    SizedBox(height: 8),
                    _InstructionRow(
                      number: '2',
                      text: 'اختر "دفع" أو امسح رمز QR',
                    ),
                    SizedBox(height: 8),
                    _InstructionRow(
                      number: '3',
                      text: 'أدخل رقم نقطة البيع: 1134395',
                    ),
                    SizedBox(height: 8),
                    _InstructionRow(
                      number: '4',
                      text: 'أدخل المبلغ: (يظهر أعلاه)',
                    ),
                    SizedBox(height: 8),
                    _InstructionRow(
                      number: '5',
                      text: 'أكمل عملية الدفع في التطبيق',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ تم الدفع
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    '✅ تم الدفع — العودة للرئيسية',
                    style: TextStyle(fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف تعليمة فردي برقم
class _InstructionRow extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionRow({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
