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

  // JSON에서 Notice 객체 생성
  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      imagePath: json['imagePath'],
      author: json['author'] ?? '관리자',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
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

  // 이미지 URL 생성 (ApiConfig 사용하도록 수정)
  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    final hostUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$hostUrl/$imagePath';
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