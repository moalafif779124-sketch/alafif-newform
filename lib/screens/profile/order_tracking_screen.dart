import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_image.dart';

/// شاشة تتبع الطلب مع خط زمني
class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Order get order => widget.order;

  /// قائمة حالات الطلب مرتبة حسب التسلسل الزمني
  List<_OrderStatusStep> get _statusSteps {
    final steps = <_OrderStatusStep>[
      _OrderStatusStep(
        status: 'pending',
        label: 'قيد المراجعة',
        icon: Icons.receipt_long_outlined,
        date: order.createdAt,
        isCompleted: _isStatusCompleted('pending'),
      ),
      _OrderStatusStep(
        status: 'confirmed',
        label: 'تم التأكيد',
        icon: Icons.check_circle_outline,
        date: order.status == 'confirmed' || order.status == 'processing' ||
                order.status == 'shipped' || order.status == 'delivered'
            ? (order.updatedAt ?? order.createdAt)
            : null,
        isCompleted: _isStatusCompleted('confirmed'),
      ),
      _OrderStatusStep(
        status: 'processing',
        label: 'قيد التجهيز',
        icon: Icons.inventory_2_outlined,
        date: order.status == 'processing' || order.status == 'shipped' ||
                order.status == 'delivered'
            ? (order.updatedAt ?? order.createdAt)
            : null,
        isCompleted: _isStatusCompleted('processing'),
      ),
      _OrderStatusStep(
        status: 'shipped',
        label: 'تم الشحن',
        icon: Icons.local_shipping_outlined,
        date: order.status == 'shipped' || order.status == 'delivered'
            ? (order.updatedAt ?? order.createdAt)
            : null,
        isCompleted: _isStatusCompleted('shipped'),
      ),
      _OrderStatusStep(
        status: 'delivered',
        label: 'تم التوصيل',
        icon: Icons.verified_outlined,
        date: order.deliveredAt ?? (order.status == 'delivered' ? order.updatedAt : null),
        isCompleted: order.status == 'delivered',
      ),
    ];

    if (order.status == 'cancelled') {
      steps.add(_OrderStatusStep(
        status: 'cancelled',
        label: 'ملغي',
        icon: Icons.cancel_outlined,
        date: order.updatedAt ?? order.createdAt,
        isCompleted: true,
        isCancel: true,
      ));
    }

    return steps;
  }

  bool _isStatusCompleted(String status) {
    const order = ['pending', 'confirmed', 'processing', 'shipped', 'delivered'];
    final currentIndex = order.indexOf(widget.order.status);
    final stepIndex = order.indexOf(status);
    return stepIndex <= currentIndex && widget.order.status != 'cancelled';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'processing': return Colors.amber;
      case 'shipped': return Colors.purple;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تتبع الطلب'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== كرت رقم الطلب =====
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'رقم الطلب',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(order.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusColor(order.status).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          order.statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== الخط الزمني =====
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'حالة الطلب',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              ..._statusSteps.map((step) => _buildTimelineStep(step)),

              const SizedBox(height: 24),

              // ===== تفاصيل التوصيل =====
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'معلومات التوصيل',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person_outline, order.shippingAddress.fullName),
                      const Divider(height: 16),
                      _buildInfoRow(Icons.phone_outlined, order.shippingAddress.phone),
                      const Divider(height: 16),
                      _buildInfoRow(Icons.location_on_outlined, order.shippingAddress.fullAddress),
                      if (order.shippingAddress.landmark != null) ...[
                        const Divider(height: 16),
                        _buildInfoRow(Icons.flag_outlined, order.shippingAddress.landmark!),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== طريقة الدفع =====
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'معلومات الدفع',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.payment_outlined, _paymentMethodLabel(order.paymentMethod)),
                      const Divider(height: 16),
                      _buildInfoRow(Icons.monetization_on_outlined,
                          '${AppConstants.currency}${order.total.toStringAsFixed(0)}'),
                      const Divider(height: 16),
                      _buildInfoRow(
                        Icons.info_outline,
                        order.paymentStatusText,
                        valueColor: order.paymentStatus == 'paid'
                            ? AppColors.success
                            : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== عناصر الطلب =====
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'المنتجات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...order.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56, height: 56,
                          child: item.productImage.isNotEmpty
                              ? AppImage(
                                  imageUrl: item.productImage,
                                  fit: BoxFit.cover,
                                  backgroundColor: AppColors.accentLight,
                                )
                              : Container(
                                  color: AppColors.accentLight,
                                  child: const Icon(Icons.image_outlined),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              '${item.size.isNotEmpty ? item.size : ''}${item.size.isNotEmpty && item.color.isNotEmpty ? ' | ' : ''}${item.color.isNotEmpty ? item.color : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppConstants.currency}${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(_OrderStatusStep step) {
    final isActive = step.isCompleted;
    final isLast = step == _statusSteps.last;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العمود الرأسي للخط الزمني
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.isCancel
                        ? AppColors.error
                        : isActive
                            ? AppColors.primary
                            : AppColors.border,
                  ),
                  child: Icon(
                    step.icon,
                    size: 16,
                    color: isActive || step.isCancel ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isActive ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          // المحتوى
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive || step.isCancel ? FontWeight.bold : FontWeight.normal,
                      color: step.isCancel
                          ? AppColors.error
                          : isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(step.date!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'kuraimi': return 'كريمي باي';
      case 'jeeb': return 'جيب';
      case 'cod': return 'الدفع عند الاستلام';
      default: return method;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _OrderStatusStep {
  final String status;
  final String label;
  final IconData icon;
  final DateTime? date;
  final bool isCompleted;
  final bool isCancel;

  _OrderStatusStep({
    required this.status,
    required this.label,
    required this.icon,
    this.date,
    required this.isCompleted,
    this.isCancel = false,
  });
}
