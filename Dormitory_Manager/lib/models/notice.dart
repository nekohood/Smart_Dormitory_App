import '../api/api_config.dart'; // ApiConfig 임포트

class Notice {
  final int id;
  final String title;
  final String content;
  final String? imagePath;
  final String author;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final int viewCount;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    this.imagePath,
    required this.author,
    required this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.viewCount = 0,
  });

  // ✅ UTC 시간을 한국 시간(KST, UTC+9)으로 변환하는 헬퍼 메서드
  static DateTime _parseToKST(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return DateTime.now();
    }

    try {
      DateTime parsed = DateTime.parse(dateTimeString);

      // 서버에서 받은 시간이 UTC인 경우 KST로 변환
      // DateTime.parse()는 'Z' 또는 타임존 정보가 없으면 로컬로 처리
      // 서버가 UTC로 보내는 경우를 대비하여 명시적으로 9시간 추가
      if (dateTimeString.endsWith('Z') || dateTimeString.contains('+00:00')) {
        // UTC 시간인 경우 KST(+9시간)로 변환
        return parsed.toLocal();
      } else if (!dateTimeString.contains('+') && !dateTimeString.contains('-', 10)) {
        // 타임존 정보가 없는 경우 (서버가 UTC로 저장했지만 Z를 붙이지 않은 경우)
        // UTC로 간주하고 KST로 변환
        final utcTime = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
        );
        return utcTime.toLocal();
      }

      // 이미 로컬 타임존 정보가 포함된 경우
      return parsed.toLocal();
    } catch (e) {
      print('[ERROR] DateTime 파싱 실패: $dateTimeString, 에러: $e');
      return DateTime.now();
    }
  }

  // JSON에서 Notice 객체 생성
  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      imagePath: json['imagePath'],
      author: json['author'] ?? '관리자',
      // ✅ UTC → KST 변환 적용
      createdAt: _parseToKST(json['createdAt']?.toString()),
      updatedAt: json['updatedAt'] != null
          ? _parseToKST(json['updatedAt'].toString())
          : null,
      isPinned: json['isPinned'] ?? false,
      viewCount: json['viewCount'] ?? 0,
    );
  }

  // Notice 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imagePath': imagePath,
      'author': author,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isPinned': isPinned,
      'viewCount': viewCount,
    };
  }

  // Notice 객체 복사 (일부 필드 수정용)
  Notice copyWith({
    int? id,
    String? title,
    String? content,
    String? imagePath,
    String? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? viewCount,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      viewCount: viewCount ?? this.viewCount,
    );
  }

  // ✅ 이미지 URL 생성 (개선된 버전 - uploads 접두사 추가)
  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) {
      print('[DEBUG] Notice imageUrl: imagePath is null or empty');
      return null;
    }

    // ApiConfig.baseUrl에서 '/api' 부분을 제거하여 순수 호스트 주소를 만듭니다.
    final hostUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    // imagePath가 이미 'uploads/'로 시작하는지 확인
    String normalizedPath = imagePath!;
    if (!normalizedPath.startsWith('uploads/') && !normalizedPath.startsWith('/uploads/')) {
      // uploads/ 접두사 추가
      normalizedPath = 'uploads/$normalizedPath';
    }

    // 경로가 '/'로 시작하지 않으면 추가
    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }

    final fullUrl = '$hostUrl$normalizedPath';
    print('[DEBUG] Notice imageUrl: imagePath=$imagePath, fullUrl=$fullUrl');

    return fullUrl;
  }

  // 공지사항이 새로운지 확인 (3일 이내)
  bool get isNew {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inDays < 3;
  }

  // 생성일로부터 경과 시간 문자열
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

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
    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}';
  }

  // 날짜와 시간 포맷팅 (yyyy.MM.dd HH:mm)
  String get formattedDateTime {
    return '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'Notice{id: $id, title: $title, author: $author, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}