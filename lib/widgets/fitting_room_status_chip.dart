import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../services/in_store_service.dart';

/// شريط حالة طلب غرفة القياس — يظهر داخل شاشة «الوضع الذكي داخل الفرع»
///
/// يتتبّع طلبات العميل الحالية لحظياً (Stream على `fitting_room_requests`)
/// ويعرض بطاقة حالة واحدة فقط لأحدث طلب نشط:
/// - `pending`  → «قيد الانتظار» (كهرماني)
/// - `accepted` → «جاري الإحضار» (أزرق)
/// - `ready`    → «جاهز في غرفة القياس» (أخضر + نبض)
/// - `done` / `cancelled` → تختفي تلقائياً بعد 5 ثوانٍ أو بلمسة واحدة
///
/// الضغط على البطاقة يفتح ورقة سفلية بتفاصيل الطلب (المنتج، الكود، المقاس،
/// اللون، الفرع) مع زر «إلغاء الطلب» ما دام الطلب في حالة الانتظار.
class FittingRoomStatusChip extends StatefulWidget {
  const FittingRoomStatusChip({super.key, required this.userId});

  /// معرّف المستخدم الحالي — يجب أن يطابق `request.auth.uid`
  final String userId;

  /// مدة إظهار الحالات المنتهية قبل الاختفاء التلقائي
  static const Duration autoDismissAfter = Duration(seconds: 5);

  @override
  State<FittingRoomStatusChip> createState() => _FittingRoomStatusChipState();
}

