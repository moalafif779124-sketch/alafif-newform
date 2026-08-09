/// نموذج المستخدم
class AppUser {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String? profileImage;
  final String? address;
  final DateTime createdAt;
  final bool isAdmin;
  final String? referralCode; // كود الإحالة الخاص بالمستخدم (شارك واكسب)
  final String? referredBy; // كود من دعاه (يمنع التفعيل المكرر)

  AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email = '',
    this.profileImage,
    this.address,
    DateTime? createdAt,
    this.isAdmin = false,
    this.referralCode,
    this.referredBy,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'],
      address: map['address'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      isAdmin: map['isAdmin'] ?? false,
      referralCode: map['referralCode'] as String?,
      referredBy: map['referredBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'profileImage': profileImage,
      'address': address,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isAdmin': isAdmin,
      'referralCode': referralCode,
      'referredBy': referredBy,
    };
  }
}
