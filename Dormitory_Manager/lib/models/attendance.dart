/// 출석 테이블 관련 모델
library;

class AttendanceEntry {
  final int id;
  final DateTime inspectionDate;
  final String roomNumber;
  final String userId;
  final String userName;
  final bool isSubmitted;
  final DateTime? submissionTime;
  final int? score;
  final String status; // PENDING, PASS, FAIL
  final String? notes;

  AttendanceEntry({
    required this.id,
    required this.inspectionDate,
    required this.roomNumber,
    required this.userId,
    required this.userName,
    required this.isSubmitted,
    this.submissionTime,
    this.score,
    required this.status,
    this.notes,
  });

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    return AttendanceEntry(
      id: json['id'],
      inspectionDate: DateTime.parse(json['inspectionDate']),
      roomNumber: json['roomNumber'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      isSubmitted: json['isSubmitted'] ?? false,
      submissionTime: json['submissionTime'] != null 
          ? DateTime.parse(json['submissionTime'])
          : null,
      score: json['score'],
      status: json['status'] ?? 'PENDING',
      notes: json['notes'],
    );
  }
}

class AttendanceStatistics {
  final int totalRooms;
  final int submittedRooms;
  final int pendingRooms;
  final double submissionRate;

  AttendanceStatistics({
    required this.totalRooms,
    required this.submittedRooms,
    required this.pendingRooms,
    required this.submissionRate,
  });

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) {
    return AttendanceStatistics(
      totalRooms: json['totalRooms'] ?? 0,
      submittedRooms: json['submittedRooms'] ?? 0,
      pendingRooms: json['pendingRooms'] ?? 0,
      submissionRate: (json['submissionRate'] ?? 0.0).toDouble(),
    );
  }
}

class AttendanceTableResponse {
  final DateTime inspectionDate;
  final List<AttendanceEntry> entries;
  final AttendanceStatistics statistics;

  AttendanceTableResponse({
    required this.inspectionDate,
    required this.entries,
    required this.statistics,
  });

  factory AttendanceTableResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceTableResponse(
      inspectionDate: DateTime.parse(json['inspectionDate']),
      entries: (json['entries'] as List)
          .map((e) => AttendanceEntry.fromJson(e))
          .toList(),
      statistics: AttendanceStatistics.fromJson(json['statistics']),
    );
  }
}
