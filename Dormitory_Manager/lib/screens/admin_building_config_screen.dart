import 'package:flutter/material.dart';
import '../api/dio_client.dart';

/// 기숙사 테이블 설정 관리 화면
/// 관리자가 기숙사별 층/호실 범위를 설정
class AdminBuildingConfigScreen extends StatefulWidget {
  const AdminBuildingConfigScreen({super.key});

  @override
  State<AdminBuildingConfigScreen> createState() => _AdminBuildingConfigScreenState();
}

class _AdminBuildingConfigScreenState extends State<AdminBuildingConfigScreen> {
  List<Map<String, dynamic>> _configs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await DioClient.get('/admin/building-config');

      if (response.data['success'] == true) {
        final List<dynamic> configList = response.data['data']['configs'] ?? [];
        setState(() {
          _configs = configList.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message'] ?? '설정 로드 실패');
      }
    } catch (e) {
      print('[ERROR] 테이블 설정 로드 실패: $e');
      setState(() {
        _errorMessage = '설정을 불러오는데 실패했습니다.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConfig(int id, String buildingName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 삭제'),
        content: Text('"$buildingName" 설정을 삭제하시겠습니까?'),
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
        final response = await DioClient.delete('/admin/building-config/$id');

        if (response.data['success'] == true) {
          _showSnackBar('설정이 삭제되었습니다.');
          _loadConfigs();
        } else {
          throw Exception(response.data['message']);
        }
      } catch (e) {
        _showSnackBar('삭제 실패: $e', isError: true);
      }
    }
  }

