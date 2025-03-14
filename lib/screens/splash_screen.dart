import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'map_screen.dart';

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
        _isLoading = false;
      });
      
      // 導航到地圖頁面
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MapScreen(initialPosition: position)),
          );
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ 無法獲取 GPS 位置：$e";
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