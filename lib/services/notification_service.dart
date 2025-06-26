import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {},
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {},
    );
  }

  Future<void> createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'duck_tour_guide_channel', // 必须与后台服务使用的 ID 一致
      'Duck Tour Guide Notifications',
      description: '用於行程狀態和位置更新',
      importance: Importance.high,
    );

    await _notificationsPlugin
         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
         ?.createNotificationChannel(channel);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'duck_tour_guide_channel',
      'Duck Tour Guide Notifications',
      channelDescription: 'Notifications for Duck Tour Guide app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // 行程开始通知
  Future<void> showTripStartNotification(String tripName) async {
    await showNotification(
      id: 1,
      title: '行程开始',
      body: '"$tripName" 行程已开始，祝您旅途愉快！',
    );
  }

  // 景点到达通知
  Future<void> showAttractionArrivalNotification(String attractionName) async {
    await showNotification(
      id: 2,
      title: '已到達景點',
      body: '您已到達 "$attractionName"，開始參觀景點。',
    );
  }

  // 景点停留时间结束通知
  Future<void> showAttractionDepartureNotification(String attractionName, String nextAttractionName) async {
    await showNotification(
      id: 3,
      title: '景點停留時間結束',
      body: '"$attractionName" 的景點停留時間結束，下一站：$nextAttractionName',
    );
  }

  // 休息时间开始通知
  Future<void> showRestStartNotification(String restName) async {
    await showNotification(
      id: 4,
      title: '休息時間開始',
      body: '"$restName" 休息時間開始。',
    );
  }

  // 休息时间结束通知
  Future<void> showRestEndNotification(String restName) async {
    await showNotification(
      id: 5,
      title: '休息時間結束',
      body: '"$restName" 休息時間已結束。',
    );
  }

  // 行程完成通知
  Future<void> showTripCompletedNotification(String tripName, double progress) async {
    await showNotification(
      id: 6,
      title: '行程完成',
      body: '"$tripName" 行程已完成！您完成了 ${progress.toStringAsFixed(0)}% 的景點。',
    );
  }
}