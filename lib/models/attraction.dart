import 'dart:math' as math;

class Attraction {
  String? id; // 添加id屬性
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String description;
  final String imageUrl;
  int stayDuration; // 停留時間（分鐘）

  Attraction({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.description,
    this.imageUrl = '',
    this.stayDuration = 60, // 預設停留時間為60分鐘
  });

  // 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'description': description,
      'imageUrl': imageUrl,
      'stayDuration': stayDuration,
    };
  }

  // 從 JSON 格式創建實例
  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['\$id'] ?? json['id'],
      name: json['name'] ?? json['Name'] ?? '',
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      address: json['address'] ?? json['Address'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      imageUrl: json['imageUrl'] ?? json['Picture'] ?? '',
      stayDuration: json['stayDuration'] ?? 60,
    );
  }

  // 在 Attraction 类中
  
  // 添加在类内部
  double distanceTo(Attraction other) {
    // 使用 Haversine 公式计算两点之间的距离
    const double earthRadius = 6371000; // 地球半径（米）
    
    // 将经纬度转换为弧度
    final lat1 = latitude * math.pi / 180;
    final lon1 = longitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final lon2 = other.longitude * math.pi / 180;
    
    // Haversine 公式
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a = math.sin(dLat/2) * math.sin(dLat/2) +
               math.cos(lat1) * math.cos(lat2) *
               math.sin(dLon/2) * math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    final distance = earthRadius * c;
    
    return distance; // 返回距离（米）
  }
}