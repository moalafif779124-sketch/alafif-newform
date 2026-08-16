import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/live_tracking_timeline.dart';

/// شاشة تتبع الطلب مع خط زمني حي
class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Order _order = widget.order;
  Stream<Map<String, dynamic>>? _orderStream;

  @override
  void initState() {
    super.initState();
    // اشتراك مباشر — يتحدث فورياً عند تغيير حالة الطلب من لوحة التحكم
    _orderStream = FirebaseService().getOrderStream(widget.order.id);
    _orderStream!.listen((data) {
      if (!mounted || data.isEmpty) return;
      final updated = Order.fromMap(data);
      if (updated.status != _order.status || updated.paymentStatus != _order.paymentStatus) {
        setState(() => _order = updated);
      }
    });
  }

  Order get order => _order;

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

              // ===== الخط الزمني الحي =====
              LiveTrackingTimeline(order: order),
              const SizedBox(height: 20),

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
}
