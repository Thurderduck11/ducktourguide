import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import '../services/notification_service.dart';
import '../services/trip_status_manager.dart'; // 添加這行
import '../services/user_data_service.dart'; // 添加這行

class TripTimerService {
  static final TripTimerService _instance = TripTimerService._internal();
  factory TripTimerService() => _instance;
  TripTimerService._internal();
  
  final NotificationService _notificationService = NotificationService();
  Timer? _tripTimer;
  TripPlan? _currentTripPlan;
  
  // 啟動行程計時器
  void startTripTimer(TripPlan tripPlan) {
    _currentTripPlan = tripPlan;
    
    // 取消現有計時器
    _tripTimer?.cancel();
    
    // 計算距離行程開始的時間
    final now = DateTime.now();
    final tripStartTime = tripPlan.startTime;
    
    if (now.isBefore(tripStartTime)) {
      final difference = tripStartTime.difference(now);
      
      debugPrint('行程將在 ${difference.inMinutes} 分鐘後開始');
      
      // 設置計時器
      _tripTimer = Timer(difference, () {
        _sendTripStartNotification();
      });
    }
  }
  
  // 修改發送行程開始通知方法
  void _sendTripStartNotification() async {
    if (_currentTripPlan != null) {
      // 發送通知
      await _notificationService.showTripStartNotification(_currentTripPlan!.name);
      
      // 自動更新行程狀態為進行中（Status 2）
      await TripStatusManager.updateStatus(2, _currentTripPlan);
      
      print('行程時間已到，自動更新狀態為進行中: ${_currentTripPlan!.name}');
    }
  }
  
  // 取消計時器
  void cancelTripTimer() {
    _tripTimer?.cancel();
    _tripTimer = null;
    _currentTripPlan = null;
  }
  
  // 檢查是否有行程計時器正在運行
  bool isTimerActive() {
    return _tripTimer != null && _tripTimer!.isActive;
  }
}