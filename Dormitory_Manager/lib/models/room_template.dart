/// 방 템플릿 모델 (기준 방 사진)
class RoomTemplate {
  final int? id;
  final String templateName;
  final String roomType;
  final String? roomTypeDisplay;
  final String imagePath;
  final String? description;
  final String? buildingName;
  final bool isActive;
  final bool isDefault;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RoomTemplate({
    this.id,
    required this.templateName,
    required this.roomType,
    this.roomTypeDisplay,
    required this.imagePath,
    this.description,
    this.buildingName,
    this.isActive = true,
    this.isDefault = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory RoomTemplate.fromJson(Map<String, dynamic> json) {
    return RoomTemplate(
      id: json['id'],
      templateName: json['templateName'] ?? '',
      roomType: json['roomType'] ?? 'SINGLE',
      roomTypeDisplay: json['roomTypeDisplay'],
      imagePath: json['imagePath'] ?? '',
      description: json['description'],
      buildingName: json['buildingName'],
      isActive: json['isActive'] ?? true,
      isDefault: json['isDefault'] ?? false,
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'templateName': templateName,
      'roomType': roomType,
      'imagePath': imagePath,
      if (description != null) 'description': description,
      if (buildingName != null) 'buildingName': buildingName,
      'isActive': isActive,
      'isDefault': isDefault,
    };
  }

  /// 방 타입 한글 표시
  String get roomTypeDisplayName {
    if (roomTypeDisplay != null) return roomTypeDisplay!;
    switch (roomType) {
      case 'SINGLE':
        return '1인실';
      case 'DOUBLE':
        return '2인실';
      case 'MULTI':
        return '다인실';
      default:
        return roomType;
    }
  }

  RoomTemplate copyWith({
    int? id,
    String? templateName,
    String? roomType,
    String? roomTypeDisplay,
    String? imagePath,
    String? description,
    String? buildingName,
    bool? isActive,
    bool? isDefault,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomTemplate(
      id: id ?? this.id,
      templateName: templateName ?? this.templateName,
      roomType: roomType ?? this.roomType,
      roomTypeDisplay: roomTypeDisplay ?? this.roomTypeDisplay,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      buildingName: buildingName ?? this.buildingName,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 방 타입 enum
enum RoomType {
  SINGLE('1인실'),
  DOUBLE('2인실'),
  MULTI('다인실');

  final String displayName;
  const RoomType(this.displayName);

  static RoomType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SINGLE':
        return RoomType.SINGLE;
      case 'DOUBLE':
        return RoomType.DOUBLE;
      case 'MULTI':
        return RoomType.MULTI;
      default:
        return RoomType.SINGLE;
    }
  }
}
