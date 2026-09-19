import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';

/// فرع المتجر
class StoreBranch {
  final String id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;

  const StoreBranch({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
  });

  factory StoreBranch.fromMap(String id, Map<String, dynamic> doc) => StoreBranch(
        id: id,
        name: doc['name'] ?? 'الفرع الرئيسي',
        address: doc['address'] ?? '',
        phone: doc['phone'] ?? '',
        isActive: doc['isActive'] ?? true,
      );

  static const StoreBranch fallback = StoreBranch(
    id: 'main',
    name: 'فرع العفيف نيوفورم — الرئيسي',
  );
}

/// نتيجة مسح بطاقة منتج: المنتج + كيف تم مطابقته
class ScanLookupResult {
  final Product product;
  final String matchedBy; // 'id' | 'barcode' | 'sku' | 'name'
  final String rawCode;

  const ScanLookupResult({
    required this.product,
    required this.matchedBy,
    required this.rawCode,
  });
}

/// خدمة «الوضع الذكي داخل الفرع»
///
/// - مطابقة كود البطاقة (باركود/QR/SKU) مع منتجات المتجر
/// - جلب توفّر المقاسات والألوان والمخزون من Firestore
/// - ربط المنتج بمقطع الفيديو من تبويب «اكتشف»
/// - إرسال طلب «إحضار لغرفة القياس» لموظفي الفرع
class InStoreService {
  InStoreService._();
  static final InStoreService instance = InStoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== الفروع ====================

  /// جلب الفروع النشطة (مع بديل آمن إن لم تُعرَّف بعد)
  Future<List<StoreBranch>> getBranches() async {
    try {
      final snapshot =
          await _firestore.collection('branches').limit(20).get();
      final branches = snapshot.docs
          .map((doc) => StoreBranch.fromMap(doc.id, doc.data()))
          .where((b) => b.isActive)
          .toList();
      if (branches.isEmpty) return [StoreBranch.fallback];
      return branches;
    } catch (e) {
      debugPrint('⚠️ getBranches error: $e');
      return [StoreBranch.fallback];
    }
  }

  // ==================== البحث عن منتج بالكود ====================

  /// يبحث عن المنتج المطابق لكود البطاقة المسحوحة.
  ///
  /// يجري الاستعلامات **بالتوازي** (Future.wait) — بحث مباشر بالمعرّف،
  /// ثم حقول barcode / sku، مع تنظيف الكود أولاً. أسرع بكثير من التتابع
  /// ويحافظ على سلاسة الواجهة أثناء المسح.
  Future<ScanLookupResult?> lookupByCode(String rawCode) async {
    final code = _normalize(rawCode);
    if (code.isEmpty) return null;

    // 1) بحث مباشر بالمعرّف (الأسرع والأكثر دقة)
    try {
      final doc = await _firestore.collection('products').doc(code).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        final product = Product.fromMap(data);
        if (product.isActive) {
          return ScanLookupResult(product: product, matchedBy: 'id', rawCode: code);
        }
      }
    } catch (e) {
      debugPrint('⚠️ lookupById error: $e');
    }

    // 2) بحث بالحقول barcode / sku — معاً وبالتوازي
    final fieldResults = await Future.wait([
      _queryByField('barcode', code),
      _queryByField('sku', code),
    ]);

    for (var i = 0; i < fieldResults.length; i++) {
      final products = fieldResults[i];
      if (products.isNotEmpty) {
        final product = products.firstWhere(
          (p) => p.isActive,
          orElse: () => products.first,
        );
        return ScanLookupResult(
          product: product,
          matchedBy: i == 0 ? 'barcode' : 'sku',
          rawCode: code,
        );
      }
    }

