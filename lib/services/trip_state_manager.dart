import 'dart:async';
import '../models/trip_plan.dart';
import '../models/attraction.dart';
import 'notification_service.dart';
import 'location_tracker.dart';
import 'user_data_service.dart'; // 添加這行

class TripStateManager {
  final TripPlan tripPlan;
  final NotificationService _notificationService = NotificationService();
  final LocationTracker _locationTracker = LocationTracker();
  
  Timer? _attractionTimer;
  Timer? _restTimer;
  StreamSubscription? _locationSubscription;
  
  int _currentAttractionIndex = -1;
  int _currentRestIndex = -1;
  bool _isRunning = false;
  
  TripStateManager({required this.tripPlan}) {
    // 确保访问记录已初始化
    if (tripPlan.visits.isEmpty && tripPlan.attractions.isNotEmpty) {
      tripPlan.initializeVisits();
    }
  }
  
  bool get isRunning => _isRunning;
  int get currentAttractionIndex => _currentAttractionIndex;
  int get currentRestIndex => _currentRestIndex;
  
  // 开始行程
  Future<void> startTrip() async {
    if (_isRunning) return;
    
    _isRunning = true;
    tripPlan.startTrip();
    
    // 发送行程开始通知
    await _notificationService.showTripStartNotification(tripPlan.name);
    
    // 开始位置追踪
    await _locationTracker.startTracking();
    
    // 监听位置变化，检查是否到达景点
    _locationSubscription = _locationTracker.locationStream.listen((_) {
      _checkAttractionProximity();
    });
  }
  
  // 结束行程
  Future<void> endTrip() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    tripPlan.endTrip();
    
    // 取消所有计时器和订阅
    _attractionTimer?.cancel();
    _restTimer?.cancel();
    _locationSubscription?.cancel();
    
    // 停止位置追踪
    _locationTracker.stopTracking();
    
    // 发送行程完成通知
    await _notificationService.showTripCompletedNotification(
      tripPlan.name,
      tripPlan.getProgress(),
    );
  }
  
  // 检查是否接近任何景点
  void _checkAttractionProximity() {
    if (!_isRunning) return;
    
    for (int i = 0; i < tripPlan.visits.length; i++) {
      final visit = tripPlan.visits[i];
      
      // 如果景点尚未访问且已接近
      if (!visit.isVisited && 
          _locationTracker.hasReachedAttraction(visit.attraction)) {
        _arriveAtAttraction(i);
        break;
      }
    }
  }
  
  // 到达景点
  // 修改到達景點方法
  Future<void> _arriveAtAttraction(int index) async {
    if (_currentAttractionIndex != -1 || index < 0 || index >= tripPlan.visits.length) return;
    
    _currentAttractionIndex = index;
    tripPlan.recordArrival(index);
    
    final attraction = tripPlan.visits[index].attraction;
    
    // 發送到達景點通知
    await _notificationService.showAttractionArrivalNotification(attraction.name);
    
    // 保存到雲端
    try {
      await UserDataService.saveTripPlan(tripPlan);
      print('已記錄到達景點並保存到雲端: ${attraction.name}');
    } catch (e) {
      print('保存景點到達記錄失敗: $e');
    }
    
    // 設置景點停留計時器
    _attractionTimer = Timer(Duration(minutes: attraction.stayDuration), () {
      _departFromAttraction(index);
    });
  }
  
  // 修改離開景點方法
  Future<void> _departFromAttraction(int index) async {
    if (_currentAttractionIndex != index) return;
    
    tripPlan.recordDeparture(index);
    _currentAttractionIndex = -1;
    
    final attraction = tripPlan.visits[index].attraction;
    String nextDestination = "行程结束";
    
    // 确定下一个目的地（景点或休息）
    int nextIndex = _getNextDestinationIndex(index);
    if (nextIndex != -1) {
      if (nextIndex < tripPlan.visits.length) {
        nextDestination = tripPlan.visits[nextIndex].attraction.name;
      } else if (nextIndex - tripPlan.visits.length < tripPlan.restStops.length) {
        int restIndex = nextIndex - tripPlan.visits.length;
        nextDestination = tripPlan.restStops[restIndex].name;
      }
    }
    
    // 发送离开景点通知
    await _notificationService.showAttractionDepartureNotification(
      attraction.name,
      nextDestination,
    );
    
    // 保存到雲端
    try {
      await UserDataService.saveTripPlan(tripPlan);
      print('已記錄離開景點並保存到雲端: ${attraction.name}');
    } catch (e) {
      print('保存景點離開記錄失敗: $e');
    }
    
    // 檢查是否所有景點都已訪問
    bool allVisited = tripPlan.visits.every((visit) => visit.isVisited);
    if (allVisited) {
      await endTrip();
    }
  }
  
  // 获取下一个目的地索引
  int _getNextDestinationIndex(int currentIndex) {
    // 简单实现：返回下一个景点索引
    if (currentIndex + 1 < tripPlan.visits.length) {
      return currentIndex + 1;
    }
    return -1;
  }
  
  // 开始休息
  Future<void> startRest(int restIndex) async {
    if (_currentRestIndex != -1 || restIndex < 0 || restIndex >= tripPlan.restStops.length) return;
    
    _currentRestIndex = restIndex;
    tripPlan.startRest(restIndex);
    
    final rest = tripPlan.restStops[restIndex];
    
    // 发送休息开始通知
    await _notificationService.showRestStartNotification(rest.name);
    
    // 设置休息计时器
    _restTimer = Timer(Duration(minutes: rest.durationMinutes), () {
      endRest(restIndex);
    });
  }
  
  // 结束休息
  Future<void> endRest(int restIndex) async {
    if (_currentRestIndex != restIndex) return;
    
    tripPlan.endRest(restIndex);
    _currentRestIndex = -1;
    
    final rest = tripPlan.restStops[restIndex];
    
    // 发送休息结束通知
    await _notificationService.showRestEndNotification(rest.name);
  }
  
  // 手动记录到达景点
  Future<void> manualArriveAtAttraction(int index) async {
    await _arriveAtAttraction(index);
  }
  
  // 手动记录离开景点
  Future<void> manualDepartFromAttraction(int index) async {
    if (_currentAttractionIndex == index) {
      _attractionTimer?.cancel();
      await _departFromAttraction(index);
    }
  }
  
  // 手动开始休息
  Future<void> manualStartRest(int restIndex) async {
    await startRest(restIndex);
  }
  
  // 手动结束休息
  Future<void> manualEndRest(int restIndex) async {
    if (_currentRestIndex == restIndex) {
      _restTimer?.cancel();
      await endRest(restIndex);
    }
  }
  
  // 释放资源
  void dispose() {
    _attractionTimer?.cancel();
    _restTimer?.cancel();
    _locationSubscription?.cancel();
    _locationTracker.stopTracking();
  }
}