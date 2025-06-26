import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import 'map_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = "正在初始化...";
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 檢查位置服務
      setState(() => _statusMessage = "檢查 GPS 服務狀態...");
      bool serviceEnabled = await LocationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = "⚠️ GPS 服務未開啟！請檢查裝置的 GPS 設定。";
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // 檢查權限
      setState(() => _statusMessage = "GPS 服務已開啟，檢查權限中...");
      LocationPermission permission = await LocationService.checkAndRequestPermission();
      
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = "❌ GPS 權限被拒絕！請手動允許位置權限。";
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage = "🚫 GPS 權限永久被拒！請到設定中手動允許位置存取。";
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // 獲取位置
      setState(() => _statusMessage = "✅ 權限已獲得，嘗試獲取 GPS 位置...");
      Position position = await LocationService.getCurrentPosition();
      
      setState(() {
        _statusMessage = "🎯 GPS 成功！\n緯度: ${position.latitude}, 經度: ${position.longitude}";
      });
      
      // 檢查用戶是否已登入
      setState(() => _statusMessage = "檢查登入狀態...");
      bool isLoggedIn = false;
      try {
        final user = await AuthService.getCurrentUser();
        isLoggedIn = user != null;
        if (isLoggedIn) {
          print('用戶已登入，ID: ${user.$id}');
        }
      } catch (e) {
        print('檢查登入狀態時出錯: $e');
        // 如果出錯，假設用戶未登入
        isLoggedIn = false;
      }
      
      setState(() {
        _statusMessage = isLoggedIn ? "已登入，正在進入應用..." : "未登入，請先登入...";
        _isLoading = false;
      });
      
      // 導航到適當的頁面
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => isLoggedIn
                  ? MapScreen(initialPosition: position)
                  : LoginScreen(initialPosition: position),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ 初始化失敗：$e";
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Duck Tour Guide",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                if (_isLoading) const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _hasError ? Colors.red : Colors.black87,
                  ),
                ),
                if (_hasError) ...[  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });
                      _initializeApp();
                    },
                    child: const Text("重試"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}