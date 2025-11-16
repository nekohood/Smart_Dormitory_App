class Schedule {
  final int id;
  final String title;
  final DateTime eventDate;

  Schedule({
    required this.id,
    required this.title,
    required this.eventDate,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      title: json['title'],
      eventDate: DateTime.parse(json['eventDate']),
    );
  }
}