    // 3) مطابقة احتياطية: المعرّف يحتوي الكود (بطاقات قديمة)
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .limit(300)
          .get();
      for (final doc in snapshot.docs) {
        if (doc.id.toUpperCase().endsWith(code.toUpperCase())) {
          final data = doc.data();
          data['id'] = doc.id;
          return ScanLookupResult(
            product: Product.fromMap(data),
            matchedBy: 'id',
            rawCode: code,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ lookupBySuffix error: $e');
    }

    return null;
  }

  Future<List<Product>> _queryByField(String field, String value) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where(field, isEqualTo: value)
          .limit(5)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Product.fromMap(data);
      }).toList();
    } catch (e) {
      // حقل غير موجود في المخطط → تجاهل بهدوء
      debugPrint('⚠️ query field "$field" error: $e');
      return const [];
    }
  }

  String _normalize(String raw) {
    var code = raw.trim();
    // إزالة روابط QR الشائعة والحفاظ على المعرّف فقط
    if (code.contains('product/')) {
      code = code.split('product/').last;
    }
    code = code.replaceAll('"', '').replaceAll("'", '').trim();
    if (code.contains('?')) code = code.split('?').first;
    return code;
  }

  // ==================== البحث المتوازي الكامل ====================

  /// جلب كل ما تحتاجه شاشة المسح بعد قراءة الكود — **بالتوازي**:
  /// المنتج المطابق + الفروع (لطلب غرفة القياس).
  Future<Map<String, dynamic>> resolveScan(String rawCode) async {
    final results = await Future.wait([
      lookupByCode(rawCode),
      getBranches(),
    ]);
    return {
      'scan': results[0] as ScanLookupResult?,
      'branches': results[1] as List<StoreBranch>,
    };
  }

  /// مقطع فيديو الإطلالة المرتبط بالمنتج (من تبويب «اكتشف»).
  ///
  /// الأولوية: فيديو المنتج نفسه، ثم منتجات من نفس الفئة لها فيديو
  /// (بديل إطلالة) — كلها في استعلام واحد متوازٍ مع بقية البيانات.
  Future<String> getStylistVideoUrl(Product product) async {
    if (product.videoUrl.trim().isNotEmpty) return product.videoUrl.trim();

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('categoryId', isEqualTo: product.categoryId)
          .limit(20)
          .get();
      for (final doc in snapshot.docs) {
        final video = (doc.data()['videoUrl'] ?? '').toString().trim();
        if (video.isNotEmpty) return video;
      }
    } catch (e) {
      debugPrint('⚠️ getStylistVideoUrl error: $e');
    }
    return '';
  }

  // ==================== طلب غرفة القياس ====================

  /// إرسال طلب «إحضار لغرفة القياس» إلى موظفي الفرع.
  ///
  /// يُنشئ سجلاً في مجموعة `fitting_room_requests` يحمل المنتج والمقاس
  /// واللون ورقم جلسة العميل ليصل إشعار الموظف في الفرع.
  Future<String> sendFittingRoomRequest({
    required StoreBranch branch,
    required Product product,
    required String size,
    required String color,
    required String userId,
    required String sessionId,
    String sku = '',
    String note = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final docRef = await _firestore.collection('fitting_room_requests').add({
      'branchId': branch.id,
      'branchName': branch.name,
      'productId': product.id,
      'productName': product.name,
      'productImage': product.images.isNotEmpty ? product.images.first : '',
      'sku': sku,
      'size': size,
      'color': color,
      'userId': userId,
      'sessionId': sessionId,
      'note': note,
      'source': 'in_store_smart_mode',
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    });
    debugPrint('🛎️ Fitting-room request sent: ${docRef.id}');
    return docRef.id;
  }

  /// طلبات العميل الحالية (لمتابعة حالتها داخل الفرع)
  ///
  /// ⚠️ لا يُستخدم orderBy هنا: `where(userId) + orderBy(createdAt)` يحتاج
  /// فهرساً مركّباً (userId ASC, createdAt DESC) وإلا يفشل الاستعلام بـ
  /// `failed-precondition`. الفرز يجري في الواجهة (أحدث 20 طلباً تكفي).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyRequests(String userId) {
    return _firestore
        .collection('fitting_room_requests')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .snapshots();
  }

  /// إلغاء العميل لطلبه — مسموح فقط وهو بحالة `pending`
  /// (قاعدة Firestore ترفض أي انتقال آخر من جهة العميل).
  Future<void> cancelFittingRoomRequest(String docId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('fitting_room_requests').doc(docId).update({
      'status': 'cancelled',
      'cancelledAt': now,
      'updatedAt': now,
      'cancelledBy': 'customer',
    });
    debugPrint('🚫 Fitting-room request cancelled by customer: $docId');
  }
}
