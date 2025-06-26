import 'dart:async'; // 添加這行導入
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'add_trip_screen.dart';
import '../widgets/trip_card.dart';
import '../models/trip_plan.dart';
import '../services/user_data_service.dart';
import 'attraction_planning_screen.dart';
import 'attraction_preview_screen.dart';
import '../services/auth_service.dart';
import '../services/trip_status_manager.dart'; // 添加這行導入

class TripPlanningScreen extends StatefulWidget {
  const TripPlanningScreen({super.key});

  @override
  State<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends State<TripPlanningScreen> {
  List<TripPlan> tripPlans = [];
  List<TripPlan> displayedTripPlans = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _statusCheckTimer; // 添加定時器變量

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadTrips();
    
    // 添加定時器，每分鐘檢查一次行程狀態更新
    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTripStatusUpdate();
    });
  }
  
  // 添加檢查行程狀態更新的方法
  Future<void> _checkTripStatusUpdate() async {
    try {
      print('開始檢查行程狀態更新...');
      print('更新前：TripStatusManager.status = ${TripStatusManager.status}');
      if (TripStatusManager.currentTrip != null) {
        print('更新前：當前行程 = ${TripStatusManager.currentTrip?.name}, 狀態 = ${TripStatusManager.currentTrip?.status}');
      }
      
      // 重新初始化 TripStatusManager
      await TripStatusManager.initialize();
      
      // 重新加載行程數據
      await _loadUserTrips();
      
      print('更新後：TripStatusManager.status = ${TripStatusManager.status}');
      if (TripStatusManager.currentTrip != null) {
        print('更新後：當前行程 = ${TripStatusManager.currentTrip?.name}, 狀態 = ${TripStatusManager.currentTrip?.status}');
      }
      print('行程規劃畫面：行程狀態已更新，當前狀態: ${TripStatusManager.status}');
    } catch (e) {
      print('行程規劃畫面：檢查行程狀態更新失敗: $e');
    }
  }

  Future<void> _checkLoginAndLoadTrips() async {
    try {
      bool isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        // 導航到登入頁面
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      
      // 初始化 TripStatusManager
      await TripStatusManager.initialize();
      
      _loadUserTrips();
    } catch (e) {
      setState(() {
        _errorMessage = '檢查登入狀態失敗：${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserTrips() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final userTrips = await UserDataService.getUserTrips();
      
      setState(() {
        tripPlans = userTrips;
        // 過濾掉狀態為進行中(2)或已完成(3)的行程
        displayedTripPlans = tripPlans.where((trip) => 
          trip.status == TripStatus.notStarted || 
          trip.status == TripStatus.preparation
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '無法加載行程：${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTripPlan(TripPlan tripPlan) async {
    try {
      print('開始保存行程：${tripPlan.name}');
      await UserDataService.saveTripPlan(tripPlan);
      print('行程保存成功：${tripPlan.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行程保存成功！')),
      );
    } catch (e) {
      print('保存行程失敗：${e.toString()}');
      String errorMsg = '保存行程失敗';
      if (e is AppwriteException) {
        errorMsg += '：${e.message} (錯誤碼: ${e.code})';
      } else {
        errorMsg += '：${e.toString()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Future<void> _deleteTripPlan(String tripId) async {
    try {
      await UserDataService.deleteTripPlan(tripId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除行程失敗：${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('行程規劃')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('行程規劃')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserTrips,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // 其餘的 build 方法保持不變，但修改 onDelete 和 onEdit 回調
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('行程規劃'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (displayedTripPlans.isEmpty)
            const Center(
              child: Text(
                '尚未新增新的行程規劃',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: displayedTripPlans.length,
                itemBuilder: (context, index) {
                  final tripPlan = displayedTripPlans[index];
                  return TripCard(
                    tripPlan: tripPlan,
                    onDelete: () async {
                      // 顯示加載對話框
                      _showLoadingDialog('正在刪除行程...');
                      
                      // 檢查是否為當前活動行程
                      bool isCurrentTrip = TripStatusManager.currentTrip?.id == tripPlan.id;
                      
                      if (tripPlan.id != null) {
                        await _deleteTripPlan(tripPlan.id!);
                      }
                      
                      // 如果刪除的是當前活動行程，重置 TripStatusManager 狀態
                      if (isCurrentTrip) {
                        await TripStatusManager.updateStatus(0, null);
                      }
                      
                      // 重新初始化 TripStatusManager
                      await TripStatusManager.initialize();
                      
                      // 關閉對話框並延遲刷新
                      await _closeDialogAndRefresh();
                    },
                    onEdit: (TripPlan updatedPlan) async {
                      // 顯示加載對話框
                      _showLoadingDialog('正在更新行程...');
                      
                      await _saveTripPlan(updatedPlan);
                      
                      // 關閉對話框並延遲刷新
                      await _closeDialogAndRefresh();
                    },
                    onViewAttractions: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttractionPreviewScreen(tripPlan: tripPlan),
                        ),
                      );
                    },
                    onAddAttraction: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttractionPlanningScreen(tripPlan: tripPlan),
                        ),
                      );
                      if (result != null && result is TripPlan) {
                        // 顯示加載對話框
                        _showLoadingDialog('正在更新行程...');
                        
                        // 保存行程
                        await _saveTripPlan(result);
                        
                        // 關閉對話框並延遲刷新
                        await _closeDialogAndRefresh();
                      }
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTripScreen(),
                  ),
                );
                if (result != null && result is TripPlan) {
                  // 顯示加載對話框
                  _showLoadingDialog('正在新增行程...');
                  
                  // 保存行程
                  await _saveTripPlan(result);
                  
                  // 關閉對話框並延遲刷新
                  await _closeDialogAndRefresh();
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel(); // 取消定時器
    super.dispose();
  }

  // 添加顯示加載對話框的方法
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止用戶點擊外部關閉對話框
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // 添加關閉對話框並延遲刷新的方法
  Future<void> _closeDialogAndRefresh() async {
    // 等待3秒
    await Future.delayed(const Duration(seconds: 3));
    
    // 關閉對話框
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    
    // 重新加載行程
    await _loadUserTrips();
  }
}