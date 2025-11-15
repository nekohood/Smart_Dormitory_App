/// 캘린더 이벤트 모델
class CalendarEvent {
  final int? id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? category;
  final String? color;
  final bool isAllDay;
  final bool isImportant;
  final String? location;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CalendarEvent({
    this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.category,
    this.color,
    this.isAllDay = false,
    this.isImportant = false,
    this.location,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // JSON으로부터 객체 생성
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      category: json['category'],
      color: json['color'],
      isAllDay: json['isAllDay'] ?? false,
      isImportant: json['isImportant'] ?? false,
      location: json['location'],
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      'isAllDay': isAllDay,
      'isImportant': isImportant,
      if (location != null) 'location': location,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  // 복사 생성자
  CalendarEvent copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? color,
    bool? isAllDay,
    bool? isImportant,
    String? location,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      color: color ?? this.color,
      isAllDay: isAllDay ?? this.isAllDay,
      isImportant: isImportant ?? this.isImportant,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 날짜 포맷팅
  String get formattedStartDate {
    return '${startDate.year}.${startDate.month.toString().padLeft(2, '0')}.${startDate.day.toString().padLeft(2, '0')}';
  }

  String get formattedEndDate {
    return '${endDate.year}.${endDate.month.toString().padLeft(2, '0')}.${endDate.day.toString().padLeft(2, '0')}';
  }

  String get formattedStartTime {
    return '${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    return '${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}';
  }

  // 이벤트가 오늘인지 확인
  bool get isToday {
    final now = DateTime.now();
    return startDate.year == now.year &&
        startDate.month == now.month &&
        startDate.day == now.day;
  }

  // 이벤트가 지났는지 확인
  bool get isPast {
    return endDate.isBefore(DateTime.now());
  }

  // 이벤트 기간 (일 수)
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  @override
  String toString() {
    return 'CalendarEvent{id: $id, title: $title, startDate: $startDate, endDate: $endDate}';
  }
}
