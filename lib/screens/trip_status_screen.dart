import 'dart:async'; // 添加這行導入
import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import '../services/trip_state_manager.dart';
import '../widgets/trip_progress_view.dart';
import '../models/attraction_visit.dart';
import '../services/trip_status_manager.dart';
import '../services/user_data_service.dart';

class TripStatusScreen extends StatefulWidget {
  final TripPlan tripPlan;
  
  const TripStatusScreen({Key? key, required this.tripPlan}) : super(key: key);
  
  @override
  State<TripStatusScreen> createState() => _TripStatusScreenState();
}

class _TripStatusScreenState extends State<TripStatusScreen> {
  late TripStateManager _tripStateManager;
  bool _isTripRunning = false;
  TripPlan? _activeTrip;
  Timer? _statusCheckTimer; // 添加定時器變量
  
  @override
  void initState() {
    super.initState();
    _checkActiveTrip();
    
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
      
      // 重新檢查活動行程
      await _checkActiveTrip();
      
      print('行程狀態畫面：行程狀態已更新，當前狀態: ${TripStatusManager.status}');
    } catch (e) {
      print('行程狀態畫面：檢查行程狀態更新失敗: $e');
    }
  }
  
  // 檢查雲端是否有已啟動的行程
  Future<void> _checkActiveTrip() async {
    try {
      // 獲取所有行程
      final trips = await UserDataService.getUserTrips();
      
      // 尋找狀態為進行中(status 2)的行程
      final activeTrip = trips.firstWhere(
        (trip) => trip.status == TripStatus.inProgress,
        orElse: () => widget.tripPlan, // 如果沒有找到，使用當前行程
      );
      
      setState(() {
        _activeTrip = activeTrip;
        // 如果找到的行程是進行中狀態，設置 _isTripRunning 為 true
        _isTripRunning = activeTrip.status == TripStatus.inProgress;
        // 使用找到的行程初始化 TripStateManager
        _tripStateManager = TripStateManager(tripPlan: _activeTrip!);
      });
      
      print('檢查雲端行程結果: ${_activeTrip?.name}, 狀態: ${_activeTrip?.status}');
    } catch (e) {
      print('檢查雲端行程失敗: $e');
      // 如果發生錯誤，使用當前行程
      setState(() {
        _activeTrip = widget.tripPlan;
        _tripStateManager = TripStateManager(tripPlan: widget.tripPlan);
      });
    }
  }
  
  @override
  void dispose() {
    _tripStateManager.dispose();
    _statusCheckTimer?.cancel(); // 取消定時器
    super.dispose();
  }
  
  // 在文件頂部添加導入

  
  // 在 _startTrip 方法中添加狀態更新
  void _startTrip() async {
    await _tripStateManager.startTrip();
    // 更新行程狀態
    await TripStatusManager.updateStatus(2, _activeTrip);
    setState(() {
      _isTripRunning = true;
    });
  }
  
  // 在 _endTrip 方法中添加狀態更新
  void _endTrip() async {
    await _tripStateManager.endTrip();
    // 更新行程狀態
    await TripStatusManager.updateStatus(3, _activeTrip);
    setState(() {
      _isTripRunning = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 如果 _activeTrip 還未初始化，顯示加載指示器
    if (_activeTrip == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tripPlan.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_activeTrip!.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 行程状态卡片
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '行程狀態',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    _buildTripStatusInfo(),
                    const SizedBox(height: 16.0),
                    _buildTripControls(),
                  ],
                ),
              ),
            ),
            
            // 行程进度视图
            TripProgressView(tripPlan: widget.tripPlan),
            
            // 景点列表
            _buildAttractionsList(),
          ],
        ),
      ),
    );
  }
  
  // 修改文字為繁體中文
  Widget _buildTripStatusInfo() {
    final status = _activeTrip!.status;
    String statusText;
    Color statusColor;
    
    switch (status) {
      case TripStatus.notStarted:
        statusText = '未開始';
        statusColor = Colors.grey;
        break;
      case TripStatus.preparation:
        statusText = '預備中';
        statusColor = Colors.grey;
        break;
      case TripStatus.inProgress:
        statusText = '進行中';
        statusColor = Colors.blue;
        break;
      case TripStatus.completed:
        statusText = '已完成';
        statusColor = Colors.green;
        break;
    }
    
    return Row(
      children: [
        Icon(Icons.info_outline, color: statusColor),
        const SizedBox(width: 8.0),
        Text(
          '狀態: $statusText',
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  // 在 _buildTripControls 方法中使用 _activeTrip
  Widget _buildTripControls() {
    if (_activeTrip!.status == TripStatus.completed) {
      return const Text('此行程已完成');
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!_isTripRunning)
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('開始行程'),
            onPressed: _startTrip,
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('結束行程'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _endTrip,
          ),
      ],
    );
  }
  
  // 在 _buildAttractionsList 方法中使用 _activeTrip
  Widget _buildAttractionsList() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '景點列表',  // 修改为繁体中文
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16.0),
            ...widget.tripPlan.visits.asMap().entries.map((entry) {
              final index = entry.key;
              final visit = entry.value;
              print('List Item - Attraction Name: ${visit.attraction.name}, Stay Duration: ${visit.attraction.stayDuration}');
              return _buildAttractionItem(index, visit);
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  // 在 _buildAttractionItem 方法中
  Widget _buildAttractionItem(int index, AttractionVisit visit) {
    final attraction = visit.attraction;
    final isCurrentAttraction = _tripStateManager.currentAttractionIndex == index;
    print('Attraction Name: ${attraction.name}, Stay Duration: ${attraction.stayDuration}');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isCurrentAttraction ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: visit.isVisited ? Colors.green : Colors.grey,
          child: Text('${index + 1}'),
        ),
        title: Text(attraction.name),
        subtitle: Text('計劃停留: ${visit.attraction.stayDuration} 分鐘'),
        trailing: _isTripRunning ? _buildAttractionControls(index, visit) : null,
      ),
    );
  }
  
  // 在 _buildAttractionControls 方法中
  Widget _buildAttractionControls(int index, AttractionVisit visit) {
    if (!_isTripRunning) return const SizedBox.shrink();
    
    final isCurrentAttraction = _tripStateManager.currentAttractionIndex == index;
    
    if (visit.isVisited && visit.departureTime != null) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    
    if (isCurrentAttraction) {
      return ElevatedButton(
        onPressed: () => _tripStateManager.manualDepartFromAttraction(index),
        child: const Text('離開'),
      );
    }
    
    if (!visit.isVisited) {
      return ElevatedButton(
        onPressed: () => _tripStateManager.manualArriveAtAttraction(index),
        child: const Text('到達'),
      );
    }
    
    return const SizedBox.shrink();
  }
}