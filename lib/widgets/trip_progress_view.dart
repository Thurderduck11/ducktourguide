import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import '../models/attraction_visit.dart';
class TripProgressView extends StatelessWidget {
  final TripPlan tripPlan;
  
  const TripProgressView({Key? key, required this.tripPlan}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '行程進度',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16.0),
            LinearProgressIndicator(
              value: tripPlan.getProgress() / 100,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8.0),
            Text(
              '${tripPlan.getProgress().toStringAsFixed(0)}% 完成',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16.0),
            _buildVisitList(),
          ],
        ),
      ),
    );
  }
  
  // 在 _buildVisitList 方法中添加休息时间的显示
  Widget _buildVisitList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('景點訪問情況：'),
        const SizedBox(height: 8.0),
        ...tripPlan.visits.map((visit) => _buildVisitItem(visit)).toList(),
        
        // 添加休息时间显示
        if (tripPlan.restStops.isNotEmpty) ...[  
          const SizedBox(height: 16.0),
          const Text('休息時間：'),
          const SizedBox(height: 8.0),
          ...tripPlan.restStops.map((rest) => _buildRestItem(rest)).toList(),
        ],
      ],
    );
  }
  
  // 添加显示休息时间的方法
  Widget _buildRestItem(RestStop rest) {
    final isCompleted = rest.isCompleted;
    
    String restStatus = '未開始';
    Color statusColor = Colors.grey;
    
    if (isCompleted) {
      restStatus = '已完成';
      statusColor = Colors.green;
      
      if (rest.startTime != null && rest.endTime != null) {
        final duration = rest.endTime!.difference(rest.startTime!);
        final minutes = duration.inMinutes;
        restStatus = '已完成 (实际 $minutes 分钟)';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.coffee,
            color: statusColor,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text('${rest.name} (計畫 ${rest.durationMinutes} 分鐘)'),
          ),
          Text(
            restStatus,
            style: TextStyle(color: statusColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVisitItem(AttractionVisit visit) {
    final attraction = visit.attraction;
    final isVisited = visit.isVisited;
    
    String visitStatus = '未訪問';
    Color statusColor = Colors.grey;
    
    if (isVisited) {
      visitStatus = '已訪問';
      statusColor = Colors.green;
      
      if (visit.arrivalTime != null && visit.departureTime != null) {
        final duration = visit.departureTime!.difference(visit.arrivalTime!);
        final minutes = duration.inMinutes;
        visitStatus = '已訪問(停留 $minutes 分鐘)';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isVisited ? Icons.check_circle : Icons.circle_outlined,
            color: statusColor,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(attraction.name),
          ),
          Text(
            visitStatus,
            style: TextStyle(color: statusColor),
          ),
        ],
      ),
    );
  }
}