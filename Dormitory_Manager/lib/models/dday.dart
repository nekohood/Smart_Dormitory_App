/// D-Day 모델
class DDay {
  final int? id;
  final String title;
  final String? description;
  final DateTime targetDate;
  final String? color;
  final bool isActive;
  final bool isImportant;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? daysRemaining; // 남은 일수
  final bool? isPast; // 지난 날짜인지
  final bool? isToday; // 오늘인지

  DDay({
    this.id,
    required this.title,
    this.description,
    required this.targetDate,
    this.color,
    this.isActive = true,
    this.isImportant = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.daysRemaining,
    this.isPast,
    this.isToday,
  });

  // JSON으로부터 객체 생성
  factory DDay.fromJson(Map<String, dynamic> json) {
    return DDay(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      targetDate: DateTime.parse(json['targetDate']),
      color: json['color'],
      isActive: json['isActive'] ?? true,
      isImportant: json['isImportant'] ?? false,
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      daysRemaining: json['daysRemaining'],
      isPast: json['isPast'],
      isToday: json['isToday'],
    );
  }

  // 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      'targetDate': targetDate.toIso8601String().split('T')[0], // 날짜만 전송
      if (color != null) 'color': color,
      'isActive': isActive,
      'isImportant': isImportant,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  // 복사 생성자
  DDay copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? targetDate,
    String? color,
    bool? isActive,
    bool? isImportant,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? daysRemaining,
    bool? isPast,
    bool? isToday,
  }) {
    return DDay(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      isImportant: isImportant ?? this.isImportant,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isPast: isPast ?? this.isPast,
      isToday: isToday ?? this.isToday,
    );
  }

  // 날짜 포맷팅
  String get formattedTargetDate {
    return '${targetDate.year}.${targetDate.month.toString().padLeft(2, '0')}.${targetDate.day.toString().padLeft(2, '0')}';
  }

  // D-Day 텍스트 생성
  String get ddayText {
    if (isToday == true) {
      return 'D-Day';
    } else if (isPast == true) {
      return 'D+${(daysRemaining ?? 0).abs()}';
    } else {
      return 'D-${daysRemaining ?? 0}';
    }
  }

  // 남은 일수 계산 (로컬)
  int calculateDaysRemaining() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  // 지난 날짜인지 확인 (로컬)
  bool checkIsPast() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.isBefore(today);
  }

  // 오늘인지 확인 (로컬)
  bool checkIsToday() {
    final now = DateTime.now();
    return targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
  }

  @override
  String toString() {
    return 'DDay{id: $id, title: $title, targetDate: $targetDate, daysRemaining: $daysRemaining}';
  }
}
