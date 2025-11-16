import 'package:flutter/material.dart';
import 'package:dormitory_manager/models/schedule.dart';
import 'package:dormitory_manager/services/schedule_service.dart';
import 'package:intl/intl.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({Key? key}) : super(key: key);

  @override
  _AdminScheduleScreenState createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() { _isLoading = true; });
    final schedules = await _scheduleService.getAllSchedules();
    setState(() {
      _schedules = schedules;
      _isLoading = false;
    });
  }

  Future<void> _showScheduleDialog({Schedule? schedule}) async {
    final titleController = TextEditingController(text: schedule?.title);
    DateTime selectedDate = schedule?.eventDate ?? DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(schedule == null ? '일정 추가' : '일정 수정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '일정 제목'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    final title = titleController.text;
                    if (title.isEmpty) return;

                    bool success;
                    if (schedule == null) {
                      success = await _scheduleService.createSchedule(title, selectedDate);
                    } else {
                      success = await _scheduleService.updateSchedule(schedule.id, title, selectedDate);
                    }
                    Navigator.of(context).pop(success);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _loadSchedules();
    }
  }

  Future<void> _deleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('정말로 이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _scheduleService.deleteSchedule(id);
      if (success) {
        _loadSchedules();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 관리'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final schedule = _schedules[index];
          return ListTile(
            title: Text(schedule.title),
            subtitle: Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(schedule.eventDate)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showScheduleDialog(schedule: schedule),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSchedule(schedule.id),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showScheduleDialog(),
      ),
    );
  }
}