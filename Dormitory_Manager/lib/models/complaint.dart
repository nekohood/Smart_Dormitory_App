import 'package:flutter/material.dart';
import '../api/api_config.dart'; // ApiConfig 임포트

class Complaint {
  final int id;
  final String title;
  final String content;
  final String category;
  final String writerId;
  final String? writerName;
  final String? dormitoryBuilding; // ✅ 기숙사 거주 동 (자동 기입)
  final String? roomNumber; // ✅ 방 번호 (자동 기입)
  final String? imagePath;
  final String status; // 대기, 처리중, 완료, 반려
  final String? adminComment;
  final DateTime submittedAt;
  final DateTime? processedAt;
  final DateTime? updatedAt;

  Complaint({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.writerId,
    this.writerName,
    this.dormitoryBuilding,
    this.roomNumber,
    this.imagePath,
    required this.status,
    this.adminComment,
    required this.submittedAt,
    this.processedAt,
    this.updatedAt,
  });

  // JSON에서 Complaint 객체 생성
  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      writerId: json['writerId'] ?? '',
      writerName: json['writerName'],
      dormitoryBuilding: json['dormitoryBuilding'], // ✅ 거주 동 파싱
      roomNumber: json['roomNumber'], // ✅ 방 번호 파싱
      imagePath: json['imagePath'],
      status: json['status'] ?? '대기',
      adminComment: json['adminComment'],
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // Complaint 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'writerId': writerId,
      'writerName': writerName,
      'dormitoryBuilding': dormitoryBuilding, // ✅ 거주 동 직렬화
      'roomNumber': roomNumber, // ✅ 방 번호 직렬화
      'imagePath': imagePath,
      'status': status,
      'adminComment': adminComment,
      'submittedAt': submittedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // =============================================================================
  // Getter 메서드들 (기존 프로젝트와 호환)
  // =============================================================================

  // 상태별 색상 반환
  Color get statusColor {
    switch (status) {
      case '대기':
        return const Color(0xFFFF9800); // 주황색
      case '처리중':
        return const Color(0xFF2196F3); // 파란색
      case '완료':
        return const Color(0xFF4CAF50); // 초록색
      case '반려':
        return const Color(0xFFF44336); // 빨간색
      default:
        return const Color(0xFF9E9E9E); // 회색
    }
  }

  // 상태별 아이콘 반환
  IconData get statusIcon {
    switch (status) {
      case '대기':
        return Icons.schedule;
      case '처리중':
        return Icons.pending;
      case '완료':
        return Icons.check_circle;
      case '반려':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // 이미지 URL 생성 (ApiConfig 사용)
  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    // ApiConfig.baseUrl에서 '/api' 부분을 제거하여 순수 호스트 주소를 만듭니다.
    final hostUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    // 서버의 상대 경로를 절대 URL로 변환합니다.
    return '$hostUrl/$imagePath';
  }

  // 제출일로부터 경과 시간 문자열
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(submittedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 날짜 포맷팅 (yyyy.MM.dd)
  String get formattedDate {
    return '${submittedAt.year}.${submittedAt.month.toString().padLeft(2, '0')}.${submittedAt.day.toString().padLeft(2, '0')}';
  }

  // 날짜와 시간 포맷팅 (yyyy.MM.dd HH:mm)
  String get formattedDateTime {
    return '${submittedAt.year}.${submittedAt.month.toString().padLeft(2, '0')}.${submittedAt.day.toString().padLeft(2, '0')} '
        '${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';
  }

  // 민원이 새로운지 확인 (1일 이내)
  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(submittedAt);
    return difference.inDays < 1;
  }

  // 처리 완료 여부
  bool get isCompleted {
    return status == '완료' || status == '반려';
  }

  // ✅ 거주 정보 존재 여부 확인
  bool get hasLocationInfo => dormitoryBuilding != null && roomNumber != null;

  // ✅ 거주 정보 포맷팅 (예: "A동 301호")
  String? get formattedLocation {
    if (dormitoryBuilding != null && roomNumber != null) {
      return '$dormitoryBuilding $roomNumber호';
    }
    return null;
  }

  // 객체 복사 (일부 필드 수정용)
  Complaint copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    String? writerId,
    String? writerName,
    String? dormitoryBuilding,
    String? roomNumber,
    String? imagePath,
    String? status,
    String? adminComment,
    DateTime? submittedAt,
    DateTime? processedAt,
    DateTime? updatedAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      writerId: writerId ?? this.writerId,
      writerName: writerName ?? this.writerName,
      dormitoryBuilding: dormitoryBuilding ?? this.dormitoryBuilding,
      roomNumber: roomNumber ?? this.roomNumber,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      adminComment: adminComment ?? this.adminComment,
      submittedAt: submittedAt ?? this.submittedAt,
      processedAt: processedAt ?? this.processedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Complaint{id: $id, title: $title, writerId: $writerId, status: $status, dormitoryBuilding: $dormitoryBuilding, roomNumber: $roomNumber}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Complaint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}