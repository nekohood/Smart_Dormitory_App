import 'package:intl/intl.dart';

/// 점호 설정 모델
/// ✅ 수정: inspectionDate 필드 추가 (특정 날짜에만 점호 가능)
class InspectionSettings {
  final int? id;
  final String settingName;
  final String startTime;
  final String endTime;
  final DateTime? inspectionDate;  // ✅ 신규: 점호 날짜
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
  final int? scheduleId;  // ✅ 신규: 연결된 캘린더 일정 ID
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  InspectionSettings({
    this.id,
    required this.settingName,
    required this.startTime,
    required this.endTime,
    this.inspectionDate,
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
    this.scheduleId,
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
      inspectionDate: json['inspectionDate'] != null
          ? DateTime.parse(json['inspectionDate'])
          : null,
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
      scheduleId: json['scheduleId'],
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
      if (inspectionDate != null) 'inspectionDate': DateFormat('yyyy-MM-dd').format(inspectionDate!),
      'isEnabled': isEnabled,
      'cameraOnly': cameraOnly,
      'exifValidationEnabled': exifValidationEnabled,
      'exifTimeToleranceMinutes': exifTimeToleranceMinutes,
      'gpsValidationEnabled': gpsValidationEnabled,
      if (dormitoryLatitude != null) 'dormitoryLatitude': dormitoryLatitude,
      if (dormitoryLongitude != null) 'dormitoryLongitude': dormitoryLongitude,
      if (gpsRadiusMeters != null) 'gpsRadiusMeters': gpsRadiusMeters,
      'roomPhotoValidationEnabled': roomPhotoValidationEnabled,
      if (applicableDays != null) 'applicableDays': applicableDays,
      'isDefault': isDefault,
    };
  }

  /// ✅ 신규: 점호 날짜 포맷팅
  String? get formattedInspectionDate {
    if (inspectionDate == null) return null;
    return DateFormat('yyyy년 M월 d일').format(inspectionDate!);
  }

  /// ✅ 신규: 점호 날짜까지 남은 일수
  int? get daysUntilInspection {
    if (inspectionDate == null) return null;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final inspectionOnly = DateTime(inspectionDate!.year, inspectionDate!.month, inspectionDate!.day);
    return inspectionOnly.difference(todayOnly).inDays;
  }

  /// ✅ 신규: 오늘이 점호 날짜인지 확인
  bool get isInspectionToday {
    if (inspectionDate == null) return true;  // 날짜 미설정시 매일 점호
    final today = DateTime.now();
    return inspectionDate!.year == today.year &&
        inspectionDate!.month == today.month &&
        inspectionDate!.day == today.day;
  }

  InspectionSettings copyWith({
    int? id,
    String? settingName,
    String? startTime,
    String? endTime,
    DateTime? inspectionDate,
    bool? isEnabled,
    bool? cameraOnly,
    bool? exifValidationEnabled,
    int? exifTimeToleranceMinutes,
    bool? gpsValidationEnabled,
    double? dormitoryLatitude,
    double? dormitoryLongitude,
    int? gpsRadiusMeters,
    bool? roomPhotoValidationEnabled,
    String? applicableDays,
    bool? isDefault,
    int? scheduleId,
  }) {
    return InspectionSettings(
      id: id ?? this.id,
      settingName: settingName ?? this.settingName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      isEnabled: isEnabled ?? this.isEnabled,
      cameraOnly: cameraOnly ?? this.cameraOnly,
      exifValidationEnabled: exifValidationEnabled ?? this.exifValidationEnabled,
      exifTimeToleranceMinutes: exifTimeToleranceMinutes ?? this.exifTimeToleranceMinutes,
      gpsValidationEnabled: gpsValidationEnabled ?? this.gpsValidationEnabled,
      dormitoryLatitude: dormitoryLatitude ?? this.dormitoryLatitude,
      dormitoryLongitude: dormitoryLongitude ?? this.dormitoryLongitude,
      gpsRadiusMeters: gpsRadiusMeters ?? this.gpsRadiusMeters,
      roomPhotoValidationEnabled: roomPhotoValidationEnabled ?? this.roomPhotoValidationEnabled,
      applicableDays: applicableDays ?? this.applicableDays,
      isDefault: isDefault ?? this.isDefault,
      scheduleId: scheduleId ?? this.scheduleId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }
}

/// 점호 시간 확인 결과
/// ✅ 수정: 다음 점호 날짜 정보 추가
class InspectionTimeCheckResult {
  final bool allowed;
  final String message;
  final String? startTime;
  final String? endTime;
  final DateTime? nextInspectionDate;  // ✅ 신규: 다음 점호 날짜
  final int? daysUntilNext;            // ✅ 신규: 다음 점호까지 남은 일수

  InspectionTimeCheckResult({
    required this.allowed,
    required this.message,
    this.startTime,
    this.endTime,
    this.nextInspectionDate,
    this.daysUntilNext,
  });

  factory InspectionTimeCheckResult.fromJson(Map<String, dynamic> json) {
    return InspectionTimeCheckResult(
      allowed: json['allowed'] ?? false,
      message: json['message'] ?? '',
      startTime: json['startTime'],
      endTime: json['endTime'],
      nextInspectionDate: json['nextInspectionDate'] != null
          ? DateTime.parse(json['nextInspectionDate'])
          : null,
      daysUntilNext: json['daysUntilNext'],
    );
  }

  /// ✅ 신규: 다음 점호 날짜 포맷팅
  String? get formattedNextDate {
    if (nextInspectionDate == null) return null;
    return DateFormat('M월 d일').format(nextInspectionDate!);
  }
}