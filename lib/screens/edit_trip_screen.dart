import 'package:flutter/material.dart';
import '../models/trip_plan.dart';

class EditTripScreen extends StatefulWidget {
  final TripPlan tripPlan;

  const EditTripScreen({
    super.key,
    required this.tripPlan,
  });

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tripNameController;
  DateTime? startTime;
  DateTime? endTime;

  @override
  void initState() {
    super.initState();
    // 初始化控制器並設置初始值
    _tripNameController = TextEditingController(text: widget.tripPlan.name);
    startTime = widget.tripPlan.startTime;
    endTime = widget.tripPlan.endTime;
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  Future<DateTime?> _showDateTimePicker() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更改行程'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tripNameController,
                decoration: const InputDecoration(
                  labelText: '行程名稱',
                  border: OutlineInputBorder(),
                  hintText: '請輸入行程名稱',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入行程名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              
              // 開始時間
              Row(
                children: [
                  const Text('開始時間：'),
                  Expanded(
                    child: Text(
                      startTime != null ? _formatDateTime(startTime!) : '請選擇時間',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () async {
                      final DateTime? picked = await _showDateTimePicker();
                      if (picked != null) {
                        setState(() {
                          startTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16.0),
              
              // 結束時間
              Row(
                children: [
                  const Text('結束時間：'),
                  Expanded(
                    child: Text(
                      endTime != null ? _formatDateTime(endTime!) : '請選擇時間',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () async {
                      final DateTime? picked = await _showDateTimePicker();
                      if (picked != null) {
                        setState(() {
                          endTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              
              const Spacer(),
              
              // 儲存更改按鈕
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && 
                        startTime != null && 
                        endTime != null) {
                      // 檢查時間是否早於現在
                      final now = DateTime.now();
                      if (startTime!.isBefore(now)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('開始時間不能早於現在時間'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      
                      if (endTime!.isBefore(now)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('結束時間不能早於現在時間'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      // 檢查結束時間是否早於開始時間
                      if (endTime!.isBefore(startTime!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('結束時間不能早於開始時間，請重新選擇'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      // 創建更新後的行程規劃
                      final updatedTripPlan = TripPlan(
                        id: widget.tripPlan.id, // 保留原始行程的 ID
                        name: _tripNameController.text,
                        startTime: startTime!,
                        endTime: endTime!,
                        attractions: widget.tripPlan.attractions, // 保留原有的景點
                        visits: widget.tripPlan.visits, // 保留原有的訪問記錄
                        restStops: widget.tripPlan.restStops, // 保留原有的休息時間
                        status: widget.tripPlan.status, // 保留原有的狀態
                        actualStartTime: widget.tripPlan.actualStartTime, // 保留原有的實際開始時間
                        actualEndTime: widget.tripPlan.actualEndTime, // 保留原有的實際結束時間
                      );

                      // 返回更新後的行程規劃
                      Navigator.pop(context, updatedTripPlan);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('請填寫所有必要資訊'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    '儲存更改',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}