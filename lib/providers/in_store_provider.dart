import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/in_store_service.dart';

/// حالة «الوضع الذكي داخل الفرع»
///
/// يحفظ تفعيل الوضع، الفرع المختار، آخر عملية مسح، وحالة طلب غرفة القياس.
/// كل النداءات غير حاجزة (async) ولا تُجمّد الواجهة.
class InStoreProvider extends ChangeNotifier {
  bool _enabled = false;
  StoreBranch? _branch;
  List<StoreBranch> _branches = const [];

  // آخر مسح
  Product? _scannedProduct;
  String _matchedBy = '';
  String _rawCode = '';
  bool _scanning = false;
  String _error = '';

  // فيديو الإطلالة المرتبط
  String _videoUrl = '';
  bool _loadingVideo = false;

  // طلب غرفة القياس
  bool _sendingRequest = false;
  String _lastRequestId = '';

  /// معرّف جلسة العميل داخل الفرع (يُستخدم في سجل الطلب)
  final String sessionId =
      'SES-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

  // ==================== getters ====================

  bool get enabled => _enabled;
  StoreBranch? get branch => _branch;
  List<StoreBranch> get branches => _branches;
  Product? get scannedProduct => _scannedProduct;
  String get matchedBy => _matchedBy;
  String get rawCode => _rawCode;
  bool get scanning => _scanning;
  String get error => _error;
  String get videoUrl => _videoUrl;
  bool get loadingVideo => _loadingVideo;
  bool get sendingRequest => _sendingRequest;
  String get lastRequestId => _lastRequestId;
  bool get hasScan => _scannedProduct != null;

  // ==================== تفعيل الوضع ====================

  Future<void> toggleMode(bool value) async {
    _enabled = value;
    notifyListeners();
    if (value && _branches.isEmpty) {
      await loadBranches();
    }
  }

  Future<void> loadBranches() async {
    _branches = await InStoreService.instance.getBranches();
    _branch ??= _branches.isNotEmpty ? _branches.first : null;
    notifyListeners();
  }

  void selectBranch(StoreBranch branch) {
    _branch = branch;
    notifyListeners();
  }

  // ==================== المسح ====================

  void clearScan() {
    _scannedProduct = null;
    _matchedBy = '';
    _rawCode = '';
    _error = '';
    _videoUrl = '';
    _lastRequestId = '';
    notifyListeners();
  }

  /// معالجة كود البطاقة: بحث عن المنتج ثم جلب فيديو الإطلالة.
  ///
  /// البحث عن المنتج والفروع يجري بالتوازي (resolveScan)، ثم يُجلب
  /// الفيديو — دون حجب الواجهة.
  Future<void> handleScan(String rawCode) async {
    _scanning = true;
    _error = '';
    _scannedProduct = null;
    _videoUrl = '';
    _lastRequestId = '';
    notifyListeners();

    try {
      final result = await InStoreService.instance.resolveScan(rawCode);
      final scan = result['scan'] as ScanLookupResult?;
      final branches = result['branches'] as List<StoreBranch>;

      _branches = branches;
      _branch ??= branches.isNotEmpty ? branches.first : null;
      _rawCode = rawCode.trim();

      if (scan == null) {
        _error = 'لم يتم العثور على منتج مطابق لهذا الكود';
        _scanning = false;
        notifyListeners();
        return;
      }

      _scannedProduct = scan.product;
      _matchedBy = scan.matchedBy;
      _scanning = false;
      notifyListeners();

      // فيديو الإطلالة — لا نُجمّد الشاشة بانتظاره
      _loadingVideo = true;
      notifyListeners();
      final video =
          await InStoreService.instance.getStylistVideoUrl(scan.product);
      _videoUrl = video;
      _loadingVideo = false;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ handleScan error: $e');
      _error = 'تعذّر قراءة الكود — حاول مرة أخرى';
      _scanning = false;
      notifyListeners();
    }
  }

  // ==================== طلب غرفة القياس ====================

  Future<bool> requestFittingRoom({
    required String size,
    required String color,
    required String userId,
    String note = '',
  }) async {
    final product = _scannedProduct;
    final branch = _branch;
    if (product == null || branch == null) return false;

    _sendingRequest = true;
    notifyListeners();

    try {
      final id = await InStoreService.instance.sendFittingRoomRequest(
        branch: branch,
        product: product,
        size: size,
        color: color,
        userId: userId,
        sessionId: sessionId,
        note: note,
      );
      _lastRequestId = id;
      _sendingRequest = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('⚠️ requestFittingRoom error: $e');
      _error = 'تعذّر إرسال الطلب — تحقق من الاتصال';
      _sendingRequest = false;
      notifyListeners();
      return false;
    }
  }
}
