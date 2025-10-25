import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 기본 점호 모델
class InspectionModel {
  final int id;
  final String userId;
  final String roomNumber;
  final String imagePath;
  final int score;
  final String status;
  final String? geminiFeedback;
  final String? adminComment;
  final bool isReInspection;
  final DateTime inspectionDate;
  final DateTime createdAt;

  InspectionModel({
    required this.id,
    required this.userId,
    required this.roomNumber,
    required this.imagePath,
    required this.score,
    required this.status,
    this.geminiFeedback,
    this.adminComment,
    required this.isReInspection,
    required this.inspectionDate,
    required this.createdAt,
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      imagePath: json['imagePath'] ?? '',
      score: json['score'] ?? 0,
      status: json['status'] ?? 'PENDING',
      geminiFeedback: json['geminiFeedback'],
      adminComment: json['adminComment'],
      isReInspection: json['isReInspection'] ?? false,
      inspectionDate: DateTime.parse(json['inspectionDate'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'roomNumber': roomNumber,
      'imagePath': imagePath,
      'score': score,
      'status': status,
      'geminiFeedback': geminiFeedback,
      'adminComment': adminComment,
      'isReInspection': isReInspection,
      'inspectionDate': inspectionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // 편의 메서드들
  bool get isPassed => status == 'PASS';
  bool get isFailed => status == 'FAIL';
  String get scoreText => '$score/10';

  String getStatusMessage() {
    switch (status) {
      case 'PASS':
        return '통과';
      case 'FAIL':
        return '실패';
      case 'PENDING':
        return '대기중';
      default:
        return status;
    }
  }

  Color getStatusColor() {
    switch (status) {
      case 'PASS':
        return Colors.green;
      case 'FAIL':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon() {
    switch (status) {
      case 'PASS':
        return Icons.check_circle;
      case 'FAIL':
        return Icons.cancel;
      case 'PENDING':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String getFormattedDate() {
    return DateFormat('MM-dd HH:mm').format(inspectionDate);
  }
}

/// 관리자용 점호 모델 (추가 정보 포함)
class AdminInspectionModel {
  final int id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String imagePath;
  final int score;
  final String status;
  final String? geminiFeedback;
  final String? adminComment;
  final bool isReInspection;
  final DateTime inspectionDate;
  final DateTime createdAt;

  AdminInspectionModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    required this.imagePath,
    required this.score,
    required this.status,
    this.geminiFeedback,
    this.adminComment,
    required this.isReInspection,
    required this.inspectionDate,
    required this.createdAt,
  });

  factory AdminInspectionModel.fromJson(Map<String, dynamic> json) {
    return AdminInspectionModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      imagePath: json['imagePath'] ?? '',
      score: json['score'] ?? 0,
      status: json['status'] ?? 'PENDING',
      geminiFeedback: json['geminiFeedback'],
      adminComment: json['adminComment'],
      isReInspection: json['isReInspection'] ?? false,
      inspectionDate: DateTime.parse(json['inspectionDate'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'imagePath': imagePath,
      'score': score,
      'status': status,
      'geminiFeedback': geminiFeedback,
      'adminComment': adminComment,
      'isReInspection': isReInspection,
      'inspectionDate': inspectionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // InspectionModel로 변환
  InspectionModel toInspectionModel() {
    return InspectionModel(
      id: id,
      userId: userId,
      roomNumber: roomNumber,
      imagePath: imagePath,
      score: score,
      status: status,
      geminiFeedback: geminiFeedback,
      adminComment: adminComment,
      isReInspection: isReInspection,
      inspectionDate: inspectionDate,
      createdAt: createdAt,
    );
  }

  // 편의 메서드들
  bool get isPassed => status == 'PASS';
  bool get isFailed => status == 'FAIL';
  String get scoreText => '$score/10';

  String getStatusMessage() {
    switch (status) {
      case 'PASS':
        return '통과';
      case 'FAIL':
        return '실패';
      case 'PENDING':
        return '대기중';
      default:
        return status;
    }
  }

  Color getStatusColor() {
    switch (status) {
      case 'PASS':
        return Colors.green;
      case 'FAIL':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // 누락되었던 getStatusIcon 메서드 추가
  IconData getStatusIcon() {
    switch (status) {
      case 'PASS':
        return Icons.check_circle;
      case 'FAIL':
        return Icons.cancel;
      case 'PENDING':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String getFormattedDate() {
    return DateFormat('MM-dd HH:mm').format(inspectionDate);
  }

  String getFormattedDateLong() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(inspectionDate);
  }

  // 점수에 따른 등급 반환
  String getScoreGrade() {
    if (score >= 9) return 'A+';
    if (score >= 8) return 'A';
    if (score >= 7) return 'B+';
    if (score >= 6) return 'B';
    if (score >= 5) return 'C';
    return 'D';
  }

  // 재점호 여부에 따른 아이콘
  IconData getReInspectionIcon() {
    return isReInspection ? Icons.refresh : Icons.first_page;
  }

  // 사용자 정보 표시용
  String getUserDisplayName() {
    return userName.isNotEmpty ? userName : userId;
  }
}

/// 점호 통계 모델
class InspectionStatistics {
  final int totalInspections;
  final int passedInspections;
  final int failedInspections;
  final int reInspections;
  final double passRate;
  final DateTime date;

  InspectionStatistics({
    required this.totalInspections,
    required this.passedInspections,
    required this.failedInspections,
    required this.reInspections,
    required this.passRate,
    required this.date,
  });

  factory InspectionStatistics.fromJson(Map<String, dynamic> json) {
    return InspectionStatistics(
      totalInspections: json['totalInspections'] ?? 0,
      passedInspections: json['passedInspections'] ?? 0,
      failedInspections: json['failedInspections'] ?? 0,
      reInspections: json['reInspections'] ?? 0,
      passRate: (json['passRate'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalInspections': totalInspections,
      'passedInspections': passedInspections,
      'failedInspections': failedInspections,
      'reInspections': reInspections,
      'passRate': passRate,
      'date': date.toIso8601String(),
    };
  }
}

/// 점호 통계 응답 모델 (API 응답용)
class InspectionStatisticsResponse {
  final bool success;
  final InspectionStatistics statistics;
  final String? message;

  InspectionStatisticsResponse({
    required this.success,
    required this.statistics,
    this.message,
  });

  factory InspectionStatisticsResponse.fromJson(Map<String, dynamic> json) {
    return InspectionStatisticsResponse(
      success: json['success'] ?? true,
      statistics: InspectionStatistics.fromJson(json['statistics']),
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'statistics': statistics.toJson(),
      'message': message,
    };
  }
}

/// 점호 수정 요청 모델
class InspectionUpdateRequest {
  final int? score;
  final String? status;
  final String? geminiFeedback;
  final String? adminComment;
  final bool? isReInspection;

  InspectionUpdateRequest({
    this.score,
    this.status,
    this.geminiFeedback,
    this.adminComment,
    this.isReInspection,
  });

  Map<String, dynamic> toJson() {
    return {
      if (score != null) 'score': score,
      if (status != null) 'status': status,
      if (geminiFeedback != null) 'geminiFeedback': geminiFeedback,
      if (adminComment != null) 'adminComment': adminComment,
      if (isReInspection != null) 'isReInspection': isReInspection,
    };
  }
}

/// 점호 응답 모델 (수정된 버전)
class InspectionResponse {
  final bool success;
  final InspectionModel? inspection;
  final String? message;
  final String? error;

  InspectionResponse({
    required this.success,
    this.inspection,
    this.message,
    this.error,
  });

  factory InspectionResponse.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] InspectionResponse.fromJson 호출됨');
    print('[DEBUG] 받은 JSON: $json');

    bool isSuccess = false;
    InspectionModel? inspectionModel;
    String? message;
    String? errorMessage;

    try {
      // success 필드 확인
      if (json.containsKey('success')) {
        isSuccess = json['success'] == true;
      }

      // message 추출
      if (json.containsKey('message') && json['message'] != null) {
        message = json['message'].toString();
      }

      // error 처리
      if (json.containsKey('error') && json['error'] != null) {
        if (json['error'] is Map) {
          errorMessage = json['error']['message']?.toString() ?? json['error'].toString();
        } else {
          errorMessage = json['error'].toString();
        }
        isSuccess = false;
      }

      // data 필드에서 inspection 추출 (SpringBoot ApiResponse 구조)
      if (json.containsKey('data') && json['data'] != null) {
        print('[DEBUG] data 필드 발견: ${json['data']}');
        try {
          inspectionModel = InspectionModel.fromJson(json['data']);
          isSuccess = true; // data가 있으면 성공으로 처리
        } catch (e) {
          print('[DEBUG] data에서 InspectionModel 생성 실패: $e');
        }
      }

      // inspection 필드에서 직접 추출
      else if (json.containsKey('inspection') && json['inspection'] != null) {
        print('[DEBUG] inspection 필드 발견: ${json['inspection']}');
        try {
          inspectionModel = InspectionModel.fromJson(json['inspection']);
          isSuccess = true; // inspection이 있으면 성공으로 처리
        } catch (e) {
          print('[DEBUG] inspection에서 InspectionModel 생성 실패: $e');
        }
      }

      // 최종 성공 여부 결정 (inspection이 있으면 성공)
      if (inspectionModel != null) {
        isSuccess = true;
      }

      print('[DEBUG] 파싱 결과 - success: $isSuccess, inspection: ${inspectionModel != null}, message: $message, error: $errorMessage');

    } catch (e) {
      print('[ERROR] InspectionResponse JSON 파싱 오류: $e');
      errorMessage = 'JSON 파싱 오류: $e';
      isSuccess = false;
    }

    return InspectionResponse(
      success: isSuccess,
      inspection: inspectionModel,
      message: message,
      error: errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (inspection != null) 'inspection': inspection!.toJson(),
      if (message != null) 'message': message,
      if (error != null) 'error': error,
    };
  }
}

/// 점호 목록 응답 모델
class InspectionListResponse {
  final bool success;
  final List<AdminInspectionModel> inspections;
  final String? message;
  final int? count;

  InspectionListResponse({
    required this.success,
    required this.inspections,
    this.message,
    this.count,
  });

  factory InspectionListResponse.fromJson(Map<String, dynamic> json) {
    List<AdminInspectionModel> inspectionList = [];

    // data 필드에서 추출 (SpringBoot ApiResponse 구조)
    if (json.containsKey('data') && json['data'] is List) {
      inspectionList = (json['data'] as List)
          .map((item) => AdminInspectionModel.fromJson(item))
          .toList();
    }
    // inspections 필드에서 직접 추출
    else if (json.containsKey('inspections') && json['inspections'] is List) {
      inspectionList = (json['inspections'] as List)
          .map((item) => AdminInspectionModel.fromJson(item))
          .toList();
    }

    return InspectionListResponse(
      success: json['success'] ?? false,
      inspections: inspectionList,
      message: json['message'],
      count: json['count'] ?? inspectionList.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'inspections': inspections.map((e) => e.toJson()).toList(),
      'message': message,
      'count': count,
    };
  }
}

/// 오늘 점호 응답 모델
class TodayInspectionResponse {
  final bool success;
  final bool completed;
  final InspectionModel? inspection;
  final String? message;

  TodayInspectionResponse({
    required this.success,
    required this.completed,
    this.inspection,
    this.message,
  });

  factory TodayInspectionResponse.fromJson(Map<String, dynamic> json) {
    bool completed = false;
    InspectionModel? inspection;

    // data 필드 확인 (SpringBoot ApiResponse 구조)
    if (json.containsKey('data') && json['data'] != null) {
      final data = json['data'];
      completed = data['completed'] ?? false;

      if (data['inspection'] != null) {
        inspection = InspectionModel.fromJson(data['inspection']);
      }
    } else {
      // 직접 필드 확인
      completed = json['completed'] ?? false;

      if (json['inspection'] != null) {
        inspection = InspectionModel.fromJson(json['inspection']);
      }
    }

    return TodayInspectionResponse(
      success: json['success'] ?? false,
      completed: completed,
      inspection: inspection,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'completed': completed,
      if (inspection != null) 'inspection': inspection!.toJson(),
      'message': message,
    };
  }
}