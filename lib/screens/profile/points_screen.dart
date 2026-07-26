import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/points_provider.dart';

/// شاشة النقاط والتحقق اليومي
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نقاطي'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Consumer<PointsProvider>(
          builder: (context, points, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // =========== بطاقة النقاط ===========
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('رصيد النقاط',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${points.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'قيمتها ${points.discountValue.toStringAsFixed(0)} ريال',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      // خانة التحقق اليومي
                      _buildCheckInButton(points),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =========== تسلسل الأيام (Streak) ===========
                const Text('تسلسل التحقق اليومي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                _buildStreakCalendar(points),

                const SizedBox(height: 24),

                // =========== طريقة حساب النقاط ===========
                const Text('كيف تربح النقاط؟',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                _buildRewardCard(Icons.login, 'التحقق اليومي', '10 نقاط', 'كل يوم'),
                _buildRewardCard(Icons.local_fire_department, 'تسلسل 7 أيام', '50 نقطة مكافأة', 'يوم 7'),
                _buildRewardCard(Icons.star, 'تسلسل 14 يوم', '100 نقطة مكافأة', 'يوم 14'),
                _buildRewardCard(Icons.diamond, 'تسلسل 30 يوم', '200 نقطة مكافأة', 'يوم 30'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckInButton(PointsProvider points) {
    if (points.checkedInToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('تم التحقق اليوم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final success = await points.checkIn();
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ تم التحقق! ربحت ${points.points > 0 ? "نقاط" : "10 نقاط"}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        icon: const Icon(Icons.login, color: Colors.white),
        label: const Text('تحقق الآن!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildStreakCalendar(PointsProvider points) {
    final days = ['الإثن', 'الثلاث', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final weekStatus = points.weekCheckins;
    return Row(
      children: List.generate(7, (i) {
        final checked = weekStatus[i];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: checked ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: checked
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : const Icon(Icons.circle_outlined,
                            color: AppColors.textSecondary, size: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 9,
                    color: checked ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRewardCard(IconData icon, String title, String reward, String period) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(period, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(reward, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
