/// 허용 사용자 관련 모델
library;

class AllowedUser {
  final int? id;
  final String userId;
  final String name;
  final String? dormitoryBuilding; // ✅ 거주 동 추가
  final String? roomNumber;
  final String? phoneNumber;
  final String? email;
  final bool isRegistered;
  final DateTime? registeredAt;
  final DateTime? createdAt;

  AllowedUser({
    this.id,
    required this.userId,
    required this.name,
    this.dormitoryBuilding,
    this.roomNumber,
    this.phoneNumber,
    this.email,
    required this.isRegistered,
    this.registeredAt,
    this.createdAt,
  });

  factory AllowedUser.fromJson(Map<String, dynamic> json) {
    return AllowedUser(
      id: json['id'],
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      dormitoryBuilding: json['dormitoryBuilding'], // ✅ 거주 동 추가
      roomNumber: json['roomNumber'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      isRegistered: json['isRegistered'] ?? false,
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'dormitoryBuilding': dormitoryBuilding, // ✅ 거주 동 추가
      'roomNumber': roomNumber,
      'phoneNumber': phoneNumber,
      'email': email,
      'isRegistered': isRegistered,
      'registeredAt': registeredAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AllowedUser{userId: $userId, name: $name, dormitoryBuilding: $dormitoryBuilding, roomNumber: $roomNumber, isRegistered: $isRegistered}';
  }
}

class AllowedUserListResponse {
  final List<AllowedUser> users;
  final int totalCount;
  final int registeredCount;
  final int unregisteredCount;

  AllowedUserListResponse({
    required this.users,
    required this.totalCount,
    required this.registeredCount,
    required this.unregisteredCount,
  });

  factory AllowedUserListResponse.fromJson(Map<String, dynamic> json) {
    return AllowedUserListResponse(
      users: (json['users'] as List<dynamic>)
          .map((item) => AllowedUser.fromJson(item))
          .toList(),
      totalCount: json['totalCount'] ?? 0,
      registeredCount: json['registeredCount'] ?? 0,
      unregisteredCount: json['unregisteredCount'] ?? 0,
    );
  }
}

class UploadExcelResponse {
  final int totalCount;
  final int successCount;
  final int failCount;
  final List<String> errors;

  UploadExcelResponse({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.errors,
  });

  factory UploadExcelResponse.fromJson(Map<String, dynamic> json) {
    return UploadExcelResponse(
      totalCount: json['totalCount'] ?? 0,
      successCount: json['successCount'] ?? 0,
      failCount: json['failCount'] ?? 0,
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
