import 'dart:math';
import 'package:flutter/material.dart';
import '../services/user_data_service.dart';
import '../screens/trip_status_screen.dart';
import '../models/trip_plan.dart';
  // 在文件頂部添加導入
  import '../services/trip_status_manager.dart';
  import '../services/trip_timer_service.dart'; // 添加 trip_timer_service.dart 導入
  import '../services/background_service.dart'; // 添加 background_service.dart 導入

class CircularMenu extends StatefulWidget {
  final Function? onReloadMarkers;
  final Function? onLocateCurrentPosition; // 新增定位當前位置的回調
  
  const CircularMenu({
    super.key,
    this.onReloadMarkers,
    this.onLocateCurrentPosition, // 新增參數
  });

  @override
  State<CircularMenu> createState() => CircularMenuState();
}

// 將私有的 _CircularMenuState 改為公開的 CircularMenuState
class CircularMenuState extends State<CircularMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;
  bool _isLocating = false; // 追蹤是否正在定位
  bool _isCentered = true; // 追蹤地圖是否在當前位置
  final TripTimerService _tripTimerService = TripTimerService(); // 初始化 TripTimerService
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 初始化行程狀態
    _initTripStatus();
  }
  
  // 添加初始化行程狀態的方法
  void _initTripStatus() async {
    print('初始化行程狀態...');
    await TripStatusManager.initialize();
    print('行程狀態初始化完成，當前狀態: ${TripStatusManager.status}');
    print('當前行程: ${TripStatusManager.currentTrip?.name ?? "無行程"}');
    setState(() {}); // 更新UI
  }
  
  // 添加行程狀態按鈕方法 - 修改位置計算方式，使其與定位按鈕相對於螢幕中心線對稱
  Widget _buildTripStatusButton() {
    const double buttonSize = 56.0; // 設定固定的按鈕大小
    
    return Positioned(
      left: 40, // 距離左邊 20px
      bottom: 70, // 與定位按鈕高度相同
      child: SizedBox(  // 使用 SizedBox 確保按鈕大小固定
        width: buttonSize,
        height: buttonSize,
        child: ElevatedButton(
          onPressed: () async {
            print("行程狀態按鈕被點擊");
            
            // 根據當前狀態執行不同操作
            switch (TripStatusManager.status) {
              case 0: // 無行程
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請先打開菜單開始行程')),
                );
                break;
              case 1: // 預備狀態
                if (TripStatusManager.currentTrip != null && context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripStatusScreen(tripPlan: TripStatusManager.currentTrip!),
                    ),
                  );
                  
                  // 返回後重新初始化狀態
                  await TripStatusManager.initialize();
                  setState(() {}); // 更新UI
                }
                break;
              case 2: // 進行中
              case 3: // 已結束
                if (TripStatusManager.currentTrip != null && context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripStatusScreen(tripPlan: TripStatusManager.currentTrip!),
                    ),
                  );
                  
                  // 返回後重新初始化狀態
                  await TripStatusManager.initialize();
                  setState(() {}); // 更新UI
                }
                break;
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TripStatusManager.getStatusColor(context),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero, // 移除內邊距以確保大小一致
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.directions_walk,
                size: 24,
                color: TripStatusManager.status > 0 ? 
                  Colors.white : Colors.white.withOpacity(0.5), // 只有在有行程時才顯示完全不透明
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // 修改 _toggle 方法，使其與 TripStatusManager 連動
  /*void _toggle() async {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
        // 菜單打開時，將狀態設為 1（預備狀態）
        _updateTripStatus(1);
      } else {
        _controller.reverse();
        // 菜單關閉時，將狀態設為 0（無行程）
        _updateTripStatus(0);
      }
    });
  }*/
  
  // 添加更新行程狀態的方法
  void _updateTripStatus(int newStatus) async {
    // 先刷新行程狀態，確保狀態與當前時間匹配
    await BackgroundService.refreshTripStatus();
    
    // 只有在當前狀態不是進行中（2）或已結束（3）時才更新
    if (TripStatusManager.status != 2 && TripStatusManager.status != 3) {
      print('準備更新行程狀態為: $newStatus');
      
      // 如果當前沒有行程，但需要設置為預備狀態（1），則先獲取用戶行程
      if (TripStatusManager.currentTrip == null && newStatus == 1) {
        print('當前沒有行程，嘗試獲取用戶行程');
        try {
          final trips = await UserDataService.getUserTrips();
          if (trips.isNotEmpty) {
            print('找到用戶行程: ${trips.first.name}');
            await TripStatusManager.updateStatus(newStatus, trips.first);
          } else {
            print('用戶沒有行程，無法設置為預備狀態');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請先創建行程')),
            );
            return;
          }
        } catch (e) {
          print('獲取用戶行程失敗: $e');
          return;
        }
      } else {
        // 使用當前行程更新狀態
        await TripStatusManager.updateStatus(newStatus, TripStatusManager.currentTrip);
      }
      
      // 如果狀態為 1（預備狀態）且有當前行程，啟動行程計時器
      if (newStatus == 1 && TripStatusManager.currentTrip != null) {
        print('啟動行程計時器: ${TripStatusManager.currentTrip!.name}');
        _tripTimerService.startTripTimer(TripStatusManager.currentTrip!);
      } else if (newStatus == 0) {
        // 如果狀態為 0（無行程），取消行程計時器
        print('取消行程計時器');
        _tripTimerService.cancelTripTimer();
      }
      
      setState(() {}); // 更新UI
    } else {
      print('當前狀態為 ${TripStatusManager.status}，不更新為 $newStatus');
    }
  }
  
  // 處理定位當前位置
  void _locateCurrentPosition() async {
    setState(() {
      _isLocating = true; // 開始定位
      _isCentered = true; // 設置為已置中
    });
    
    if (widget.onLocateCurrentPosition != null) {
      try {
        await widget.onLocateCurrentPosition!();
        print("定位當前位置成功");
      } catch (e) {
        print("定位當前位置出錯: $e");
      }
    } else {
      print("未提供定位當前位置回調");
    }
    
    // 保持動畫顯示一段時間
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isLocating = false; // 結束定位
    });
  }

  // 設置地圖是否置中
  void setMapCentered(bool centered) {
    if (_isCentered != centered) {
      setState(() {
        _isCentered = centered;
      });
    }
  }

  // 修改：定位按鈕部分
  Widget _buildLocationButton() {
    const double buttonSize = 56.0; // 設定固定的按鈕大小
    
    return Positioned(
      right: 0,
      bottom: 70,
      child: SizedBox(  // 使用 SizedBox 確保按鈕大小固定
        width: buttonSize,
        height: buttonSize,
        child: ElevatedButton(
          onPressed: () {
            if (widget.onLocateCurrentPosition != null) {
              widget.onLocateCurrentPosition!();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero, // 移除內邊距以確保大小一致
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.my_location,
                size: 24,
                color: Colors.white.withOpacity(_isCentered ? 1.0 : 0.7),
              ),
              if (!_isCentered)
                SizedBox(  // 使用 SizedBox 確保動畫效果大小固定
                  width: buttonSize,
                  height: buttonSize,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return CustomPaint(
                        size: Size(buttonSize, buttonSize),
                        painter: LocationPulseEffect(
                          progress: value,
                          color: Colors.white,
                          showCenter: _isCentered,
                        ),
                      );
                    },
                    onEnd: () {
                      if (!_isCentered) {
                        setState(() {}); // 重新觸發動畫
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 定義統一的按鈕樣式
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.lightBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      minimumSize: const Size(120, 40), // 設定最小寬高，確保所有按鈕大小一致
      alignment: Alignment.centerLeft, // 將按鈕內容統一置左
    );

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: MediaQuery.of(context).size.width, // 確保按鈕有足夠空間
        height: 350, // 確保按鈕有足夠空間
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 背景覆蓋層 - 只在菜單打開時顯示
            if (_isOpen)
              Positioned(
                left: -1000,
                top: -1000,
                right: -1000,
                bottom: -1000,
                child: GestureDetector(
                  //onTap: _toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
              ),
            
            // 設定按鈕 - 使用滑動特效
            _buildAnimatedButton(
              icon: Icons.settings,
              label: "設定",
              onPressed: () {
                print("設定按鈕被點擊");
                Navigator.pushNamed(context, '/settings');
                //_toggle();
              },
              index: 0,
              buttonStyle: buttonStyle,
            ),
            
            // 行程規劃按鈕 - 使用滑動特效
            _buildAnimatedButton(
              icon: Icons.map,
              label: "行程規劃",
              onPressed: () {
                print("行程規劃按鈕被點擊");
                Navigator.pushNamed(context, '/trip_planning');
                //_toggle();
              },
              index: 1,
              buttonStyle: buttonStyle,
            ),
            
            // 旅行紀錄按鈕 - 使用滑動特效
            _buildAnimatedButton(
              icon: Icons.photo_album,
              label: "旅行紀錄",
              onPressed: () {
                print("旅行紀錄按鈕被點擊");
                Navigator.pushNamed(context, '/travel_records');
                //_toggle();
              },
              index: 2,
              buttonStyle: buttonStyle,
            ),
            
            // 首頁按鈕 - 使用滑動特效（調整索引回到原本的位置）
            _buildAnimatedButton(
              icon: Icons.home,
              label: "首頁",
              onPressed: () async {
                print("首頁按鈕被點擊");
                
                if (widget.onReloadMarkers != null) {
                  try {
                    await widget.onReloadMarkers!();
                    print("重新加載景點完成");
                  } catch (e) {
                    print("重新加載景點出錯: $e");
                  }
                } else {
                  print("未提供重新加載景點回調");
                  Navigator.pushReplacementNamed(context, '/map');
                }
                //_toggle();
              },
              index: 3,  // 調整索引回到原本的位置
              buttonStyle: buttonStyle,
            ),
            
            // 使用統一的定位按鈕實現
            _buildLocationButton(),
            
            // 添加行程狀態按鈕
            _buildTripStatusButton(),
            
            // 主按鈕 - 始終顯示
            Positioned(
              right: 0,
              bottom: 0,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isOpen = !_isOpen;
                    if (_isOpen) {
                      _controller.forward();
                    } else {
                      _controller.reverse();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _controller,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 新增帶有滑動特效的按鈕方法
  Widget _buildAnimatedButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required int index,
    required ButtonStyle buttonStyle,
  }) {
    // 計算按鈕位置
    final bottomPosition = index * 60.0;
    
    // 創建滑動動畫
    final animation = Tween(
      begin: const Offset(1.0, 0.0), // 從右側開始
      end: Offset.zero, // 滑動到原位置
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          0.1 * index, // 每個按鈕的動畫開始時間錯開
          0.6 + 0.1 * index, // 每個按鈕的動畫結束時間也錯開
          curve: Curves.easeOutBack, // 使用彈性曲線
        ),
      ),
    );
    
    return Positioned(
      right: 70,
      bottom: bottomPosition,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Visibility(
            visible: _controller.value > 0.1 * index, // 當動畫開始時才顯示
            child: SlideTransition(
              position: animation,
              child: ElevatedButton(
                onPressed: onPressed,
                style: buttonStyle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start, // 確保內容靠左對齊
                  children: [
                    Icon(icon, size: 24, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(label, style: const TextStyle(fontSize: 14, color: Colors.white)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 定位脈衝效果的自定義繪製
class LocationPulseEffect extends CustomPainter {
  final double progress;
  final Color color;
  final bool showCenter; // 是否顯示中心點
  
  LocationPulseEffect({
    required this.progress,
    required this.color,
    this.showCenter = true,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 繪製脈衝圓圈
    final paint = Paint()
      ..color = color.withOpacity(1.0 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 繪製擴散的圓圈
    canvas.drawCircle(center, 10 + 10 * progress, paint);
    
    // 繪製十字準心
    final crossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // 水平線
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      crossPaint,
    );
    
    // 垂直線
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      crossPaint,
    );
    
    // 只在置中時繪製中心點
    if (showCenter) {
      final centerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 2, centerPaint);
    }
  }
  
  @override
  bool shouldRepaint(LocationPulseEffect oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color ||
           oldDelegate.showCenter != showCenter;
  }
}
