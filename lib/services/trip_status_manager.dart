import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import 'user_data_service.dart';

/// 行程狀態管理器
/// 狀態說明：
/// 0 - 無行程
/// 1 - 預備狀態（有行程但未開始）
/// 2 - 行程進行中
/// 3 - 行程已結束
class TripStatusManager {
  static int _status = 0;
  static TripPlan? _currentTrip;
  static String? _lastTripId; // 添加這個變量來記錄最後一次設置的行程 ID
  
  /// 獲取當前狀態
  static int get status => _status;
  
  /// 獲取當前行程
  static TripPlan? get currentTrip => _currentTrip;
  
  /// 初始化狀態
  static Future<void> initialize() async {
    try {
      final trips = await UserDataService.getUserTrips();
      print('測試status是否正確獲得');
      if (trips.isEmpty) {
        _status = 0; // 無行程
        _currentTrip = null;
        _lastTripId = null; // 清除最後一次設置的行程 ID
        print('初始化完成：無行程');
        return;
      }
      
      print(trips[0].status);
      
      // 獲取當前時間
      final now = DateTime.now();
      
      // 按照優先級排序行程：
      // 1. 進行中的行程
      // 2. 即將開始的行程（開始時間最接近當前時間的）
      // 3. 最後一次設置的行程（如果仍然有效）
      // 4. 第一個行程
      
      TripPlan? selectedTrip;
      
      // 1. 首先查找進行中的行程
      for (var trip in trips) {
        if (trip.status == TripStatus.inProgress) {
          selectedTrip = trip;
          print('找到進行中的行程: ${trip.name}');
          break;
        }
      }
      
      // 2. 如果沒有進行中的行程，查找即將開始的行程（開始時間在當前時間之後且最接近當前時間的）
      if (selectedTrip == null) {
        TripPlan? nearestTrip;
        Duration? minDuration;
        
        for (var trip in trips) {
          if (trip.startTime.isAfter(now) && 
              (trip.status == TripStatus.preparation || trip.status == TripStatus.notStarted)) {
            final duration = trip.startTime.difference(now);
            if (minDuration == null || duration < minDuration) {
              minDuration = duration;
              nearestTrip = trip;
            }
          }
        }
        
        if (nearestTrip != null) {
          selectedTrip = nearestTrip;
          print('找到即將開始的行程: ${selectedTrip.name}，開始時間: ${selectedTrip.startTime}');
        }
      }
      
      // 3. 如果仍未找到合適的行程，嘗試使用最後一次設置的行程（如果存在且有效）
      if (selectedTrip == null && _lastTripId != null && _lastTripId!.isNotEmpty) {
        for (var trip in trips) {
          if (trip.id == _lastTripId) {
            // 檢查該行程是否仍然有效（未結束或開始時間在未來）
            if (trip.status != TripStatus.completed || trip.startTime.isAfter(now)) {
              selectedTrip = trip;
              print('使用上次設置的有效行程: ${trip.name}');
            } else {
              print('上次設置的行程 ${trip.name} 已結束或過期，尋找其他行程');
            }
            break;
          }
        }
      }
      
      // 4. 如果仍然沒有找到行程，使用第一個行程
      if (selectedTrip == null && trips.isNotEmpty) {
        selectedTrip = trips.first;
        print('使用第一個行程: ${selectedTrip.name}');
      }
      
      // 確保 selectedTrip 不為 null
      if (selectedTrip == null) {
        _status = 0;
        _currentTrip = null;
        _lastTripId = null;
        print('初始化完成：無有效行程');
        return;
      }
      
      _currentTrip = selectedTrip;
      
      // 安全地設置 _lastTripId，確保它不為 null
      if (selectedTrip.id != null && selectedTrip.id!.isNotEmpty) {
        _lastTripId = selectedTrip.id;
        print('設置最後一次行程 ID: $_lastTripId');
      } else {
        _lastTripId = null;
        print('警告：當前行程沒有有效的 ID');
      }
      
      // 直接根據行程的 TripStatus 設置對應的數字狀態
      switch (selectedTrip.status) {
        case TripStatus.notStarted:
          _status = 0;
          break;
        case TripStatus.preparation:
          _status = 1;
          break;
        case TripStatus.inProgress:
          _status = 2;
          break;
        case TripStatus.completed:
          _status = 3;
          break;
      }
      
      print('初始化完成：行程 ${_currentTrip?.name} 狀態為 ${_currentTrip?.status}，_status=$_status');
    } catch (e) {
      print('初始化行程狀態失敗: $e');
      _status = 0;
      _currentTrip = null;
      _lastTripId = null;
    }
  }
  
  /// 更新狀態
  static Future<void> updateStatus(int newStatus, [TripPlan? tripPlan]) async {
    if (newStatus < 0 || newStatus > 3) return;

    print('觸發Function');
    print(StackTrace.current);

    // 打印當前狀態和新狀態
    print('更新行程狀態: 從 $_status 到 $newStatus');
    print('當前行程: ${_currentTrip?.name ?? "無行程"}');
    
    _status = newStatus;
    if (tripPlan != null) {
      _currentTrip = tripPlan;
      _lastTripId = tripPlan.id; // 更新最後一次設置的行程 ID
      print('使用提供的行程: ${tripPlan.name}');
    } else {
      print('沒有提供行程，使用當前行程: ${_currentTrip?.name ?? "無行程"}');
    }
    
    // 根據狀態更新行程
    if (_currentTrip != null) {
      print('更新行程 ID: ${_currentTrip!.id ?? "新行程"}');
      
      switch (newStatus) {
        case 0: // 無行程
          _currentTrip!.status = TripStatus.notStarted;
          print('設置行程狀態為: 無行程');
          break;
        case 1: // 預備狀態
          _currentTrip!.status = TripStatus.preparation; // 確保這個枚舉值存在
          print('設置行程狀態為: 預備狀態');
          break;
        case 2: // 行程進行中
          _currentTrip!.status = TripStatus.inProgress;
          _currentTrip!.actualStartTime = DateTime.now();
          print('設置行程狀態為: 進行中，開始時間: ${_currentTrip!.actualStartTime}');
          break;
        case 3: // 行程已結束
          _currentTrip!.status = TripStatus.completed;
          _currentTrip!.actualEndTime = DateTime.now();
          print('設置行程狀態為: 已結束，結束時間: ${_currentTrip!.actualEndTime}');
          break;
      }
      
      // 上傳到雲端
      try {
        print('準備上傳行程到雲端...');
        print('行程詳情: ID=${_currentTrip!.id}, 名稱=${_currentTrip!.name}, 狀態=${_currentTrip!.status}');
        await UserDataService.saveTripPlan(_currentTrip!);
        print('行程狀態已更新並上傳到雲端');
      } catch (e) {
        print('上傳行程狀態失敗: $e');
      }
    } else {
      print('警告: 沒有當前行程，無法更新狀態');
    }
  }
  
  /// 獲取狀態顏色
  static Color getStatusColor(BuildContext context) {
    switch (_status) {
      case 0: // 無行程
        return Colors.transparent;
      case 1: // 預備狀態
        return Colors.transparent; // 淺綠色
      case 2: // 行程進行中
        return Colors.lightGreen.shade400; // 較亮的綠色
      case 3: // 行程已結束
        return Colors.lightGreen.shade200; // 更淺的綠色
      default:
        return Colors.transparent;
    }
  }
}