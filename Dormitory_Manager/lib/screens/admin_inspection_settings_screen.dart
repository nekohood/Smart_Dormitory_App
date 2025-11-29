import 'package:flutter/material.dart';
import '../models/inspection_settings.dart';
import '../services/inspection_settings_service.dart';

/// 관리자용 점호 설정 관리 화면
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
        content: Text('"${settings.settingName}" 설정을 삭제하시겠습니까?'),
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
              _showSnackBar('설정이 생성되었습니다.');
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
        heroTag: 'fab_inspection_settings',  // ✅ heroTag 추가
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
              '점호 설정이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('설정 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: settings.isEnabled ? Colors.blue[50] : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: settings.isEnabled ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            settings.settingName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (settings.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '기본',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settings.startTime} ~ ${settings.endTime}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.isEnabled,
                  onChanged: (value) => _toggleSettings(settings),
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),

          // 설정 상세
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSettingRow(
                  icon: Icons.camera_alt,
                  label: '카메라 전용',
                  value: settings.cameraOnly ? '활성화' : '비활성화',
                  isActive: settings.cameraOnly,
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  icon: Icons.photo_camera_front,
                  label: 'EXIF 검증',
                  value: settings.exifValidationEnabled ? '활성화' : '비활성화',
                  isActive: settings.exifValidationEnabled,
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  icon: Icons.location_on,
                  label: 'GPS 검증',
                  value: settings.gpsValidationEnabled ? '활성화' : '비활성화',
                  isActive: settings.gpsValidationEnabled,
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  icon: Icons.home,
                  label: '방 사진 검증',
                  value: settings.roomPhotoValidationEnabled ? '활성화' : '비활성화',
                  isActive: settings.roomPhotoValidationEnabled,
                ),
              ],
            ),
          ),

          // 액션 버튼
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(settings: settings),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: settings.isDefault ? null : () => _deleteSettings(settings),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('삭제'),
                  style: TextButton.styleFrom(
                    foregroundColor: settings.isDefault ? Colors.grey : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isActive ? Colors.blue : Colors.grey[400]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

/// 설정 추가/수정 다이얼로그
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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final settings = InspectionSettings(
        id: widget.settings?.id,
        settingName: _nameController.text.trim(),
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
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
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.settings == null ? '점호 설정 추가' : '점호 설정 수정'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '설정 이름',
                    hintText: '예: 평일 점호',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '설정 이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text('점호 허용 시간', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selectTime(true),
                        child: Text('시작: ${_formatTime(_startTime)}'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selectTime(false),
                        child: Text('종료: ${_formatTime(_endTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('활성화'),
                  subtitle: const Text('이 설정을 사용합니다'),
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('카메라 전용'),
                  subtitle: const Text('갤러리 선택 비활성화'),
                  value: _cameraOnly,
                  onChanged: (v) => setState(() => _cameraOnly = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('EXIF 검증'),
                  subtitle: const Text('촬영 시간/위조 여부 확인'),
                  value: _exifValidation,
                  onChanged: (v) => setState(() => _exifValidation = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_exifValidation)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Text('허용 오차: '),
                        DropdownButton<int>(
                          value: _exifTolerance,
                          items: [5, 10, 15, 30, 60]
                              .map((v) => DropdownMenuItem(value: v, child: Text('$v분')))
                              .toList(),
                          onChanged: (v) => setState(() => _exifTolerance = v!),
                        ),
                      ],
                    ),
                  ),
                SwitchListTile(
                  title: const Text('GPS 검증'),
                  subtitle: const Text('기숙사 위치 확인'),
                  value: _gpsValidation,
                  onChanged: (v) => setState(() => _gpsValidation = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('방 사진 검증'),
                  subtitle: const Text('AI가 방 사진 여부 확인'),
                  value: _roomPhotoValidation,
                  onChanged: (v) => setState(() => _roomPhotoValidation = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('기본 설정'),
                  subtitle: const Text('다른 설정이 없을 때 적용'),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  contentPadding: EdgeInsets.zero,
                ),
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
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}