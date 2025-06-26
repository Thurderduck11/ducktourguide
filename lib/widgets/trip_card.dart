import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import '../screens/edit_trip_screen.dart';
import '../services/trip_status_manager.dart';  // 添加這行導入

class TripCard extends StatefulWidget {
  final TripPlan tripPlan;
  final VoidCallback onDelete;
  final Function(TripPlan) onEdit;  // 修改這裡
  final VoidCallback onViewAttractions;
  final VoidCallback onAddAttraction;

  const TripCard({
    super.key,
    required this.tripPlan,
    required this.onDelete,
    required this.onEdit,
    required this.onViewAttractions,
    required this.onAddAttraction,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool isActive = false;
  
  @override
  void initState() {
    super.initState();
    _updateSwitchState(); // 初始化時設定一次
  }
  
  @override
  void didUpdateWidget(covariant TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當 widget 的屬性更新時（例如 tripPlan 變化），重新設定 Switch 狀態
    if (widget.tripPlan != oldWidget.tripPlan) {
      _updateSwitchState();
    }
  }
  
  // 更新開關狀態
  void _updateSwitchState() {
    setState(() {
      // 根據行程狀態設置開關
      // 確保只看自己的 tripPlan.status
      if (widget.tripPlan.status == TripStatus.preparation ||
          widget.tripPlan.status == TripStatus.inProgress) {
        isActive = true;
      } else {
        isActive = false;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[100],
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行程名稱區塊
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[300],
              width: double.infinity,
              child: Text(
                widget.tripPlan.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // 時間區塊
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[300],
              width: double.infinity,
              child: Text(
                '${_formatDateTime(widget.tripPlan.startTime)} - ${_formatDateTime(widget.tripPlan.endTime)}',
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 按鈕區域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onViewAttractions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      '景點預覽',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,  // 添加粗體
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onAddAttraction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      '景點規劃',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,  // 添加粗體
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditTripScreen(tripPlan: widget.tripPlan),
                        ),
                      );
                      if (result != null && result is TripPlan) {
                        widget.onEdit(result);  // 傳遞更新後的行程數據
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      '旅遊行程更改',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,  // 添加粗體
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 行程狀態和刪除按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '行程狀態：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, 2),
                      child: Switch(
                        value: isActive,
                        onChanged: (bool value) async {
                          // 更新TripStatusManager的狀態
                          if (value) {
                            // 開啟 - 設置為預備狀態(1)
                            print('將行程 ${widget.tripPlan.name} 設置為預備狀態');
                            await TripStatusManager.updateStatus(1, widget.tripPlan);
                          } else {
                            // 關閉 - 設置為無行程狀態(0)
                            print('將行程 ${widget.tripPlan.name} 設置為無行程狀態');
                            await TripStatusManager.updateStatus(0, widget.tripPlan);
                          }
                          
                          // 更新UI
                          setState(() {
                            isActive = value;
                          });
                          
                          // 通知父組件行程已更新
                          widget.onEdit(widget.tripPlan);
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        isActive ? '開啟' : '關閉',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('確認刪除'),
                          content: const Text('您確定要刪除這個行程嗎？'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onDelete();
                              },
                              child: const Text(
                                '確定',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[300],
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16, // 放大2px
                    ),
                  ),
                  child: const Text(
                    '刪除行程',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,  // 添加粗體
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute}';
  }
}