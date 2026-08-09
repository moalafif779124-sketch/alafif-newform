import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/points_provider.dart';
import '../../services/firebase_service.dart';

/// شاشة "شارك واكسب" — نظام الإحالة
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isActivating = false;
  String _referralCode = '';
  String _referredBy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// تحميل كود الإحالة (إنشاؤه تلقائياً إن لم يوجد)
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null || userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    var code = auth.user?.referralCode ?? '';
    if (code.isEmpty) {
      code = await _firebaseService.ensureReferralCode(userId);
      // تحديث جلسة المستخدم في الذاكرة
      if (code.isNotEmpty) await auth.refreshUser();
    }
    if (mounted) {
      setState(() {
        _referralCode = code;
        _referredBy = auth.user?.referredBy ?? '';
        _isLoading = false;
      });
    }
  }

  /// نسخ الكود
  Future<void> _copyCode() async {
    if (_referralCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _referralCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود ✓'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// مشاركة الكود عبر واتساب/رسائل/أي تطبيق
  Future<void> _shareCode() async {
    if (_referralCode.isEmpty) return;
    await Share.share(
      'انضم إليّ على العفيف نيوفورم 🎁 استخدم كود الدعوة الخاص بي واحصل على 50 نقطة: $_referralCode',
      subject: 'شارك واكسب — العفيف نيوفورم',
    );
  }

  /// تفعيل كود دعوة صديق
  Future<void> _activateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كود الدعوة'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isActivating = true);
    final success = await _firebaseService.activateReferral(
      refereeUid: userId,
      refereeName: auth.user?.fullName ?? 'مستخدم',
      code: code,
    );
    if (!mounted) return;
    setState(() => _isActivating = false);

    if (success) {
      // تحديث بيانات المستخدم والنقاط
      await auth.refreshUser();
      if (!mounted) return;
      context.read<PointsProvider>().initialize(userId);
      setState(() {
        _referredBy = auth.user?.referredBy ?? code.toUpperCase();
        _codeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 تم تفعيل كود الدعوة! حصلت على 50 نقطة'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الكود غير صالح أو تم استخدامه من قبل'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('شارك واكسب'),
          centerTitle: true,
          backgroundColor: AppColors.background,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== البطاقة الرئيسية =====
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF1F5AA8)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard,
                              color: Colors.white, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'ادعُ أصدقاءك واكسب النقاط',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'شارك كودك — أنت وصديقك تحصلان على 50 نقطة لكل دعوة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // الكود
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _referralCode.isEmpty ? 'جاري الإنشاء...' : _referralCode,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppColors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // أزرار النسخ والمشاركة
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyCode,
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('نسخ'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _shareCode,
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('مشاركة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== رصيد النقاط =====
                    Consumer<PointsProvider>(
                      builder: (context, points, _) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                color: AppColors.rating, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'رصيدك: ${points.points} نقطة',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== تفعيل كود صديق =====
                    if (_referredBy.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'هل لديك كود دعوة من صديق؟',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'أدخل الكود واحصل على 50 نقطة فوراً',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: AppColors.primary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'أدخل كود دعوة صديقك',
                                hintTextDirection: TextDirection.rtl,
                                prefixIcon: const Icon(Icons.redeem,
                                    color: AppColors.textSecondary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onSubmitted: (_) => _activateCode(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _isActivating ? null : _activateCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isActivating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('تفعيل',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // تم تفعيل كود مسبقاً
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.success, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تم تفعيل كود الدعوة: $_referredBy ✓',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ===== كيف تعمل؟ =====
                    const Text(
                      'كيف تعمل؟',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStep('1', 'شارك كودك مع أصدقائك عبر واتساب أو أي تطبيق'),
                    const SizedBox(height: 8),
                    _buildStep('2', 'عند استخدامهم للكود تحصل أنت على 50 نقطة'),
                    const SizedBox(height: 8),
                    _buildStep('3', 'صديقك يحصل أيضاً على 50 نقطة فور التفعيل'),
                    const SizedBox(height: 8),
                    _buildStep('4', 'استبدل نقاطك بخصومات على طلباتك (100 نقطة = 375 ريال)'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
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
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
