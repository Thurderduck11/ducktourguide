import 'attraction.dart';

class AttractionVisit {
  final Attraction attraction;
  DateTime? arrivalTime;      // 到达时间
  DateTime? departureTime;    // 离开时间
  bool isVisited;             // 是否已访问
  
  AttractionVisit({
    required this.attraction,
    this.arrivalTime,
    this.departureTime,
    this.isVisited = false,
  });
  
  // 转换为 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'attraction': attraction.toJson(),
      'arrivalTime': arrivalTime?.toIso8601String(),
      'departureTime': departureTime?.toIso8601String(),
      'isVisited': isVisited,
    };
  }
  
  // 从 JSON 格式创建实例
  factory AttractionVisit.fromJson(Map<String, dynamic> json) {
    return AttractionVisit(
      attraction: Attraction.fromJson(json['attraction']),
      arrivalTime: json['arrivalTime'] != null ? DateTime.parse(json['arrivalTime']) : null,
      departureTime: json['departureTime'] != null ? DateTime.parse(json['departureTime']) : null,
      isVisited: json['isVisited'] ?? false,
    );
  }
}