class _FittingRoomStatusChipState extends State<FittingRoomStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  /// معرّف الطلب الذي انتهى عرضه (بعد انتهاء المهلة أو بعد اللمس)
  String _hiddenRequestId = '';

  /// معرّف الطلب الذي شُغّل له مؤقّت الاختفاء
  String _timerRequestId = '';

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// يُدار مؤقّت الاختفاء للحالات المنتهية (تم التسليم / ملغي)
  void _scheduleAutoDismiss(String requestId) {
    if (_hiddenRequestId == requestId) return;
    if (_timerRequestId == requestId) return;
    _timerRequestId = requestId;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(FittingRoomStatusChip.autoDismissAfter, () {
      if (!mounted) return;
      setState(() => _hiddenRequestId = requestId);
    });
  }

  void _cancelAutoDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _timerRequestId = '';
  }

  void _syncPulse(bool shouldPulse) {
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: InStoreService.instance.watchMyRequests(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('⚠️ fitting-room status stream error: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        // الفرز في الواجهة — الاستعلام بلا orderBy (تفادياً لفهرس مركّب)
        final sorted = [...docs]..sort((a, b) {
            final av = _createdAt(a.data());
            final bv = _createdAt(b.data());
            return bv.compareTo(av);
          });
        final request = sorted.first;
        final data = request.data();
        final status = (data['status'] as String?) ?? 'pending';

        if (status == 'pending' || status == 'accepted' || status == 'ready') {
          _cancelAutoDismiss();
          if (_hiddenRequestId.isNotEmpty && _hiddenRequestId != request.id) {
            // طلب جديد بعد اختفاء طلب قديم
            _hiddenRequestId = '';
          }
        } else {
          if (_hiddenRequestId == request.id) return const SizedBox.shrink();
          _scheduleAutoDismiss(request.id);
        }

        final style = _StatusStyle.of(status);
        _syncPulse(status == 'ready');

        final card = _StatusCard(
          data: data,
          style: style,
          onTap: () => _openDetails(context, request.id, data),
          pulse: _pulse,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Dismissible(
            key: ValueKey('fitting-room-${request.id}'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => setState(() => _hiddenRequestId = request.id),
            child: card,
          ),
        );
      },
    );
  }

  static int _createdAt(Map<String, dynamic> data) {
    final value = data['createdAt'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> _openDetails(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final isPending = ((data['status'] as String?) ?? '') == 'pending';
    final cancelled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailsSheet(
        data: data,
        cancellable: isPending,
      ),
    );
    if (cancelled != true) return;

    try {
      await InStoreService.instance.cancelFittingRoomRequest(requestId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء الطلب'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ cancel fitting-room request failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذّر إلغاء الطلب — حاول مرة أخرى'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// وصف الحالة: لون + أيقونة + نصوص عربية
class _StatusStyle {
  const _StatusStyle({
    required this.color,
    required this.background,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
  });

  final Color color;
  final Color background;
  final IconData icon;
  final String title;
  final String subtitle;
  final String label;

  static _StatusStyle of(String status) {
    switch (status) {
      case 'accepted':
        return _StatusStyle(
          color: AppColors.info,
          background: AppColors.info.withValues(alpha: 0.10),
          icon: Icons.directions_run,
          title: 'جاري إحضار قطعك إلى غرفة القياس 🏃‍♂️',
          subtitle: 'فريق الفرع في الطريق إلى المخزن الآن',
          label: 'جاري الإحضار',
        );
      case 'ready':
        return _StatusStyle(
          color: AppColors.success,
          background: AppColors.success.withValues(alpha: 0.12),
          icon: Icons.shopping_bag,
          title: 'ملابسك جاهزة الآن في غرفة القياس! 🛍️',
          subtitle: 'توجّه إلى غرفة القياس — القطعة بانتظارك',
          label: 'في غرفة القياس',
        );
      case 'done':
        return _StatusStyle(
          color: AppColors.success,
          background: AppColors.success.withValues(alpha: 0.10),
          icon: Icons.check_circle,
          title: 'تم تسليم طلبك ✅',
          subtitle: 'نتشرف بخدمتك دائماً — شكراً لزيارتك',
          label: 'تم التسليم',
        );
      case 'cancelled':
        return const _StatusStyle(
          color: AppColors.textSecondary,
          background: AppColors.accentLight,
          icon: Icons.cancel_outlined,
          title: 'تم إلغاء الطلب',
          subtitle: 'لا يوجد طلب نشط حالياً',
          label: 'ملغي',
        );
      default:
        return const _StatusStyle(
          color: AppColors.warning,
          background: Color(0xFFFFF7E6),
          icon: Icons.hourglass_top,
          title: 'طلبك قيد الانتظار فريق الفرع ⏳',
          subtitle: 'سنبلغك أول ما يبدأ فريق الفرع بتجهيز القطعة',
          label: 'قيد الانتظار',
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.data,
    required this.style,
    required this.onTap,
    required this.pulse,
  });

  final Map<String, dynamic> data;
  final _StatusStyle style;
  final VoidCallback onTap;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final size = (data['size'] as String?) ?? '';
    final color = (data['color'] as String?) ?? '';
    final productName = (data['productName'] as String?) ?? '';
    final meta = [productName, if (size.isNotEmpty) 'مقاس $size', if (color.isNotEmpty) color]
        .where((e) => e.isNotEmpty)
        .join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final t = pulse.value;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: style.color.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: style.color.withValues(alpha: 0.08 + 0.10 * t),
                    blurRadius: 10 + 8 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                        color: style.color,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      style.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: style.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.keyboard_arrow_up,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة تفاصيل الطلب + إلغاء الطلب (أثناء الانتظار فقط)
class _RequestDetailsSheet extends StatelessWidget {
  const _RequestDetailsSheet({required this.data, required this.cancellable});

  final Map<String, dynamic> data;
  final bool cancellable;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('المنتج', (data['productName'] as String?) ?? '—'),
      MapEntry('الكود (SKU)', _nonEmpty(data['sku'])),
      MapEntry('المقاس', _nonEmpty(data['size'])),
      MapEntry('اللون', _nonEmpty(data['color'])),
      MapEntry('الفرع', _nonEmpty(data['branchName'])),
      MapEntry('رقم الجلسة', _nonEmpty(data['sessionId'])),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.checkroom, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'تفاصيل طلب غرفة القياس',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        row.key,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (cancellable) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'إلغاء الطلب',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
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
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تم',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _nonEmpty(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '—' : text;
  }
}
