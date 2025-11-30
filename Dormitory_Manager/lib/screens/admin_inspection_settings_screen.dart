import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection_settings.dart';
import '../services/inspection_settings_service.dart';

/// 관리자용 점호 설정 관리 화면
/// ✅ 수정: 점호 날짜 선택 기능 추가
class AdminInspectionSettingsScreen extends StatefulWidget {
  const AdminInspectionSettingsScreen({super.key});

  @override
  State<AdminInspectionSettingsScreen> createState() => _AdminInspectionSettingsScreenState();
}

class _AdminInspectionSettingsScreenState extends State<AdminInspectionSettingsScreen> {
  List<InspectionSettings> _settings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await InspectionSettingsService.getAllSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '설정을 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSettings(InspectionSettings settings) async {
    try {
      final result = await InspectionSettingsService.toggleSettings(settings.id!);
      if (result != null) {
        _showSnackBar(result.isEnabled ? '설정이 활성화되었습니다.' : '설정이 비활성화되었습니다.');
        _loadSettings();
      }
    } catch (e) {
      _showSnackBar('설정 변경에 실패했습니다.', isError: true);
    }
  }

  Future<void> _deleteSettings(InspectionSettings settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${settings.settingName}" 설정을 삭제하시겠습니까?'),
            if (settings.scheduleId != null) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ 연결된 캘린더 일정도 함께 삭제됩니다.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await InspectionSettingsService.deleteSettings(settings.id!);
        if (success) {
          _showSnackBar('설정이 삭제되었습니다.');
          _loadSettings();
        } else {
          _showSnackBar('설정 삭제에 실패했습니다.', isError: true);
        }
      } catch (e) {
        _showSnackBar('설정 삭제에 실패했습니다.', isError: true);
      }
    }
  }

  void _showAddEditDialog({InspectionSettings? settings}) {
    showDialog(
      context: context,
      builder: (context) => _SettingsEditDialog(
        settings: settings,
        onSave: (newSettings) async {
          try {
            if (settings != null) {
              await InspectionSettingsService.updateSettings(settings.id!, newSettings);
              _showSnackBar('설정이 수정되었습니다.');
            } else {
              await InspectionSettingsService.createSettings(newSettings);
              _showSnackBar('설정이 생성되었습니다. 📅 캘린더에 자동 등록됩니다.');
            }
            _loadSettings();
          } catch (e) {
            _showSnackBar('저장에 실패했습니다.', isError: true);
          }
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('점호 설정 관리'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_inspection_settings',
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSettings,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_settings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '점호 설정이 없습니다.\n+ 버튼을 눌러 새 설정을 추가하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _settings.length,
        itemBuilder: (context, index) => _buildSettingsCard(_settings[index]),
      ),
    );
  }

  Widget _buildSettingsCard(InspectionSettings settings) {
    final isActive = settings.isEnabled;
    final hasDate = settings.inspectionDate != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.blue : Colors.grey[300]!,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddEditDialog(settings: settings),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 이름, 상태
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          settings.settingName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black : Colors.grey,
                          ),
                        ),
                        if (settings.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '기본',
                              style: TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 활성화 스위치
                  Switch(
                    value: isActive,
                    onChanged: (_) => _toggleSettings(settings),
                    activeColor: Colors.blue,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ 점호 날짜 표시
              if (hasDate) ...[
                _buildDateChip(settings),
                const SizedBox(height: 10),
              ],

              // 시간, 검증 옵션
              Row(
                children: [
                  _buildInfoChip(
                    Icons.access_time,
                    '${settings.startTime} ~ ${settings.endTime}',
                    isActive,
                  ),
                  const SizedBox(width: 8),
                  if (settings.exifValidationEnabled)
                    _buildInfoChip(Icons.verified, 'EXIF', isActive),
                  if (settings.gpsValidationEnabled) ...[
                    const SizedBox(width: 4),
                    _buildInfoChip(Icons.location_on, 'GPS', isActive),
                  ],
                  if (settings.roomPhotoValidationEnabled) ...[
                    const SizedBox(width: 4),
                    _buildInfoChip(Icons.home, 'AI', isActive),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // 하단: 버튼들
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (settings.scheduleId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: const Text('캘린더 연동됨'),
                        backgroundColor: Colors.green[50],
                        labelStyle: TextStyle(fontSize: 11, color: Colors.green[700]),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAddEditDialog(settings: settings),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('수정'),
                  ),
                  if (!settings.isDefault)
                    TextButton.icon(
                      onPressed: () => _deleteSettings(settings),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('삭제'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 신규: 점호 날짜 칩 위젯 (null-safe)
  Widget _buildDateChip(InspectionSettings settings) {
    final int days = settings.daysUntilInspection ?? 0;

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color textColor;
    String dDayText;

    if (days == 0) {
      bgColor = Colors.green[50]!;
      borderColor = Colors.green[300]!;
      iconColor = Colors.green[700]!;
      textColor = Colors.green[700]!;
      dDayText = '오늘';
    } else if (days > 0) {
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[300]!;
      iconColor = Colors.blue[700]!;
      textColor = Colors.blue[700]!;
      dDayText = 'D-$days';
    } else {
      bgColor = Colors.grey[100]!;
      borderColor = Colors.grey[300]!;
      iconColor = Colors.grey[600]!;
      textColor = Colors.grey[600]!;
      dDayText = '지남';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            settings.formattedInspectionDate ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: days == 0 ? Colors.green : (days > 0 ? Colors.blue : Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              dDayText,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? Colors.blue : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 설정 추가/수정 다이얼로그
/// ✅ 수정: 점호 날짜 선택 기능 추가
class _SettingsEditDialog extends StatefulWidget {
  final InspectionSettings? settings;
  final Function(InspectionSettings) onSave;

  const _SettingsEditDialog({this.settings, required this.onSave});

  @override
  State<_SettingsEditDialog> createState() => _SettingsEditDialogState();
}

class _SettingsEditDialogState extends State<_SettingsEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  DateTime? _inspectionDate;  // ✅ 신규: 점호 날짜

  bool _isEnabled = true;
  bool _cameraOnly = true;
  bool _exifValidation = true;
  int _exifTolerance = 10;
  bool _gpsValidation = false;
  bool _roomPhotoValidation = true;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings != null) {
      final s = widget.settings!;
      _nameController.text = s.settingName;
      _startTime = _parseTime(s.startTime);
      _endTime = _parseTime(s.endTime);
      _inspectionDate = s.inspectionDate;  // ✅ 신규
      _isEnabled = s.isEnabled;
      _cameraOnly = s.cameraOnly;
      _exifValidation = s.exifValidationEnabled;
      _exifTolerance = s.exifTimeToleranceMinutes;
      _gpsValidation = s.gpsValidationEnabled;
      _roomPhotoValidation = s.roomPhotoValidationEnabled;
      _isDefault = s.isDefault;
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  /// ✅ 신규: 날짜 선택
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _inspectionDate = picked;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final settings = InspectionSettings(
      settingName: _nameController.text.trim(),
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      inspectionDate: _inspectionDate,  // ✅ 신규
      isEnabled: _isEnabled,
      cameraOnly: _cameraOnly,
      exifValidationEnabled: _exifValidation,
      exifTimeToleranceMinutes: _exifTolerance,
      gpsValidationEnabled: _gpsValidation,
      roomPhotoValidationEnabled: _roomPhotoValidation,
      isDefault: _isDefault,
    );

    widget.onSave(settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.settings != null;

    return AlertDialog(
      title: Text(isEditing ? '점호 설정 수정' : '새 점호 설정'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 설정 이름
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '설정 이름 *',
                    hintText: '예: 평일 저녁 점호',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '설정 이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ✅ 신규: 점호 날짜 선택
                const Text('점호 날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '특정 날짜에만 점호를 진행하려면 날짜를 선택하세요.\n미선택 시 매일 점호가 가능합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(8),
                            color: _inspectionDate != null ? Colors.blue[50] : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: _inspectionDate != null ? Colors.blue : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _inspectionDate != null
                                    ? DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_inspectionDate!)
                                    : '날짜 선택 (선택사항)',
                                style: TextStyle(
                                  color: _inspectionDate != null ? Colors.blue[700] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_inspectionDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () => setState(() => _inspectionDate = null),
                        tooltip: '날짜 초기화',
                      ),
                  ],
                ),
                if (_inspectionDate != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_available, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '📅 저장 시 캘린더에 자동 등록됩니다',
                          style: TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 점호 시간
                const Text('점호 시간', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeButton('시작', _startTime, () => _selectTime(true)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: _buildTimeButton('종료', _endTime, () => _selectTime(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 검증 옵션들
                const Text('검증 옵션', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildSwitchTile('카메라 촬영만 허용', _cameraOnly, (v) => setState(() => _cameraOnly = v)),
                _buildSwitchTile('EXIF 검증', _exifValidation, (v) => setState(() => _exifValidation = v)),
                if (_exifValidation)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Text('허용 오차: '),
                        DropdownButton<int>(
                          value: _exifTolerance,
                          items: [5, 10, 15, 30, 60].map((v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v분'),
                          )).toList(),
                          onChanged: (v) => setState(() => _exifTolerance = v!),
                        ),
                      ],
                    ),
                  ),
                _buildSwitchTile('GPS 위치 검증', _gpsValidation, (v) => setState(() => _gpsValidation = v)),
                _buildSwitchTile('AI 방 사진 검증', _roomPhotoValidation, (v) => setState(() => _roomPhotoValidation = v)),

                const Divider(),

                _buildSwitchTile('활성화', _isEnabled, (v) => setState(() => _isEnabled = v)),
                _buildSwitchTile('기본 설정으로 지정', _isDefault, (v) => setState(() => _isDefault = v)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? '수정' : '생성'),
        ),
      ],
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Text(_formatTime(time), style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}