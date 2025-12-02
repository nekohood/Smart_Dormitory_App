/// 시간 변환 유틸리티
/// ✅ Railway 서버가 UTC를 사용하므로 KST(+9)로 변환 필요

/// UTC → KST 변환 헬퍼 함수
DateTime parseToKST(String? dateTimeString) {
  if (dateTimeString == null) return DateTime.now();
  
  try {
    DateTime parsed = DateTime.parse(dateTimeString);
    
    // 서버에서 UTC로 오는 경우 KST로 변환
    // DateTime.parse()가 'Z' 접미사나 타임존 정보 없이 파싱하면 local로 처리됨
    // 하지만 Railway 서버는 UTC 시간을 보내므로 명시적으로 변환 필요
    if (!dateTimeString.endsWith('Z') && !dateTimeString.contains('+')) {
      // 타임존 정보가 없으면 UTC로 간주하고 KST(+9)로 변환
      parsed = parsed.add(const Duration(hours: 9));
    } else {
      // 타임존 정보가 있으면 toLocal()로 변환
      parsed = parsed.toLocal();
    }
    
    return parsed;
  } catch (e) {
    return DateTime.now();
  }
}

/// dynamic 타입 지원 버전
DateTime parseToKSTDynamic(dynamic dateTime) {
  if (dateTime == null) return DateTime.now();
  
  if (dateTime is DateTime) {
    return dateTime;
  }
  
  if (dateTime is String) {
    return parseToKST(dateTime);
  }
  
  return DateTime.now();
}
