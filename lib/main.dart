import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/trip_planning_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/background_service.dart';

// 定義全局 navigatorKey，用於在非 Widget 類中獲取 context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 在 main 函數中添加
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化背景服務
  await BackgroundService.initializeService();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duck Tour Guide',
      navigatorKey: navigatorKey, // 添加全局 navigatorKey
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      // 添加路由配置
      routes: {
        '/trip_planning': (context) => const TripPlanningScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        // 之後可以在這裡添加更多路由
      },
    );
  }
}
