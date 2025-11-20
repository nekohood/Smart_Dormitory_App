/// 허용 사용자 관련 모델

class AllowedUser {
  final int id;
  final String userId;
  final String name;
  final String? roomNumber;
  final String? phoneNumber;
  final String? email;
  final bool isRegistered;
  final DateTime? registeredAt;
  final DateTime createdAt;

  AllowedUser({
    required this.id,
    required this.userId,
    required this.name,
    this.roomNumber,
    this.phoneNumber,
    this.email,
    required this.isRegistered,
    this.registeredAt,
    required this.createdAt,
  });

  factory AllowedUser.fromJson(Map<String, dynamic> json) {
    return AllowedUser(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      roomNumber: json['roomNumber'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      isRegistered: json['isRegistered'] ?? false,
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
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
      users: (json['users'] as List)
          .map((e) => AllowedUser.fromJson(e))
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
