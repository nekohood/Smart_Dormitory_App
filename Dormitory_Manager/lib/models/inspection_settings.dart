/// 점호 설정 모델
class InspectionSettings {
  final int? id;
  final String settingName;
  final String startTime;
  final String endTime;
  final bool isEnabled;
  final bool cameraOnly;
  final bool exifValidationEnabled;
  final int exifTimeToleranceMinutes;
  final bool gpsValidationEnabled;
  final double? dormitoryLatitude;
  final double? dormitoryLongitude;
  final int? gpsRadiusMeters;
  final bool roomPhotoValidationEnabled;
  final String? applicableDays;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  InspectionSettings({
    this.id,
    required this.settingName,
    required this.startTime,
    required this.endTime,
    this.isEnabled = true,
    this.cameraOnly = true,
    this.exifValidationEnabled = true,
    this.exifTimeToleranceMinutes = 10,
    this.gpsValidationEnabled = false,
    this.dormitoryLatitude,
    this.dormitoryLongitude,
    this.gpsRadiusMeters = 100,
    this.roomPhotoValidationEnabled = true,
    this.applicableDays = 'ALL',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory InspectionSettings.fromJson(Map<String, dynamic> json) {
    return InspectionSettings(
      id: json['id'],
      settingName: json['settingName'] ?? '',
      startTime: json['startTime'] ?? '21:00',
      endTime: json['endTime'] ?? '23:59',
      isEnabled: json['isEnabled'] ?? true,
      cameraOnly: json['cameraOnly'] ?? true,
      exifValidationEnabled: json['exifValidationEnabled'] ?? true,
      exifTimeToleranceMinutes: json['exifTimeToleranceMinutes'] ?? 10,
      gpsValidationEnabled: json['gpsValidationEnabled'] ?? false,
      dormitoryLatitude: json['dormitoryLatitude']?.toDouble(),
      dormitoryLongitude: json['dormitoryLongitude']?.toDouble(),
      gpsRadiusMeters: json['gpsRadiusMeters'] ?? 100,
      roomPhotoValidationEnabled: json['roomPhotoValidationEnabled'] ?? true,
      applicableDays: json['applicableDays'] ?? 'ALL',
      isDefault: json['isDefault'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      createdBy: json['createdBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'settingName': settingName,
      'startTime': startTime,
      'endTime': endTime,
      'isEnabled': isEnabled,
      'cameraOnly': cameraOnly,
      'exifValidationEnabled': exifValidationEnabled,
      'exifTimeToleranceMinutes': exifTimeToleranceMinutes,
      'gpsValidationEnabled': gpsValidationEnabled,
      'dormitoryLatitude': dormitoryLatitude,
      'dormitoryLongitude': dormitoryLongitude,
      'gpsRadiusMeters': gpsRadiusMeters,
      'roomPhotoValidationEnabled': roomPhotoValidationEnabled,
      'applicableDays': applicableDays,
      'isDefault': isDefault,
    };
  }

  /// 현재 시간이 허용 시간 내인지 확인
  bool isWithinAllowedTime() {
    if (!isEnabled) return false;

    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (startMinutes <= endMinutes) {
      return currentTime >= startMinutes && currentTime <= endMinutes;
    } else {
      return currentTime >= startMinutes || currentTime <= endMinutes;
    }
  }

  /// 시간 범위 문자열
  String get timeRangeString => '$startTime ~ $endTime';
}

/// 점호 시간 확인 결과
class InspectionTimeCheckResult {
  final bool allowed;
  final String message;
  final String? startTime;
  final String? endTime;
  final bool cameraOnly;
  final bool exifValidationEnabled;
  final bool roomPhotoValidationEnabled;

  InspectionTimeCheckResult({
    required this.allowed,
    required this.message,
    this.startTime,
    this.endTime,
    this.cameraOnly = true,
    this.exifValidationEnabled = true,
    this.roomPhotoValidationEnabled = true,
  });

  factory InspectionTimeCheckResult.fromJson(Map<String, dynamic> json) {
    return InspectionTimeCheckResult(
      allowed: json['allowed'] ?? true,
      message: json['message'] ?? '',
      startTime: json['startTime'],
      endTime: json['endTime'],
      cameraOnly: json['cameraOnly'] ?? true,
      exifValidationEnabled: json['exifValidationEnabled'] ?? true,
      roomPhotoValidationEnabled: json['roomPhotoValidationEnabled'] ?? true,
    );
  }

  /// 시간 범위 문자열
  String? get timeRangeString {
    if (startTime != null && endTime != null) {
      return '$startTime ~ $endTime';
    }
    return null;
  }
}