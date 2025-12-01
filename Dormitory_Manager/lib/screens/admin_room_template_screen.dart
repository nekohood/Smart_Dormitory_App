import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/room_template.dart';
import '../services/room_template_service.dart';
import '../api/api_config.dart';

/// 이미지 URL 생성 헬퍼 (baseUrl에서 /api 제거)
String _getImageUrl(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) return '';
  final hostUrl = ApiConfig.baseUrl.replaceAll('/api', '');
  return '$hostUrl/uploads/$imagePath';
}

/// 관리자용 방 템플릿 관리 화면
class AdminRoomTemplateScreen extends StatefulWidget {
  const AdminRoomTemplateScreen({super.key});

  @override
  State<AdminRoomTemplateScreen> createState() => _AdminRoomTemplateScreenState();
}

class _AdminRoomTemplateScreenState extends State<AdminRoomTemplateScreen> {
  List<RoomTemplate> _templates = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templates = await RoomTemplateService.getAllTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '템플릿을 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<RoomTemplate> get _filteredTemplates {
    if (_selectedFilter == 'ALL') {
      return _templates;
    }
    return _templates.where((t) => t.roomType == _selectedFilter).toList();
  }

  Future<void> _toggleTemplate(RoomTemplate template) async {
    try {
      final result = await RoomTemplateService.toggleTemplate(template.id!);
      if (result != null) {
        _showSnackBar(result.isActive ? '템플릿이 활성화되었습니다.' : '템플릿이 비활성화되었습니다.');
        _loadTemplates();
      }
    } catch (e) {
      _showSnackBar('상태 변경에 실패했습니다.', isError: true);
    }
  }

  Future<void> _deleteTemplate(RoomTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text('"${template.templateName}" 템플릿을 삭제하시겠습니까?'),
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
        final success = await RoomTemplateService.deleteTemplate(template.id!);
        if (success) {
          _showSnackBar('템플릿이 삭제되었습니다.');
          _loadTemplates();
        } else {
          _showSnackBar('삭제에 실패했습니다.', isError: true);
        }
      } catch (e) {
        _showSnackBar('삭제에 실패했습니다.', isError: true);
      }
    }
  }

  void _showAddEditDialog({RoomTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _TemplateEditDialog(
        template: template,
        onSave: (newTemplate, imageFile) async {
          try {
            if (template != null) {
              await RoomTemplateService.updateTemplate(
                id: template.id!,
                templateName: newTemplate.templateName,
                roomType: newTemplate.roomType,
                imageFile: imageFile,
                description: newTemplate.description,
                buildingName: newTemplate.buildingName,
                isDefault: newTemplate.isDefault,
              );
              _showSnackBar('템플릿이 수정되었습니다.');
            } else {
              if (imageFile == null) {
                _showSnackBar('이미지를 선택해주세요.', isError: true);
                return;
              }
              await RoomTemplateService.createTemplate(
                templateName: newTemplate.templateName,
                roomType: newTemplate.roomType,
                imageFile: imageFile,
                description: newTemplate.description,
                buildingName: newTemplate.buildingName,
                isDefault: newTemplate.isDefault,
              );
              _showSnackBar('템플릿이 등록되었습니다.');
            }
            _loadTemplates();
          } catch (e) {
            _showSnackBar('저장에 실패했습니다: $e', isError: true);
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
      appBar: AppBar(
        title: const Text('기준 방 사진 관리'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTemplates,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_room_template',  // ✅ heroTag 추가
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('템플릿 추가'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 필터 버튼
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', '전체'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SINGLE', '1인실'),
                  const SizedBox(width: 8),
                  _buildFilterChip('DOUBLE', '2인실'),
                  const SizedBox(width: 8),
                  _buildFilterChip('MULTI', '다인실'),
                ],
              ),
            ),
          ),

          // 템플릿 목록
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildContent() {
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
            Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTemplates,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '등록된 템플릿이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '기준 방 사진을 등록하면\nAI 점호 평가 시 비교 기준으로 사용됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredTemplates.length,
        itemBuilder: (context, index) => _buildTemplateCard(_filteredTemplates[index]),
      ),
    );
  }

  Widget _buildTemplateCard(RoomTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                _getImageUrl(template.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('[ERROR] 이미지 로드 실패: ${_getImageUrl(template.imagePath)}, 에러: $error');
                  return Container(
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          '이미지 로드 실패',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ),

          // 정보
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.templateName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (template.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '기본',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Switch(
                      value: template.isActive,
                      onChanged: (value) => _toggleTemplate(template),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        template.roomTypeDisplayName,
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                    if (template.buildingName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          template.buildingName!,
                          style: TextStyle(color: Colors.green[700], fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                if (template.description != null && template.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    template.description!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // 액션 버튼
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(template: template),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteTemplate(template),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('삭제'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 템플릿 추가/수정 다이얼로그
class _TemplateEditDialog extends StatefulWidget {
  final RoomTemplate? template;
  final Function(RoomTemplate, XFile?) onSave;

  const _TemplateEditDialog({
    this.template,
    required this.onSave,
  });

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _buildingController;

  String _selectedRoomType = 'SINGLE';
  bool _isDefault = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;  // ✅ 이미지 바이트 데이터 추가
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.templateName ?? '');
    _descriptionController = TextEditingController(text: widget.template?.description ?? '');
    _buildingController = TextEditingController(text: widget.template?.buildingName ?? '');
    _selectedRoomType = widget.template?.roomType ?? 'SINGLE';
    _isDefault = widget.template?.isDefault ?? false;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      // ✅ 이미지 바이트 데이터도 함께 로드
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (widget.template == null && _selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 선택해주세요.'), backgroundColor: Colors.red),
        );
        return;
      }

      final template = RoomTemplate(
        id: widget.template?.id,
        templateName: _nameController.text.trim(),
        roomType: _selectedRoomType,
        imagePath: widget.template?.imagePath ?? '',
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        buildingName: _buildingController.text.trim().isEmpty
            ? null
            : _buildingController.text.trim(),
        isDefault: _isDefault,
      );

      widget.onSave(template, _selectedImage);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? '기준 방 사진 등록' : '기준 방 사진 수정'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 선택
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _selectedImageBytes != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                    )
                        : widget.template?.imagePath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(widget.template!.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('이미지 선택', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 템플릿 이름
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '템플릿 이름',
                    hintText: '예: 1인실 기준 사진',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '템플릿 이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 방 타입
                DropdownButtonFormField<String>(
                  value: _selectedRoomType,
                  decoration: const InputDecoration(
                    labelText: '방 타입',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SINGLE', child: Text('1인실')),
                    DropdownMenuItem(value: 'DOUBLE', child: Text('2인실')),
                    DropdownMenuItem(value: 'MULTI', child: Text('다인실')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRoomType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 동 이름 (선택)
                TextFormField(
                  controller: _buildingController,
                  decoration: const InputDecoration(
                    labelText: '동 이름 (선택)',
                    hintText: '예: A동 (비워두면 전체 적용)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // 설명 (선택)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택)',
                    hintText: '예: 깔끔하게 정리된 상태',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 기본 템플릿 설정
                SwitchListTile(
                  title: const Text('기본 템플릿으로 설정'),
                  subtitle: const Text('해당 방 타입의 기본 비교 대상'),
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
    _descriptionController.dispose();
    _buildingController.dispose();
    super.dispose();
  }
}