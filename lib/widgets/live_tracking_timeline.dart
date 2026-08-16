import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/order.dart';

/// خط زمني حي لتتبع الطلب — 4 مراحل رئيسية مع نبض متحرك للمرحلة الحالية
///
/// - المراحل المكتملة والحالية: أخضر نجاح / أزرق أمازون مع خطوط موصولة
/// - المراحل القادمة: رمادي خافت
/// - المرحلة الحالية تنبض (TweenAnimationBuilder) لإحساس "مباشر"
class LiveTrackingTimeline extends StatefulWidget {
  final Order order;

  const LiveTrackingTimeline({super.key, required this.order});

  @override
  State<LiveTrackingTimeline> createState() => _LiveTrackingTimelineState();
}

class _LiveTrackingTimelineState extends State<LiveTrackingTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  /// ترتيب المراحل الأربع
  static const List<({String status, String label, IconData icon})>
      _milestones = [
    (
      status: 'confirmed',
      label: 'تم تأكيد الطلب',
      icon: Icons.receipt_long_outlined,
    ),
    (
      status: 'processing',
      label: 'جاري التجهيز',
      icon: Icons.inventory_2_outlined,
    ),
    (
      status: 'shipped',
      label: 'في الطريق إليك',
      icon: Icons.local_shipping_outlined,
    ),
    (
      status: 'delivered',
      label: 'تم التسليم',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// مؤشر المرحلة الحالية: -1 = قيد المراجعة، 0..3 = مرحلة مفعّلة
  int get _currentIndex {
    const order = ['confirmed', 'processing', 'shipped', 'delivered'];
    return order.indexOf(widget.order.status);
  }

  bool get _isCancelled => widget.order.status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    final isActiveOrder = current >= 0 && !_isCancelled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ===== صف المراحل الأفقي =====
          SizedBox(
            height: 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _milestones.length; i++) ...[
                  if (i > 0) _buildConnector(i, current),
                  Expanded(child: _buildMilestone(i, current)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ===== شريط الحالة الحالية =====
          _buildStatusBar(current),
        ],
      ),
    );
  }

  // ======================= مرحلة واحدة =======================

  Widget _buildMilestone(int index, int current) {
    final m = _milestones[index];
    final isCompleted = current > index; // مرحلة انتهت
    final isCurrent = current == index; // المرحلة الحالية (تنبض)
    final isPast = isCompleted || isCurrent;

    final Color color = _isCancelled
        ? AppColors.accent
        : isCompleted
            ? AppColors.success
            : isCurrent
                ? AppColors.amazonBlue
                : AppColors.accent;

    return Column(
      children: [
        // الدائرة + الأيقونة
        SizedBox(
          width: 56,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // هالة النبض للمرحلة الحالية
              if (isCurrent && !_isCancelled)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    return Container(
                      width: 40 + t * 12,
                      height: 40 + t * 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.amazonBlue.withValues(
                          alpha: (1 - t) * 0.28,
                        ),
                      ),
                    );
                  },
                ),
              // الدائرة الأساسية
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPast && !_isCancelled ? color : Colors.white,
                  border: Border.all(
                    color: isPast && !_isCancelled
                        ? color
                        : AppColors.accent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  m.icon,
                  size: 18,
                  color: isPast && !_isCancelled
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // التسمية
        Text(
          m.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isPast && !_isCancelled
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ======================= خط الوصل =======================

  Widget _buildConnector(int index, int current) {
    // الوصلة بين المرحلة (index-1) و (index)
    // مكتملة إذا كانت المرحلة الحالية تجاوزت index
    final isActive = current >= index && !_isCancelled;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 4,
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: isActive ? AppColors.success : AppColors.accentLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ======================= شريط الحالة =======================

  Widget _buildStatusBar(int current) {
    if (_isCancelled) {
      return _statusPill(
        icon: Icons.cancel_outlined,
        text: 'تم إلغاء الطلب',
        color: AppColors.error,
        bg: AppColors.error.withValues(alpha: 0.1),
      );
    }
    if (current < 0) {
      return _statusPill(
        icon: Icons.hourglass_top,
        text: 'قيد المراجعة — بانتظار تأكيد الطلب',
        color: Colors.orange,
        bg: Colors.orange.withValues(alpha: 0.1),
      );
    }
    if (current == _milestones.length - 1) {
      return _statusPill(
        icon: Icons.verified,
        text: 'تم التسليم بنجاح 🎉',
        color: AppColors.success,
        bg: AppColors.success.withValues(alpha: 0.12),
      );
    }
    return _statusPill(
      icon: Icons.bolt,
      text: '${_milestones[current].label} ...',
      color: AppColors.amazonBlue,
      bg: AppColors.amazonBlue.withValues(alpha: 0.1),
      animated: true,
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
    bool animated = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (animated)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Icon(
                icon,
                size: 16,
                color: color.withValues(alpha: 0.6 + _pulse.value * 0.4),
              ),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
