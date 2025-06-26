import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip_plan.dart';
import '../models/attraction.dart';
import '../models/attraction_visit.dart'; 

class AttractionPreviewScreen extends StatefulWidget {
  final TripPlan tripPlan;

  const AttractionPreviewScreen({
    Key? key,
    required this.tripPlan,
  }) : super(key: key);

  @override
  State<AttractionPreviewScreen> createState() => _AttractionPreviewScreenState();
}

class _AttractionPreviewScreenState extends State<AttractionPreviewScreen> {
  late MapController _mapController;
  LatLng? _centerPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _calculateMapCenter();
  }

  void _calculateMapCenter() {
    if (widget.tripPlan.attractions.isEmpty) return;

    // 計算所有景點的平均位置作為地圖中心
    double sumLat = 0;
    double sumLng = 0;

    for (var attraction in widget.tripPlan.attractions) {
      sumLat += attraction.latitude;
      sumLng += attraction.longitude;
    }

    _centerPosition = LatLng(
      sumLat / widget.tripPlan.attractions.length,
      sumLng / widget.tripPlan.attractions.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripPlan.name} - 景點預覽'),
      ),
      body: Column(
        children: [
          // 地圖區域
          Expanded(
            flex: 3,
            child: _buildMap(),
          ),
          // 景點列表
          Expanded(
            flex: 2,
            child: _buildAttractionsList(),
          ),
        ],
      ),
    );
  }

  // 修改 _buildMap 方法（約在第70行）
  Widget _buildMap() {
    if (_centerPosition == null || widget.tripPlan.attractions.isEmpty) {
      return const Center(child: Text('沒有景點可顯示'));
    }
  
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _centerPosition!,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        // 添加路徑線
        PolylineLayer(
          polylines: _buildRouteLines(),
        ),
        MarkerLayer(
          markers: _buildMarkers(),
        ),
        // 添加休息時間標記層
        MarkerLayer(
          markers: _buildRestMarkers(),
        ),
      ],
    );
  }

  // 添加構建路徑線的方法
  List<Polyline> _buildRouteLines() {
    List<Polyline> lines = [];
  
    // 如果少於2個景點，不顯示路徑
    if (widget.tripPlan.attractions.length < 2) return lines;
  
    // 為每對相鄰景點創建一條線
    for (int i = 0; i < widget.tripPlan.attractions.length - 1; i++) {
      final attraction1 = widget.tripPlan.attractions[i];
      final attraction2 = widget.tripPlan.attractions[i + 1];
    
      // 檢查是否有休息時間（修改為雙向檢查）
      bool hasRest = widget.tripPlan.restStops.any((rest) => 
        (rest.fromAttractionId == attraction1.id && rest.toAttractionId == attraction2.id) ||
        (rest.fromAttractionId == attraction2.id && rest.toAttractionId == attraction1.id));
    
      lines.add(
        Polyline(
          points: [
            LatLng(attraction1.latitude, attraction1.longitude),
            LatLng(attraction2.latitude, attraction2.longitude),
          ],
          strokeWidth: 4.0,
          color: hasRest ? Colors.orange : Colors.blue, // 如果有休息時間，使用橙色線
        ),
      );
    }
  
    return lines;
  }

  List<Marker> _buildMarkers() {
    return widget.tripPlan.attractions.asMap().entries.map((entry) {
      final index = entry.key;
      final attraction = entry.value;
      return Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(attraction.latitude, attraction.longitude),
        child: GestureDetector(
          onTap: () {
            _showAttractionDetails(attraction);
          },
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // 在 _buildMarkers() 方法後添加新方法
  List<Marker> _buildRestMarkers() {
    List<Marker> markers = [];
  
    // 遍歷所有景點對，檢查是否有休息時間
    for (int i = 0; i < widget.tripPlan.attractions.length - 1; i++) {
      final attraction1 = widget.tripPlan.attractions[i];
      final attraction2 = widget.tripPlan.attractions[i + 1];
    
      // 查找休息時間
      for (var rest in widget.tripPlan.restStops) {
        if ((rest.fromAttractionId == attraction1.id && rest.toAttractionId == attraction2.id) ||
            (rest.fromAttractionId == attraction2.id && rest.toAttractionId == attraction1.id)) {
          // 計算兩個景點之間的中點位置
          final midLat = (attraction1.latitude + attraction2.latitude) / 2;
          final midLng = (attraction1.longitude + attraction2.longitude) / 2;
        
          // 添加休息時間標記
          markers.add(
            Marker(
              width: 120.0,
              height: 70.0,
              point: LatLng(midLat, midLng),
              child: GestureDetector(
                onTap: () {
                  // 顯示休息時間詳情
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${rest.name}: ${rest.durationMinutes} 分鐘'))
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rest.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${rest.durationMinutes} 分鐘',
                        style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          break;
        }
      }
    }
  
    return markers;
  }
  // 修改 _buildAttractionsList 方法（約在第130行）
  Widget _buildAttractionsList() {
    if (widget.tripPlan.attractions.isEmpty) {
      return const Center(child: Text('尚未添加任何景點'));
    }
  
    return ListView.builder(
      itemCount: widget.tripPlan.attractions.length * 2 - 1, // 增加項目數量，為了在景點之間顯示距離和休息時間
      itemBuilder: (context, index) {
      // 如果是偶數索引，顯示景點
      if (index % 2 == 0) {
        final attractionIndex = index ~/ 2;
        final attraction = widget.tripPlan.attractions[attractionIndex];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text('${attractionIndex + 1}'),
            ),
            title: Text(attraction.name),
            subtitle: Text('停留時間: ${attraction.stayDuration} 分鐘'),
            onTap: () {
              // 點擊時將地圖中心移動到該景點
              _mapController.move(
                LatLng(attraction.latitude, attraction.longitude),
                15.0,
              );
              _showAttractionDetails(attraction);
            },
          ),
        );
      } 
      // 如果是奇數索引，顯示距離和休息時間
      else {
        final prevAttractionIndex = index ~/ 2;
        final nextAttractionIndex = prevAttractionIndex + 1;
        
        // 確保下一個景點存在
        if (nextAttractionIndex < widget.tripPlan.attractions.length) {
          final prevAttraction = widget.tripPlan.attractions[prevAttractionIndex];
          final nextAttraction = widget.tripPlan.attractions[nextAttractionIndex];
          
          // 計算距離
          final distance = prevAttraction.distanceTo(nextAttraction);
          String distanceText = '';
          
          if (distance >= 1000) {
            distanceText = '距離: ${(distance / 1000).toStringAsFixed(1)} 公里';
          } else {
            distanceText = '距離: ${distance.toStringAsFixed(0)} 米';
          }
          
          // 查找休息時間
          String restText = ''; // 初始化 restText 變量
          for (var rest in widget.tripPlan.restStops) {
            if ((rest.fromAttractionId == prevAttraction.id && 
                 rest.toAttractionId == nextAttraction.id) ||
                (rest.fromAttractionId == nextAttraction.id && 
                 rest.toAttractionId == prevAttraction.id)) {
              restText = '休息: ${rest.name} (${rest.durationMinutes} 分鐘)';
              break;
            }
          }
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const SizedBox(width: 40), // 與景點圖標對齊
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(distanceText, style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                        ],
                      ),
                      if (restText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0, top: 4.0),
                          child: Text(restText, style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      }
    },
  );
}

  void _showAttractionDetails(Attraction attraction) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attraction.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('地址: ${attraction.address}'),
            const SizedBox(height: 8),
            Text('停留時間: ${attraction.stayDuration} 分鐘'),
            const SizedBox(height: 8),
            Text('描述: ${attraction.description}'),
          ],
        ),
      ),
    );
  }
}
