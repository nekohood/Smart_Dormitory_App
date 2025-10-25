class User {
  final String id;
  final String? name; // 이름 (nullable)
  final String? email; // 이메일 (nullable)
  final String? phoneNumber; // 전화번호 (nullable)
  final String? roomNumber; // 방 번호 (nullable)
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isActive;
  final bool? isLocked;
  final String? profileImagePath;
  final DateTime? lastLoginAt;
  final DateTime? passwordChangedAt;
  final int? loginAttempts;


  User({
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.roomNumber,
    required this.isAdmin,
    this.createdAt,
    this.updatedAt,
    this.isActive,
    this.isLocked,
    this.profileImagePath,
    this.lastLoginAt,
    this.passwordChangedAt,
    this.loginAttempts,
  });

  // JSON에서 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'], // 서버에서 오는 그대로 받음
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      roomNumber: json['roomNumber'],
      isAdmin: json['isAdmin'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      isActive: json['isActive'],
      isLocked: json['isLocked'],
      profileImagePath: json['profileImagePath'],
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : null,
      passwordChangedAt: json['passwordChangedAt'] != null
          ? DateTime.parse(json['passwordChangedAt'])
          : null,
      loginAttempts: json['loginAttempts'],
    );
  }

  // User 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'roomNumber': roomNumber,
      'isAdmin': isAdmin,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'isLocked': isLocked,
      'profileImagePath': profileImagePath,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'passwordChangedAt': passwordChangedAt?.toIso8601String(),
      'loginAttempts': loginAttempts,
    };
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, isAdmin: $isAdmin}';
  }
}