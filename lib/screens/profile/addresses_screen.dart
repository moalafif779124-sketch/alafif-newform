import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../models/address.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

/// شاشة إدارة العناوين
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // =========== الحقول الخاصة بنموذج الإضافة ===========
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String _selectedLabel = 'منزلي';
  bool _isDefault = false;
  bool _isSaving = false;

  final List<String> _labelOptions = ['منزلي', 'عمل', 'آخر'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // ======================== جلب العناوين ========================

  Future<List<Address>> _loadAddresses() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return [];

    final data = await _firebaseService.getUserAddresses(userId);
    return data.map((map) => Address.fromMap(map)).toList();
  }

  // ======================== حذف عنوان ========================

  Future<void> _confirmDelete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العنوان'),
        content: Text('هل أنت متأكد من حذف "${address.label}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firebaseService.deleteAddress(address.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم حذف العنوان بنجاح'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل الحذف: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ======================== إضافة عنوان ========================

  void _showAddAddressSheet() {
    _fullNameController.clear();
    _phoneController.clear();
    _streetController.clear();
    _districtController.clear();
    _cityController.clear();
    _selectedLabel = 'منزلي';
    _isDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // العنوان
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إضافة عنوان جديد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // تصنيف العنوان
                  DropdownButtonFormField<String>(
                    value: _selectedLabel,
                    decoration: const InputDecoration(
                      labelText: 'تصنيف العنوان',
                      prefixIcon: Icon(Icons.label_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: _labelOptions.map((label) {
                      return DropdownMenuItem(
                        value: label,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _selectedLabel = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // الاسم الكامل
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      hintText: 'أدخل الاسم الكامل',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // رقم الجوال
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجوال',
                      hintText: 'أدخل رقم الجوال',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // الشارع
                  TextField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'الشارع',
                      hintText: 'أدخل اسم الشارع',
                      prefixIcon: Icon(Icons.signpost_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // الحي/المنطقة
                  TextField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: 'الحي/المنطقة',
                      hintText: 'أدخل الحي أو المنطقة',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // المدينة
                  TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'المدينة',
                      hintText: 'أدخل المدينة',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // تعيين كافتراضي
                  SwitchListTile(
                    title: const Text(
                      'تعيين كعنوان افتراضي',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    value: _isDefault,
                    onChanged: (value) {
                      setSheetState(() => _isDefault = value);
                    },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _saveAddress(ctx, setSheetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'حفظ العنوان',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAddress(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
  ) async {
    // التحقق من الحقول
    if (_fullNameController.text.trim().isEmpty) {
      _showSheetSnackBar(sheetContext, 'يرجى إدخال الاسم الكامل');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSheetSnackBar(sheetContext, 'يرجى إدخال رقم الجوال');
      return;
    }
    if (_streetController.text.trim().isEmpty) {
      _showSheetSnackBar(sheetContext, 'يرجى إدخال الشارع');
      return;
    }
    if (_districtController.text.trim().isEmpty) {
      _showSheetSnackBar(sheetContext, 'يرجى إدخال الحي/المنطقة');
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      _showSheetSnackBar(sheetContext, 'يرجى إدخال المدينة');
      return;
    }

    setSheetState(() => _isSaving = true);

    try {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) {
        _showSheetSnackBar(sheetContext, 'المستخدم غير مسجل');
        setSheetState(() => _isSaving = false);
        return;
      }

      final addressData = {
        'userId': userId,
        'label': _selectedLabel,
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'street': _streetController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
        'state': 'أمانة العاصمة',
        'isDefault': _isDefault,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _firebaseService.saveAddress(addressData);

      // إذا كان العنوان افتراضياً، حدّث باقي العناوين
      if (_isDefault && userId.isNotEmpty) {
        // سيتم التعامل معه لاحقاً بعد استرجاع الـ id
      }

      if (mounted) {
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إضافة العنوان بنجاح'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      setSheetState(() => _isSaving = false);
      _showSheetSnackBar(sheetContext, 'فشل الحفظ: $e');
    }
  }

  void _showSheetSnackBar(BuildContext sheetContext, String message) {
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ======================== أيقونات التصنيف ========================

  IconData _labelIcon(String label) {
    switch (label) {
      case 'منزلي':
        return Icons.home_outlined;
      case 'عمل':
        return Icons.work_outline;
      default:
        return Icons.place_outlined;
    }
  }

  // ======================== البناء ========================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العناوين'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddAddressSheet,
              tooltip: 'إضافة عنوان',
            ),
          ],
        ),
        body: FutureBuilder<List<Address>>(
          future: _loadAddresses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'حدث خطأ أثناء تحميل العناوين',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            final addresses = snapshot.data ?? [];

            if (addresses.isEmpty) {
              return _buildEmptyState();
            }

            return _buildAddressList(addresses);
          },
        ),
      ),
    );
  }

  // ======================== الحالة الفارغة ========================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 80,
              color: AppColors.accent,
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد عناوين مسجلة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أضف عنواناً جديداً لتتمكن من استلام طلباتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showAddAddressSheet,
              icon: const Icon(Icons.add_location_outlined),
              label: const Text(
                'إضافة عنوان جديد',
                style: TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== قائمة العناوين ========================

  Widget _buildAddressList(List<Address> addresses) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        return _buildAddressCard(addresses[index]);
      },
    );
  }

  // ======================== بطاقة عنوان ========================

  Widget _buildAddressCard(Address address) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف العلوي: التصنيف + وسام افتراضي
            Row(
              children: [
                Icon(
                  _labelIcon(address.label),
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  address.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (address.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'افتراضي',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // الاسم الكامل
            Text(
              address.fullName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // رقم الجوال
            Text(
              address.phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            // العنوان الكامل
            Text(
              address.fullAddress,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            if (address.landmark != null && address.landmark!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'معلم: ${address.landmark}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 20),

            // أزرار التعديل والحذف
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // زر التعديل
                TextButton.icon(
                  onPressed: () {
                    // TODO: تعديل العنوان
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('تعديل العنوان قيد التطوير'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                // زر الحذف
                TextButton.icon(
                  onPressed: () => _confirmDelete(address),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
