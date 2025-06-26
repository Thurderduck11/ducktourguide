import 'attraction.dart';
import 'attraction_visit.dart'; // 添加这一行
import 'dart:convert'; 

enum TripStatus {
  notStarted,  // 尚未開始
  preparation,
  inProgress,  // 進行中
  completed    // 已完成
}

// 删除 AttractionVisit 类的定义

class RestStop {
  final String name;
  final int durationMinutes;
  final String fromAttractionId;  // 起始景點 ID
  final String toAttractionId;    // 目標景點 ID
  DateTime? startTime;
  DateTime? endTime;
  bool isCompleted;
  
  RestStop({
    required this.name,
    required this.durationMinutes,
    required this.fromAttractionId,
    required this.toAttractionId,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
  });
  
  // 转换为 JSON 格式
  // 确保 RestStop 类的 toJson 和 fromJson 方法正确处理所有字段
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'durationMinutes': durationMinutes,
      'fromAttractionId': fromAttractionId,
      'toAttractionId': toAttractionId,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
  
  factory RestStop.fromJson(Map<String, dynamic> json) {
    return RestStop(
      name: json['name'] ?? '休息',
      durationMinutes: json['durationMinutes'] ?? 30,
      fromAttractionId: json['fromAttractionId'] ?? '',
      toAttractionId: json['toAttractionId'] ?? '',
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class TripPlan {
  String? id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  List<Attraction> attractions;
  List<AttractionVisit> visits = [];
  List<RestStop> restStops = [];
  TripStatus status;
  DateTime? actualStartTime;
  DateTime? actualEndTime;
  
  TripPlan({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    List<Attraction>? attractions,
    List<AttractionVisit>? visits,
    List<RestStop>? restStops,
    this.status = TripStatus.notStarted,
    this.actualStartTime,
    this.actualEndTime,
  }) :
    attractions = attractions ?? [],
    visits = visits ?? [],
    restStops = restStops ?? [];
  
  // 初始化訪問記錄
  void initializeVisits() {
    visits = attractions.map((attraction) => AttractionVisit(attraction: attraction)).toList();
  }
  
  // 開始行程
  void startTrip() {
    status = TripStatus.inProgress;
    actualStartTime = DateTime.now();
  }
  
  // 結束行程
  void endTrip() {
    status = TripStatus.completed;
    actualEndTime = DateTime.now();
  }
  
  // 記錄景點到達
  void recordArrival(int attractionIndex) {
    if (attractionIndex >= 0 && attractionIndex < visits.length) {
      visits[attractionIndex].arrivalTime = DateTime.now();
      visits[attractionIndex].isVisited = true;
    }
  }
  
  // 記錄景點離開
  void recordDeparture(int attractionIndex) {
    if (attractionIndex >= 0 && attractionIndex < visits.length) {
      visits[attractionIndex].departureTime = DateTime.now();
    }
  }
  
  // 記錄休息開始
  void startRest(int restIndex) {
    if (restIndex >= 0 && restIndex < restStops.length) {
      restStops[restIndex].startTime = DateTime.now();
    }
  }
  
  // 記錄休息結束
  void endRest(int restIndex) {
    if (restIndex >= 0 && restIndex < restStops.length) {
      restStops[restIndex].endTime = DateTime.now();
      restStops[restIndex].isCompleted = true;
    }
  }
  
  // 獲取行程進度（0-100）
  double getProgress() {
    if (visits.isEmpty) return 0.0;
    int visitedCount = visits.where((visit) => visit.isVisited).length;
    return (visitedCount / visits.length) * 100;
  }



  factory TripPlan.fromJson(Map<String, dynamic> json, {List<Attraction>? allAttractions}) {
    List<Attraction> tripAttractions = [];
    List<AttractionVisit> tripVisits = [];
    List<RestStop> tripRestStops = [];

    // 解析 visits 數據
    if (json['visits'] != null) {
      var visitsData = json['visits'];
      List visitsList = [];
      if (visitsData is String) {
        try {
          visitsList = jsonDecode(visitsData);
        } catch (e) {
          print("處理 visits 字符串失敗: $e");
        }
      } else if (visitsData is List) {
        visitsList = visitsData;
      }

      if (allAttractions != null) {
        for (var visitData in visitsList) {
          Map<String, dynamic> visitMap;
          if (visitData is Map) {
            visitMap = Map<String, dynamic>.from(visitData);
          } else {
            continue;
          }

          final attractionId = visitMap['attractionId'] ?? 
                              (visitMap['attraction'] != null ? visitMap['attraction']['id'] : null);
          
          if (attractionId == null) {
            print("警告: 找不到景點ID");
            continue;
          }
          
          Attraction attraction;
          final existingAttractionIndex = allAttractions.indexWhere((a) => a.id == attractionId);

          if (existingAttractionIndex != -1) {
            // 如果在 allAttractions 中找到，則使用該景點並更新其 stayDuration
            attraction = allAttractions[existingAttractionIndex];
            if (visitMap['attraction'] != null && visitMap['attraction'] is Map) {
              final visitAttractionData = Map<String, dynamic>.from(visitMap['attraction']);
              if (visitAttractionData.containsKey('stayDuration')) {
                attraction.stayDuration = visitAttractionData['stayDuration'] ?? 60;
              }
            }
          } else if (visitMap['attraction'] != null && visitMap['attraction'] is Map) {
            // 如果 allAttractions 中沒有，但 visitMap 中有完整的景點數據，則從 visitMap 創建
            attraction = Attraction.fromJson(Map<String, dynamic>.from(visitMap['attraction']));
          } else {
            // 否則創建一個默認景點
            print("警告: 找不到ID為 $attractionId 的景點，創建默認景點");
            attraction = Attraction(
              id: attractionId,
              name: 'Unknown Attraction',
              latitude: 0.0,
              longitude: 0.0,
              address: '',
              description: '',
              stayDuration: visitMap['attraction']?['stayDuration'] ?? 60,
            );
          }
          tripAttractions.add(attraction);
          // 创建 AttractionVisit 对象，使用正确的参数格式
          tripVisits.add(AttractionVisit(
            attraction: attraction,
            arrivalTime: visitMap['arrivalTime'] != null ? DateTime.parse(visitMap['arrivalTime']) : null,
            departureTime: visitMap['departureTime'] != null ? DateTime.parse(visitMap['departureTime']) : null,
            isVisited: visitMap['isVisited'] ?? false
          ));
        }
      }
    }

    // 解析 restStops 數據
    if (json['restStops'] != null) {
      var restStopsData = json['restStops'];
      List restStopsList = [];
      if (restStopsData is String) {
        try {
          restStopsList = jsonDecode(restStopsData);
        } catch (e) {
          print("處理 restStops 字符串失敗: $e");
        }
      } else if (restStopsData is List) {
        restStopsList = restStopsData;
      }

      for (var restStopData in restStopsList) {
        if (restStopData is Map) {
          tripRestStops.add(RestStop.fromJson(Map<String, dynamic>.from(restStopData)));
        }
      }
    }

    return TripPlan(
      id: json['\$id'],
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      attractions: tripAttractions,
      visits: tripVisits,
      restStops: tripRestStops,
      status: TripStatus.values[json['status']],
      actualStartTime: json['actualStartTime'] != null ? DateTime.parse(json['actualStartTime']) : null,
      actualEndTime: json['actualEndTime'] != null ? DateTime.parse(json['actualEndTime']) : null,
    );
  }
  
  // 添加一个方法来确保 visits 和 attractions 同步
  void syncVisitsWithAttractions() {
    // 检查是否有新添加的景点没有对应的 visit 记录
    for (var attraction in attractions) {
      bool hasVisit = visits.any((visit) => visit.attraction.id == attraction.id);
      if (!hasVisit) {
        visits.add(AttractionVisit(attraction: attraction));
      }
    }
    
    // 移除已删除景点的 visit 记录
    visits.removeWhere((visit) => !attractions.any((a) => a.id == visit.attraction.id));
  }
  
  // 在 toJson 方法中调用同步方法
  // 修改 toJson 方法，將 visits 和 restStops 轉換為 JSON 字符串
  Map<String, dynamic> toJson() {
    // 確保 visits 和 attractions 同步
    syncVisitsWithAttractions();
    
    // 將 visits 轉換為更適合 Appwrite 的格式 - 只儲存必要資訊
    final List<Map<String, dynamic>> visitsData = visits.map((v) => v.toJson()).toList();

    // 將 restStops 轉換為更適合 Appwrite 的格式
    final List<Map<String, dynamic>> restStopsData = restStops.map((r) => r.toJson()).toList();

    return {

      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'visits': jsonEncode(visitsData),  // 將 visits 列表序列化為 JSON 字符串
      'restStops': jsonEncode(restStopsData),  // 將 restStops 列表序列化為 JSON 字符串
      'status': status.index,
      'actualStartTime': actualStartTime?.toIso8601String(),
      'actualEndTime': actualEndTime?.toIso8601String(),
    };
  }
}