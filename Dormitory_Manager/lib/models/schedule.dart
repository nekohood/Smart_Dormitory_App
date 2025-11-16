/// 학사 일정 모델
class Schedule {
  final int id;
  final String title;
  final String? content;
  final DateTime startDate; // ✅ eventDate -> startDate
  final DateTime? endDate;  // ✅ endDate 추가
  final String? category;   // ✅ category 추가

  Schedule({
    required this.id,
    required this.title,
    this.content,
    required this.startDate, // ✅
    this.endDate,
    this.category,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? 0,
      title: json['title'] ?? '제목 없음',
      content: json['content'],
      // ✅ eventDate -> startDate
      startDate: DateTime.parse(json['startDate']),
      // ✅ endDate는 null일 수 있음
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      // ✅ 서버로 보낼 때는 항상 UTC의 ISO 8601 문자열로 변환
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate?.toUtc().toIso8601String(),
      'category': category,
    };
  }
}