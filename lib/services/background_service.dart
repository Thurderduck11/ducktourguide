import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import '../models/trip_plan.dart';
import 'trip_status_manager.dart';
import 'trip_timer_service.dart';
import 'notification_service.dart';
import 'location_tracker.dart';
import 'user_data_service.dart';

@pragma('vm:entry-point')
class BackgroundService {
  @pragma('vm:entry-point')
  BackgroundService();
  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    // 确保通知通道在服务配置前就已经创建和初始化
    final notificationService = NotificationService();
    await notificationService.createNotificationChannel();
    await notificationService.initialize();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'duck_tour_guide_channel',
        initialNotificationTitle: '鴨導遊服務',
        initialNotificationContent: '行程監控中...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    service.startService();
  }
  
  // iOS後台處理
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }
  
  // 服務啟動時執行
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // 通知服务已在 initializeService 中初始化
    final notificationService = NotificationService();
    if (service is AndroidServiceInstance) {

      service.setAsForegroundService();
    }

    // 示例：每隔一段时间打印日志
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      print('Background service running: ${DateTime.now()}');
    });

    // 創建一個共用的位置追蹤器實例
    final locationTracker = LocationTracker();
    
    // 定期檢查行程狀態（每分鐘）
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        // 刷新行程狀態，確保狀態與當前時間匹配
        // 注意：refreshTripStatus 方法內部已經調用了 TripStatusManager.initialize()
        await refreshTripStatus();
        
        // 如果有當前行程且狀態為預備中，檢查是否需要啟動
        if (TripStatusManager.currentTrip != null && 
            TripStatusManager.status == 1) {
          final tripPlan = TripStatusManager.currentTrip!;
          final now = DateTime.now();
          
          // 如果當前時間已經超過或等於行程開始時間，自動更新狀態
          if (now.isAfter(tripPlan.startTime) || now.isAtSameMomentAs(tripPlan.startTime)) {
            await TripStatusManager.updateStatus(2, tripPlan);
            await notificationService.showTripStartNotification(tripPlan.name);
            print('背景服務：行程時間已到，自動更新狀態為進行中: ${tripPlan.name}');
          }
        }
      
        // 檢查是否有進行中的行程，如果有，檢查是否接近任何景點
        if (TripStatusManager.currentTrip != null && 
            TripStatusManager.status == 2) {
          final tripPlan = TripStatusManager.currentTrip!;
          
          // 啟動位置追蹤
          await locationTracker.startTracking();
          
          // 檢查是否接近任何景點
          print('背景服務：開始檢查是否接近任何景點，共有 ${tripPlan.visits.length} 個景點');
          bool foundAttraction = false;
          
          for (int i = 0; i < tripPlan.visits.length; i++) {
            final visit = tripPlan.visits[i];
            
            print('背景服務：檢查景點 ${visit.attraction.name}，是否已訪問: ${visit.isVisited}');
            
            // 如果景點尚未訪問
            if (!visit.isVisited) {
              print('背景服務：景點 ${visit.attraction.name} 尚未訪問，檢查是否已接近');
              bool reached = locationTracker.hasReachedAttraction(visit.attraction);
              
              if (reached) {
                print('背景服務：已抵達景點 ${visit.attraction.name}！');
                // 記錄到達時間
                tripPlan.recordArrival(i);
                
                // 發送到達景點通知
                await notificationService.showAttractionArrivalNotification(visit.attraction.name);
                
                // 保存到雲端
                try {
                  await UserDataService.saveTripPlan(tripPlan);
                  print('背景服務：已記錄到達景點並保存到雲端: ${visit.attraction.name}');
                } catch (e) {
                  print('背景服務：保存景點到達記錄失敗: $e');
                }
                
                // 設置景點停留計時器 - 使用本地變數捕獲當前值，避免閉包問題
                final int currentIndex = i;
                final String attractionName = visit.attraction.name;
                final int stayDuration = visit.attraction.stayDuration;
                
                Timer(Duration(minutes: stayDuration), () async {
                  try {
                    // 重新獲取最新的行程計劃，以防在等待期間有變化
                    await TripStatusManager.initialize();
                    if (TripStatusManager.currentTrip != null) {
                      final updatedTripPlan = TripStatusManager.currentTrip!;
                      
                      // 記錄離開時間
                      updatedTripPlan.recordDeparture(currentIndex);
                      
                      // 發送離開景點通知
                      String nextDestination = "行程結束";
                      if (currentIndex + 1 < updatedTripPlan.visits.length) {
                        nextDestination = updatedTripPlan.visits[currentIndex + 1].attraction.name;
                      }
                      await notificationService.showAttractionDepartureNotification(
                        attractionName,
                        nextDestination,
                      );
                      
                      // 保存到雲端
                      await UserDataService.saveTripPlan(updatedTripPlan);
                      print('背景服務：已記錄離開景點並保存到雲端: $attractionName');
                    }
                  } catch (e) {
                    print('背景服務：處理景點離開時發生錯誤: $e');
                  }
                });
                
                foundAttraction = true;
                break; // 找到一個景點後就跳出循環
              } else {
                print('背景服務：尚未抵達景點 ${visit.attraction.name}');
              }
            }
          }
          
          if (!foundAttraction) {
            print('背景服務：未找到任何接近的未訪問景點');
          }
        } else {
          // 如果沒有進行中的行程，停止位置追蹤以節省電池
          locationTracker.stopTracking();
        }
      } catch (e) {
        print('背景服務：處理行程狀態時發生錯誤: $e');
      }
    });
  }
  
  /// 刷新行程狀態，確保狀態與當前時間匹配
  static Future<void> refreshTripStatus() async {
    try {
      // 重新初始化行程狀態管理器，確保獲取最新數據
      await TripStatusManager.initialize();
      
      // 如果沒有當前行程，則不需要刷新狀態
      if (TripStatusManager.currentTrip == null) {
        return;
      }
      
      final tripPlan = TripStatusManager.currentTrip!;
      final now = DateTime.now();
      
      // 檢查行程狀態是否與當前時間匹配
      if (tripPlan.status == TripStatus.preparation) {
        // 如果行程處於預備狀態，但當前時間已經超過開始時間，則更新為進行中
        if (now.isAfter(tripPlan.startTime)) {
          print('刷新行程狀態：行程時間已到，更新狀態為進行中');
          await TripStatusManager.updateStatus(2, tripPlan);
        }
      } else if (tripPlan.status == TripStatus.inProgress) {
        // 如果行程處於進行中狀態，但當前時間已經超過結束時間，則更新為已完成
        if (now.isAfter(tripPlan.endTime)) {
          print('刷新行程狀態：行程時間已結束，更新狀態為已完成');
          await TripStatusManager.updateStatus(3, tripPlan);
        }
      } else if (tripPlan.status == TripStatus.notStarted) {
        // 如果行程處於未開始狀態，但已經設置了開始時間和結束時間，則更新為預備狀態
        if (tripPlan.startTime != null && tripPlan.endTime != null) {
          // 如果開始時間接近當前時間（例如在24小時內），則更新為預備狀態
          final timeUntilStart = tripPlan.startTime.difference(now).inHours;
          if (timeUntilStart <= 24) {
            print('刷新行程狀態：行程即將開始（${timeUntilStart}小時後），更新狀態為預備狀態');
            await TripStatusManager.updateStatus(1, tripPlan);
          }
        }
      }
    } catch (e) {
      print('刷新行程狀態時發生錯誤: $e');
    }
  }
}