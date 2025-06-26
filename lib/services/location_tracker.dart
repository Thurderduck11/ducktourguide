import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/attraction.dart';

class LocationTracker {
  static final LocationTracker _instance = LocationTracker._internal();
  factory LocationTracker() => _instance;
  LocationTracker._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  final _locationController = StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationController.stream;
  Position? get currentPosition => _currentPosition;

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 检查位置服务是否启用
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 检查位置权限
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    print('開始位置追蹤...');
    final hasPermission = await _handlePermission();
    
    if (!hasPermission) {
      print('無法啟動位置追蹤：權限不足');
      return;
    }
    
    // 如果已經在追蹤中，先停止
    if (_positionStreamSubscription != null) {
      print('已有位置追蹤在運行，重新啟動...');
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    
    // 先獲取當前位置
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      print('初始位置獲取成功: 緯度=${_currentPosition!.latitude}, 經度=${_currentPosition!.longitude}');
      _locationController.add(_currentPosition!);
    } catch (e) {
      print('獲取初始位置失敗: $e');
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _locationController.add(position);
        print('位置更新: 緯度=${position.latitude}, 經度=${position.longitude}');
      },
      onError: (error) {
        print('位置追蹤錯誤: $error');
      },
    );
    
    print('位置追蹤已啟動');
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }

  // 计算当前位置与景点的距离（米）
  double calculateDistance(Attraction attraction) {
    if (_currentPosition == null) {
      print('無法計算距離：當前位置未知');
      return double.infinity;
    }
    
    print('當前位置: 緯度=${_currentPosition!.latitude}, 經度=${_currentPosition!.longitude}');
    print('景點位置: 緯度=${attraction.latitude}, 經度=${attraction.longitude}');
    
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      attraction.latitude,
      attraction.longitude,
    );
    
    return distance;
  }

  // 检查是否已到达景点（距离小于50米）
  bool hasReachedAttraction(Attraction attraction, {double threshold = 50.0}) {
    double distance = calculateDistance(attraction);
    bool reached = distance <= threshold;
    print('檢查是否抵達景點: ${attraction.name}, 距離: $distance 米, 閾值: $threshold 米, 結果: $reached');
    return reached;
  }
}