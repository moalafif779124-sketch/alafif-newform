import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة Firebase المركزية
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAuth? _auth;
  bool _initialized = false;

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _storage!;
  }

  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _auth!;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;
    _auth = FirebaseAuth.instance;
    _initialized = true;

    // إعدادات Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  bool get isInitialized => _initialized;

  // =================== المنتجات ===================

  Stream<List<Map<String, dynamic>>> getProductsStream({
    String? categoryId,
    bool? isFeatured,
    bool? isNewArrival,
    String? searchQuery,
    String? sortBy,
    bool ascending = false,
  }) {
    Query query = firestore.collection('products').where('isActive', isEqualTo: true);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (isFeatured != null) {
      query = query.where('isFeatured', isEqualTo: isFeatured);
    }
    if (isNewArrival != null) {
      query = query.where('isNewArrival', isEqualTo: isNewArrival);
    }

    // ترتيب
    String sortField = 'createdAt';
    if (sortBy == 'price_asc' || sortBy == 'price_desc') {
      sortField = 'price';
    } else if (sortBy == 'name') {
      sortField = 'name';
    } else if (sortBy == 'popular') {
      sortField = 'reviewCount';
    }
    query = query.orderBy(sortField, descending: sortBy == 'price_desc' || sortBy == 'popular' || sortBy == 'newest');

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  Future<List<Map<String, dynamic>>> getProducts({
    String? categoryId,
    bool? isFeatured,
    bool? isNewArrival,
    String? searchQuery,
    String? sortBy,
    int? limit,
  }) async {
    Query query = firestore.collection('products').where('isActive', isEqualTo: true);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (isFeatured != null) {
      query = query.where('isFeatured', isEqualTo: isFeatured);
    }
    if (isNewArrival != null) {
      query = query.where('isNewArrival', isEqualTo: isNewArrival);
    }

    if (sortBy != null) {
      String sortField = 'createdAt';
      if (sortBy == 'price_asc' || sortBy == 'price_desc') sortField = 'price';
      else if (sortBy == 'name') sortField = 'name';
      else if (sortBy == 'popular') sortField = 'reviewCount';
      query = query.orderBy(sortField, descending: sortBy == 'price_desc' || sortBy == 'popular' || sortBy == 'newest');
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> getProduct(String productId) async {
    final doc = await firestore.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  // =================== الفئات ===================

  Stream<List<Map<String, dynamic>>> getCategoriesStream() {
    return firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot = await firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== البانرات ===================

  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final snapshot = await firestore
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== السلة ===================

  Future<void> saveCart(String userId, List<Map<String, dynamic>> items) async {
    await firestore.collection('carts').doc(userId).set({
      'userId': userId,
      'items': items,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>?> getCart(String userId) async {
    final doc = await firestore.collection('carts').doc(userId).get();
    if (!doc.exists) return null;
    return List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
  }

  Future<void> clearCart(String userId) async {
    await firestore.collection('carts').doc(userId).delete();
  }

  // =================== الطلبات ===================

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final docRef = await firestore.collection('orders').add(orderData);
    return docRef.id;
  }

  Stream<List<Map<String, dynamic>>> getUserOrdersStream(String userId) {
    return firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final snapshot = await firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== العناوين ===================

  Future<void> saveAddress(Map<String, dynamic> addressData) async {
    if (addressData['id'] != null && addressData['id'].isNotEmpty) {
      await firestore.collection('addresses').doc(addressData['id']).set(addressData);
    } else {
      await firestore.collection('addresses').add(addressData);
    }
  }

  Future<List<Map<String, dynamic>>> getUserAddresses(String userId) async {
    final snapshot = await firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> deleteAddress(String addressId) async {
    await firestore.collection('addresses').doc(addressId).delete();
  }

  Future<void> setDefaultAddress(String userId, String addressId) async {
    final batch = firestore.batch();
    final addresses = await firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in addresses.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == addressId});
    }
    await batch.commit();
  }

  // =================== رفع الصور ===================

  Future<String> uploadImage(String path, String fileName) async {
    final ref = storage.ref().child('products/$fileName');
    // Note: In actual implementation, use putFile with File(path)
    // For now, this is a placeholder for the API
    return ref.fullPath;
  }

  // =================== المستخدم ===================

  Future<void> saveUser(Map<String, dynamic> userData) async {
    await firestore.collection('users').doc(userData['id']).set(userData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }
}
