import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';
import '../services/attraction_service.dart';
import '../utils/marker_manager.dart';
import '../utils/upload_attraction.dart';
import '../config/database.dart';
import '../widgets/circular_menu.dart';
import '../services/auth_service.dart';
import '../services/trip_status_manager.dart'; // 添加這行導入
import '../services/user_data_service.dart'; // 添加這行導入

class MapScreen extends StatefulWidget {
  final Position initialPosition;
  
  const MapScreen({super.key, required this.initialPosition});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late LatLng _currentLocation;
  double _currentZoom = 15.0;
  StreamSubscription<Position>? _positionStream;
  String _currentAddress = "正在獲取地址...";
  final MarkerManager _markerManager = MarkerManager();
  final AttractionService _attractionService = AttractionService();
  List<Map<String, dynamic>> _markersData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isMapCentered = true; // 新增：追蹤地圖是否置中
  final GlobalKey<CircularMenuState> _menuKey = GlobalKey(); // 新增：用於訪問 CircularMenu 狀態
  Timer? _statusCheckTimer; // 添加定時器變量
  

  
  @override
  void initState() {
    super.initState();
    _initializeMap();
    // 新增：監聽地圖移動
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        _checkMapCenterStatus();
      }
    });
    
    // 添加定時器，每分鐘檢查一次行程狀態更新
    _statusCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkTripStatusUpdate();
    });
  }
  
  // 添加檢查行程狀態更新的方法
  Future<void> _checkTripStatusUpdate() async {
    try {
      // 重新初始化 TripStatusManager
      await TripStatusManager.initialize();
      
      // 重新獲取行程數據
      await _fetchMarkersData();
      
      if (mounted) {
        setState(() {});
      }
      
      print('地圖畫面：行程狀態已更新，當前狀態: ${TripStatusManager.status}');
    } catch (e) {
      print('地圖畫面：檢查行程狀態更新失敗: $e');
    }
  }

  Future<void> _initializeMap() async {
    try {
      // 使用初始位置設置當前位置
      _currentLocation = LatLng(
        widget.initialPosition.latitude, 
        widget.initialPosition.longitude
      );
      
      // 獲取當前地址
      _currentAddress = await _getAddressFromLatLng(widget.initialPosition);
      
      // 獲取景點數據
      await _fetchMarkersData();
      
      // 開始位置更新
      _startLocationUpdates();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "初始化地圖時發生錯誤: $e";
        _isLoading = false;
      });
      print(_errorMessage);
    }
  }

  // 新增：檢查地圖中心點是否與當前位置一致
  void _checkMapCenterStatus() {
    if (!mounted) return;
    
    final mapCenter = _mapController.camera.center;
    final distance = Geolocator.distanceBetween(
      mapCenter.latitude,
      mapCenter.longitude,
      _currentLocation.latitude,
      _currentLocation.longitude,
    );

    final bool isCentered = distance < 10; // 10米內視為置中
    setState(() {
      _isMapCentered = isCentered;
    });
    
    // 更新 CircularMenu 的狀態
    _menuKey.currentState?.setMapCentered(isCentered);
  }

  // 修改：定位當前位置功能
  Future<void> _locateCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _mapController.move(_currentLocation, _currentZoom);
        _isMapCentered = true;
      });
      
      // 更新 CircularMenu 的狀態
      _menuKey.currentState?.setMapCentered(true);
      
    } catch (e) {
      print("獲取當前位置失敗: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    _statusCheckTimer?.cancel(); // 取消定時器
    super.dispose();
  }

  void _startLocationUpdates() {
    var locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen(
        _handlePositionUpdate,
        onError: (error) {
          print("GPS 錯誤: $error");
          setState(() {
            _errorMessage = "GPS 錯誤: $error";
          });
        },
      );
  }

  Future<void> _handlePositionUpdate(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);
    
    // 只有當位置變化超過一定距離時才更新地圖
    if (_shouldUpdateMap(newLocation)) {
      setState(() {
        _currentLocation = newLocation;
        _mapController.move(_currentLocation, _currentZoom);
      });
    } else {
      setState(() {
        _currentLocation = newLocation;
      });
    }
    
    // 更新地址（使用節流，不是每次都更新）
    if (_shouldUpdateAddress()) {
      _currentAddress = await _getAddressFromLatLng(position);
      setState(() {});
    }
    
    // 檢查附近景點
    _checkNearbyAttractions();
  }

  bool _shouldUpdateMap(LatLng newLocation) {
    // 計算與上次更新位置的距離，如果超過20米才更新地圖視圖
    final distance = Geolocator.distanceBetween(
      _currentLocation.latitude, _currentLocation.longitude,
      newLocation.latitude, newLocation.longitude,
    );
    return distance > 20;
  }

  bool _shouldUpdateAddress() {
    // 使用簡單的節流機制，可以根據需要調整
    return DateTime.now().second % 10 == 0; // 每10秒更新一次地址
  }

  Future<String> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return "${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}";
      }
    } catch (e) {
      print("獲取地址錯誤: $e");
    }
    return "無法獲取地址";
  }

  Future<void> _fetchMarkersData() async {
    try {
      final attractions = await _attractionService.fetchAttractions();
      setState(() {
        _markersData = attractions.map((attraction) {
          return {
            'point': LatLng(attraction.latitude, attraction.longitude),
            'title': attraction.name,
            'address': attraction.address,
            'description': attraction.description,
            'imageUrl': attraction.imageUrl,
            'color': Colors.red,
            'visited': _markerManager.visitedAttractions.contains(attraction.name),
          };
        }).toList();
      });
    } catch (e) {
      print("獲取景點數據失敗: $e");
      setState(() {
        _errorMessage = "獲取景點數據失敗: $e";
      });
    }
  }

  Future<void> _checkNearbyAttractions() async {
    try {
      double userLat = _currentLocation.latitude;
      double userLng = _currentLocation.longitude;
  
      bool foundAttraction = false;
      
      print("地圖畫面：開始檢查附近景點，當前位置：緯度=$userLat, 經度=$userLng");
  
      // 檢查是否有進行中的行程
      if (TripStatusManager.status == 2 && TripStatusManager.currentTrip != null) {
        final tripPlan = TripStatusManager.currentTrip!;
        print("地圖畫面：檢查行程 ${tripPlan.name} 中的景點");
        
        // 先檢查行程中的景點
        for (int i = 0; i < tripPlan.visits.length; i++) {
          final visit = tripPlan.visits[i];
          
          if (!visit.isVisited) {
            double distance = Geolocator.distanceBetween(
              userLat, userLng, visit.attraction.latitude, visit.attraction.longitude,
            );
            
            print("地圖畫面：檢查行程景點 ${visit.attraction.name}，距離：$distance 公尺");
            
            if (distance <= 50) {
              print("地圖畫面：抵達行程景點： ${visit.attraction.name} ($distance 公尺)");
              
              // 播放景點描述
              await _markerManager.playAudioDescription(visit.attraction.name, visit.attraction.description);
              
              // 記錄到行程中
              tripPlan.recordArrival(i);
              
              // 保存到雲端
              try {
                await UserDataService.saveTripPlan(tripPlan);
                print("地圖畫面：已記錄到達景點並保存到雲端: ${visit.attraction.name}");
              } catch (e) {
                print("地圖畫面：保存景點到達記錄失敗: $e");
              }
              
              // 更新UI
              setState(() {
                _markersData = _markersData.map((data) {
                  if (data['title'] == visit.attraction.name) {
                    data['visited'] = true;
                  }
                  return data;
                }).toList();
              });
              
              // 顯示通知
              _showAttractionNotification(visit.attraction.name);
              
              foundAttraction = true;
              break;
            }
          }
        }
      }
      
      // 如果沒有在行程中找到景點，檢查所有標記點
      if (!foundAttraction) {
        print("地圖畫面：在行程中未找到景點，檢查所有標記點");
        
        for (var data in _markersData) {
          double attractionLat = data['point'].latitude;
          double attractionLng = data['point'].longitude;
          String attractionName = data['title'];
          String description = data['description'];
      
          double distance = Geolocator.distanceBetween(
            userLat, userLng, attractionLat, attractionLng,
          );
      
          print("地圖畫面：檢查標記點 $attractionName，距離：$distance 公尺");
          
          // 使用配置的距離閾值
          if (distance <= 50 && !_markerManager.visitedAttractions.contains(attractionName)) {
            print("地圖畫面：接近景點： $attractionName ($distance 公尺)");
            await _markerManager.playAudioDescription(attractionName, description);
            _markerManager.visitedAttractions.add(attractionName);
            foundAttraction = true;
      
            setState(() {
              _markersData = _markersData.map((data) {
                if (data['title'] == attractionName) {
                  data['visited'] = true;
                }
                return data;
              }).toList();
            });
      
            // 顯示通知
            _showAttractionNotification(attractionName);
      
            break;
          }
        }
      }
      
      if (!foundAttraction) {
        print("地圖畫面：未找到附近景點");
      }
    } catch (e) {
      print("檢查附近景點時發生錯誤: $e");
    }
  }

  void _showAttractionNotification(String attractionName) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 50, // 移動到中間往上50的位置
        right: MediaQuery.of(context).size.width / 2 - 100, // 水平居中
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              "發現景點：$attractionName",
              style: const TextStyle(color: Colors.white, fontSize: 18), // 調整字體大小
            ),
          ),
        ),
      ),
    );
  
    overlay?.insert(overlayEntry);
  
    // 自動移除通知，延遲時間拉長到五秒
    Future.delayed(const Duration(seconds: 5), () {
      overlayEntry.remove();
    });
  }

  void _scheduleDailyReset() {
    final now = DateTime.now();
    var nextReset = DateTime(now.year, now.month, now.day, 5);

    if (now.isAfter(nextReset)) {
      nextReset = nextReset.add(const Duration(days: 1));
    }

    final durationUntilReset = nextReset.difference(now);

    Timer(durationUntilReset, () {
      _markerManager.visitedAttractions.clear();
      setState(() {
        _markersData = _markersData.map((data) {
          data['visited'] = false;
          return data;
        }).toList();
      });
      print("已重置已訪問景點列表。");
      _scheduleDailyReset();
    });
  }

  void _showLocationInfo(String title, String address, String description, String imageUrl, Color color) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 確保置左對齊
            children: [
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 150,
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                      IconButton(
                        icon: Icon(Icons.volume_up, color: color, size: 50.0),
                        onPressed: () {
                          _markerManager.playAudioDescription(title, description);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(address, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text("簡介", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // 粗體字簡介
              
              // 將描述文本放入可滾動容器中
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    description, 
                    style: const TextStyle(fontSize: 16)
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("錯誤")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _initializeMap();
                },
                child: const Text("重試"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // 在 AppBar 的 actions 中修改登出按鈕
      appBar: AppBar(
        title: const Text("景點地圖"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 使用確認對話框
              if (await AuthService.showLogoutConfirmation(context)) {
                try {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('登出失敗：${e.toString()}')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地圖部分
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: _currentZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        _markerManager.createMarker({
                          'point': _currentLocation,
                          'title': "目前位置",
                          'address': _currentAddress,
                          'description': "這是你目前的位置。",
                          'imageUrl': "",
                          'color': Colors.blue,
                          'visited': false,
                        }, _showLocationInfo),
                        ..._markersData.map((data) => 
                          _markerManager.createMarker(data, _showLocationInfo)
                        ).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // 指定 Excel 文件和圖片目錄的路徑
                          String excelPath = 'assets/data/attractions.xlsx';
                          String imagesPath = 'assets/img/attractions';
                          
                          // 調用上傳函數
                          await processExcelAndUpload(excelPath, imagesPath);
                          
                          // 上傳成功後重新載入景點
                          setState(() {
                            _isLoading = true;
                          });
                          await _fetchMarkersData();
                          setState(() {
                            _isLoading = false;
                          });
                          
                          // 顯示成功訊息
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('景點上傳成功！')),
                          );
                        } catch (e) {
                          // 顯示錯誤訊息
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('上傳失敗：${e.toString()}')),
                          );
                        }
                      },
                      child: const Text("測試上傳景點"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 確保 CircularMenu 在最上層
          Positioned(
            right: 20,
            bottom: 120,
            child: CircularMenu(
              key: _menuKey,
              onReloadMarkers: () async {
                print("地圖頁面：開始重新加載景點");
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _fetchMarkersData();
                  print("地圖頁面：景點加載完成");
                } catch (e) {
                  print("地圖頁面：景點加載失敗 $e");
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onLocateCurrentPosition: _locateCurrentPosition, // 添加定位回調
            ),
          ),
        ],
      ),
    );
  }
}
