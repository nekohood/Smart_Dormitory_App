import 'package:flutter/material.dart';
import '../models/dday.dart';
import '../services/dday_service.dart';
import '../utils/storage_helper.dart';

/// 사용자용 D-Day 화면
class DDayScreen extends StatefulWidget {
  const DDayScreen({super.key});

  @override
  State<DDayScreen> createState() => _DDayScreenState();
}

class _DDayScreenState extends State<DDayScreen> {
  final DDayService _ddayService = DDayService();
  
  List<DDay> _ddays = [];
  List<DDay> _filteredDDays = [];
  bool _isLoading = true;
  bool _showOnlyImportant = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadDDays();
  }

  /// 서비스 초기화
  Future<void> _initializeService() async {
    try {
      final token = await StorageHelper.getToken();
      if (token != null) {
        _ddayService.setAuthToken(token);
      }
    } catch (e) {
      print('[ERROR] D-Day 화면 - 토큰 설정 실패: $e');
    }
  }

  /// D-Day 목록 로드
  Future<void> _loadDDays() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ddays = await _ddayService.getAllActiveDDays();
      
      setState(() {
        _ddays = ddays;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      print('[ERROR] D-Day 목록 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('D-Day 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  /// 필터 적용
  void _applyFilter() {
    if (_showOnlyImportant) {
      _filteredDDays = _ddays.where((dday) => dday.isImportant).toList();
    } else {
      _filteredDDays = _ddays;
    }
  }

  /// 중요 필터 토글
  void _toggleImportantFilter() {
    setState(() {
      _showOnlyImportant = !_showOnlyImportant;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          'D-Day',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyImportant ? Icons.star : Icons.star_border,
              color: _showOnlyImportant ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleImportantFilter,
            tooltip: '중요 일정만 보기',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDDays,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredDDays.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showOnlyImportant
                            ? '중요한 D-Day가 없습니다'
                            : 'D-Day가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDDays,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDDays.length,
                    itemBuilder: (context, index) {
                      return _buildDDayCard(_filteredDDays[index]);
                    },
                  ),
                ),
    );
  }

  /// D-Day 카드 위젯
  Widget _buildDDayCard(DDay dday) {
    final cardColor = _getCardColor(dday);
    final textColor = _getTextColor(dday);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardColor,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDDayDetail(dday),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목과 중요 표시
              Row(
                children: [
                  if (dday.isImportant) ...[
                    Icon(
                      Icons.star,
                      size: 20,
                      color: textColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      dday.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // D-Day 카운터
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 날짜 정보
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: textColor.withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dday.formattedTargetDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (dday.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          dday.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  
                  // D-Day 숫자
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dday.ddayText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카드 색상 반환 (D-Day에 따라)
  List<Color> _getCardColor(DDay dday) {
    if (dday.isToday == true) {
      // 오늘
      return [Colors.red.shade400, Colors.red.shade600];
    } else if (dday.isPast == true) {
      // 지난 날짜
      return [Colors.grey.shade400, Colors.grey.shade600];
    } else {
      final days = dday.daysRemaining ?? 0;
      if (days <= 3) {
        // 3일 이내
        return [Colors.orange.shade400, Colors.orange.shade600];
      } else if (days <= 7) {
        // 7일 이내
        return [Colors.amber.shade400, Colors.amber.shade600];
      } else if (days <= 30) {
        // 30일 이내
        return [Colors.blue.shade400, Colors.blue.shade600];
      } else {
        // 30일 초과
        return [Colors.green.shade400, Colors.green.shade600];
      }
    }
  }

  /// 텍스트 색상 반환
  Color _getTextColor(DDay dday) {
    return Colors.white;
  }

  /// D-Day 상세 정보 표시
  void _showDDayDetail(DDay dday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (dday.isImportant) ...[
              const Icon(Icons.star, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                dday.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // D-Day 표시
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCardColor(dday),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    dday.ddayText,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 날짜 정보
              const Text(
                '목표 날짜',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dday.formattedTargetDate,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // 설명
              if (dday.description != null) ...[
                const Text(
                  '설명',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dday.description!,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
              ],
              
              // 상태
              Row(
                children: [
                  if (dday.isImportant)
                    Chip(
                      label: const Text('중요'),
                      avatar: const Icon(Icons.star, size: 16),
                      backgroundColor: Colors.orange.shade100,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (dday.isToday == true)
                    Chip(
                      label: const Text('오늘'),
                      avatar: const Icon(Icons.today, size: 16),
                      backgroundColor: Colors.red.shade100,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