  Future<void> _toggleConfig(int id) async {
    try {
      final response = await DioClient.patch('/admin/building-config/$id/toggle');

      if (response.data['success'] == true) {
        _showSnackBar(response.data['message']);
        _loadConfigs();
      }
    } catch (e) {
      _showSnackBar('상태 변경 실패: $e', isError: true);
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? config}) {
    showDialog(
      context: context,
      builder: (context) => _ConfigEditDialog(
        config: config,
        onSave: (data) async {
          try {
            if (config != null) {
              // 수정
              await DioClient.put('/admin/building-config/${config['id']}', data: data);
              _showSnackBar('설정이 수정되었습니다.');
            } else {
              // 생성
              await DioClient.post('/admin/building-config', data: data);
              _showSnackBar('설정이 생성되었습니다.');
            }
            _loadConfigs();
          } catch (e) {
            _showSnackBar('저장 실패: $e', isError: true);
          }
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('테이블 설정 관리'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfigs,
            tooltip: '새로고침',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConfigs,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      )
          : _configs.isEmpty
          ? _buildEmptyState()
          : _buildConfigList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '등록된 테이블 설정이 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 새 설정을 추가하세요.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigList() {
    return RefreshIndicator(
      onRefresh: _loadConfigs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _configs.length,
        itemBuilder: (context, index) {
          return _buildConfigCard(_configs[index]);
        },
      ),
    );
  }

  Widget _buildConfigCard(Map<String, dynamic> config) {
    final buildingName = config['buildingName'] ?? '';
    final startFloor = config['startFloor'] ?? 2;
    final endFloor = config['endFloor'] ?? 13;
    final startRoom = config['startRoom'] ?? 1;
    final endRoom = config['endRoom'] ?? 20;
    final isActive = config['isActive'] ?? true;
    final totalRoomCount = config['totalRoomCount'] ?? 0;
    final description = config['description'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green[200]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAddEditDialog(config: config),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.apartment,
                        color: isActive ? Colors.blue : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buildingName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.black : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 활성화 토글
                      Switch(
                        value: isActive,
                        onChanged: (value) => _toggleConfig(config['id']),
                        activeColor: Colors.green,
                      ),
                      // 더보기 메뉴
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditDialog(config: config);
                          } else if (value == 'delete') {
                            _deleteConfig(config['id'], buildingName);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('수정'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('삭제', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 층/호실 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoColumn('층수', '$startFloor ~ $endFloor층', Icons.layers),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    _buildInfoColumn('호실', '$startRoom ~ $endRoom호', Icons.door_front_door),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    _buildInfoColumn('총 방', '$totalRoomCount개', Icons.grid_view),
                  ],
                ),
              ),

              if (description != null && description.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

/// 테이블 설정 편집 다이얼로그
class _ConfigEditDialog extends StatefulWidget {
  final Map<String, dynamic>? config;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _ConfigEditDialog({
    this.config,
    required this.onSave,
  });

  @override
  State<_ConfigEditDialog> createState() => _ConfigEditDialogState();
}

class _ConfigEditDialogState extends State<_ConfigEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _buildingNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _startFloor = 2;
  int _endFloor = 13;
  int _startRoom = 1;
  int _endRoom = 20;
  String _roomNumberFormat = 'FLOOR_ROOM';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _buildingNameController.text = widget.config!['buildingName'] ?? '';
      _descriptionController.text = widget.config!['description'] ?? '';
      _startFloor = widget.config!['startFloor'] ?? 2;
      _endFloor = widget.config!['endFloor'] ?? 13;
      _startRoom = widget.config!['startRoom'] ?? 1;
      _endRoom = widget.config!['endRoom'] ?? 20;
      _roomNumberFormat = widget.config!['roomNumberFormat'] ?? 'FLOOR_ROOM';
    }
  }

  @override
  void dispose() {
    _buildingNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 유효성 검사
    if (_startFloor > _endFloor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 층수는 종료 층수보다 작거나 같아야 합니다.')),
      );
      return;
    }
    if (_startRoom > _endRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 호실은 종료 호실보다 작거나 같아야 합니다.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave({
        'buildingName': _buildingNameController.text.trim(),
        'startFloor': _startFloor,
        'endFloor': _endFloor,
        'startRoom': _startRoom,
        'endRoom': _endRoom,
        'roomNumberFormat': _roomNumberFormat,
        'description': _descriptionController.text.trim(),
      });
      Navigator.pop(context);
    } catch (e) {
      // 에러는 onSave에서 처리
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.config != null;
    final totalRooms = (_endFloor - _startFloor + 1) * (_endRoom - _startRoom + 1);

    return AlertDialog(
      title: Text(isEditing ? '테이블 설정 수정' : '테이블 설정 추가'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기숙사 동 이름
                TextFormField(
                  controller: _buildingNameController,
                  decoration: const InputDecoration(
                    labelText: '기숙사 동 이름 *',
                    hintText: '예: 제1기숙사',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '기숙사 동 이름을 입력하세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 층수 범위
                const Text('층수 범위', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberDropdown(
                        label: '시작 층',
                        value: _startFloor,
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _startFloor = v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: _buildNumberDropdown(
                        label: '종료 층',
                        value: _endFloor,
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _endFloor = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 호실 범위
                const Text('호실 범위', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberDropdown(
                        label: '시작 호실',
                        value: _startRoom,
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _startRoom = v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: _buildNumberDropdown(
                        label: '종료 호실',
                        value: _endRoom,
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _endRoom = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 미리보기
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '총 ${_endFloor - _startFloor + 1}개 층 × ${_endRoom - _startRoom + 1}개 호실 = $totalRooms개 방',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 방 번호 형식
                const Text('방 번호 형식', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _roomNumberFormat,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'FLOOR_ROOM',
                      child: Text('층×100+호실 (예: 201, 1320)'),
                    ),
                    DropdownMenuItem(
                      value: 'FLOOR_ZERO_ROOM',
                      child: Text('층×1000+호실 (예: 2001, 13020)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _roomNumberFormat = v);
                  },
                ),
                const SizedBox(height: 16),

                // 설명
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택)',
                    hintText: '메모 또는 설명',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(isEditing ? '수정' : '추가'),
        ),
      ],
    );
  }

  Widget _buildNumberDropdown({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: List.generate(max - min + 1, (i) => min + i)
          .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}