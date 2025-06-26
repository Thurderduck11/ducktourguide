import 'package:flutter/material.dart';
import '../models/trip_plan.dart';
import '../models/attraction.dart';
import '../models/attraction_visit.dart';
import '../SetDataBase.dart';
import './trip_status_screen.dart'; // 添加这行
import '../services/user_data_service.dart'; // 添加这行
import '../services/trip_timer_service.dart';

class AttractionPlanningScreen extends StatefulWidget {
  final TripPlan tripPlan;

  const AttractionPlanningScreen({
    super.key,
    required this.tripPlan,
  });

  @override
  State<AttractionPlanningScreen> createState() => _AttractionPlanningScreenState();
}

class _AttractionPlanningScreenState extends State<AttractionPlanningScreen> with TickerProviderStateMixin {
  bool _showAddOptions = false;
  bool _showAttractionForm = false;
  final _searchController = TextEditingController();
  
  // 景点数据双数组，第一个元素是名称，第二个元素是地址
  List<List<dynamic>> _attractionsData = [];
  // 搜寻结果
  List<List<dynamic>> _searchResults = [];
  
  // 休息功能相关变量
  bool _isRestMode = false;
  List<int> _selectedAttractions = [];
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;
  int _restMinutes = 30; // 预设休息时间为30分钟
  
  // 存储休息时间信息的Map，键为两个景点的索引（格式："smaller_index-larger_index"），值为休息时间（分钟）
  // 在 _AttractionPlanningScreenState 类中确保有这个定义
  Map<String, Map<String, dynamic>> _restTimes = {};
  
  // 行程計時器服務
  final TripTimerService _tripTimerService = TripTimerService();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchAttractionsData();
    
    // 初始化 _restTimes 映射，從 tripPlan.restStops 加載已有的休息時間
    _initializeRestTimes();
    
    // 啟動行程計時器
    _tripTimerService.startTripTimer(widget.tripPlan);
  }
  
  // 初始化晃动动画控制器
  void _initializeAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: -5.0,
      end: 5.0,
    ).animate(CurvedAnimation(
      parent: _shakeController!,
      curve: Curves.elasticIn,
    ));
    
    _shakeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController!.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _shakeController!.forward();
      }
    });
  }
  
  // 從 tripPlan.restStops 初始化 _restTimes
  void _initializeRestTimes() {
    // 清空現有的 _restTimes
    _restTimes.clear();
    
    // 遍歷 tripPlan.restStops，填充 _restTimes
    for (var restStop in widget.tripPlan.restStops) {
      // 查找對應的景點索引
      int? fromIndex;
      int? toIndex;
      
      for (int i = 0; i < widget.tripPlan.attractions.length; i++) {
        final attraction = widget.tripPlan.attractions[i];
        final attractionId = attraction.id ?? 'attraction_$i';
        
        if (attractionId == restStop.fromAttractionId) {
          fromIndex = i;
        }
        if (attractionId == restStop.toAttractionId) {
          toIndex = i;
        }
      }
      
      // 如果找到了對應的景點索引，添加到 _restTimes
      if (fromIndex != null && toIndex != null) {
        // 確保索引順序一致（較小的索引在前）
        if (fromIndex > toIndex) {
          final temp = fromIndex;
          fromIndex = toIndex;
          toIndex = temp;
        }
        
        final key = "$fromIndex-$toIndex";
        _restTimes[key] = {
          'minutes': restStop.durationMinutes,
          'name': restStop.name.split(' (')[0], // 去掉景點名稱部分
        };
        
        // 調試輸出
        print('初始化休息時間: $key => ${restStop.name}, ${restStop.durationMinutes}分鐘');
      } else {
        print('無法找到對應的景點索引: ${restStop.fromAttractionId} -> ${restStop.toAttractionId}');
      }
    }
    
    // 調試輸出
    print('初始化後的休息時間: $_restTimes');
  }
  
  // 从数据库获取景点数据
  Future<void> _fetchAttractionsData() async {
    try {
      final response = await database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );
      
      setState(() {
        _attractionsData = response.documents.map((doc) {
          return [
            doc.data['Name'] ?? '',
            doc.data['Address'] ?? '',
            doc.data['latitude']?.toString() ?? '0',
            doc.data['longitude']?.toString() ?? '0',
            doc.data['Description'] ?? '',
            doc.$id,
          ];
        }).toList();
      });
      
      print('成功獲取 ${_attractionsData.length} 個景點數據');
    } catch (e) {
      print('獲取景點數據失敗: $e');
    }
  }
  
  // 搜寻景点
  void _searchAttractions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    // 根据输入进行模糊搜寻
    final results = _attractionsData.where((attraction) {
      final name = attraction[0].toLowerCase();
      final address = attraction[1].toLowerCase();
      final searchLower = query.toLowerCase();
      
      return name.contains(searchLower) || address.contains(searchLower);
    }).toList();
    
    // 排序结果，使最接近的排在前面
    results.sort((a, b) {
      final aName = a[0].toLowerCase();
      final bName = b[0].toLowerCase();
      final searchLower = query.toLowerCase();
      
      // 如果名稱完全匹配，優先級最高
      if (aName == searchLower && bName != searchLower) return -1;
      if (bName == searchLower && aName != searchLower) return 1;
      
      // 如果名稱以搜尋詞開頭，優先級次之
      if (aName.startsWith(searchLower) && !bName.startsWith(searchLower)) return -1;
      if (bName.startsWith(searchLower) && !aName.startsWith(searchLower)) return 1;
      
      // 否則按照包含搜尋詞的位置排序
      return aName.indexOf(searchLower) - bName.indexOf(searchLower);
    });
    
    setState(() {
      // 最多显示5个结果
      _searchResults = results.take(5).toList();
    });
  }

  // 处理休息模式下选择景点
  void _toggleAttractionSelection(int index) {
    setState(() {
      if (_selectedAttractions.contains(index)) {
        _selectedAttractions.remove(index);
      } else {
        if (_selectedAttractions.length < 2) {
          _selectedAttractions.add(index);
        } else {
          // 如果已经选了两个，替換第一個
          _selectedAttractions.removeAt(0);
          _selectedAttractions.add(index);
        }
      }
    });
  }
  
  // 確認添加休息時間
  // 修改 _confirmRest 方法
  void _confirmRest() {
    if (_selectedAttractions.length == 2) {
      // 確保選擇的索引是按順序排列的
      _selectedAttractions.sort();
      
      // 使用局部變量存儲休息時間和名稱，以便在對話框中修改
      int dialogRestMinutes = _restMinutes;
      String dialogRestName = "休息時間"; // 預設名稱
      
      // 打印 _selectedAttractions 的資料
      print(_selectedAttractions);
      print(widget.tripPlan.attractions[_selectedAttractions[0]].id);
      print(widget.tripPlan.attractions[_selectedAttractions[1]].id);
      

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('添加休息時間'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('在 ${widget.tripPlan.attractions[_selectedAttractions[0]].name} 和 '
                    '${widget.tripPlan.attractions[_selectedAttractions[1]].name} 之間添加休息時間'),
                const SizedBox(height: 16),
                // 休息時間名稱輸入
                TextField(
                  decoration: const InputDecoration(
                    labelText: '休息時間名稱',
                    hintText: '例如：午餐、咖啡休息等',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    dialogRestName = value.isEmpty ? "休息時間" : value;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('休息時間（分鐘）：'),
                    Expanded(
                      child: Slider(
                        value: dialogRestMinutes.toDouble(),
                        min: 5,
                        max: 180,
                        divisions: 23,
                        label: dialogRestMinutes.toString(),
                        onChanged: (value) {
                          // 使用setDialogState更新對話框內的狀態
                          setDialogState(() {
                            dialogRestMinutes = value.round();
                          });
                        },
                      ),
                    ),
                    Text('$dialogRestMinutes'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                // 修改 _confirmRest 方法（約在第220行）
                onPressed: () async {
                // 存儲休息時間信息
                  final key = "${_selectedAttractions[0]}-${_selectedAttractions[1]}";
                  setState(() {
                    _restTimes[key] = {
                      'minutes': dialogRestMinutes,
                      'name': dialogRestName,
                    };
                    _restMinutes = dialogRestMinutes; // 更新主界面的休息時間值


                   
                    // 獲取景點的實際 ID
                    final fromAttraction = widget.tripPlan.attractions[_selectedAttractions[0]];
                    final toAttraction = widget.tripPlan.attractions[_selectedAttractions[1]];
                    
                    // 確保使用景點的實際文檔 ID
                    final fromId = fromAttraction.id;
                    final toId = toAttraction.id;
                    
                    // 只有當兩個景點都有有效的 ID 時才添加休息時間
                    if (fromId != null && toId != null) {
                      widget.tripPlan.restStops.add(RestStop(
                        name: dialogRestName,
                        durationMinutes: dialogRestMinutes,
                        fromAttractionId: fromId,
                        toAttractionId: toId,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('警告：景點缺少有效的 ID，休息時間可能無法正確保存')),
                      );
                    }
                  });
  
                  Navigator.pop(context);
  
                  // 顯示加載對話框
                  _showLoadingDialog('正在新增休息時間...');
  
                  // 保存到雲端
                  await _saveTripPlanToCloud();
  
                  // 關閉對話框並延遲刷新
                  await _closeDialogAndRefresh();
  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已在兩個景點之間添加 $dialogRestName：$dialogRestMinutes 分鐘')),
                    );
                  }
  
                  // 重置休息模式
                  setState(() {
                    _isRestMode = false;
                    _selectedAttractions.clear();
                    _shakeController?.stop();
                  });
                },
                child: const Text('確定'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shakeController?.dispose();
    _tripTimerService.cancelTripTimer();
    super.dispose();
  }
  
  // 添加在 _AttractionPlanningScreenState 類中
  void _syncRestStopsWithRestTimes() {
    // 清空現有的 restStops
    widget.tripPlan.restStops.clear();
  
    // 遍歷 _restTimes，創建 RestStop 對象
    _restTimes.forEach((key, value) {
      final indices = key.split('-');
      if (indices.length == 2) {
        final index1 = int.tryParse(indices[0]);
        final index2 = int.tryParse(indices[1]);
      
        if (index1 != null && index2 != null && 
            index1 < widget.tripPlan.attractions.length && 
            index2 < widget.tripPlan.attractions.length) {
          final attraction1 = widget.tripPlan.attractions[index1];
          final attraction2 = widget.tripPlan.attractions[index2];
        
          // 確保使用景點的實際文檔 ID，而不是索引
          final fromId = attraction1.id;
          final toId = attraction2.id;
          
          // 只有當兩個景點都有有效的 ID 時才添加休息時間
          if (fromId != null && toId != null) {
            widget.tripPlan.restStops.add(RestStop(
              name: "${value['name']}",
              durationMinutes: value['minutes'],
              fromAttractionId: fromId,
              toAttractionId: toId,
            ));
          } else {
            print('警告：景點缺少有效的 ID，無法添加休息時間');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 在 build 方法中的 AppBar 中添加行程状态按钮
      appBar: AppBar(
        title: Text(widget.tripPlan.name),
        actions: [
          // 添加行程状态按钮
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: '行程狀態',
            onPressed: () {
              // 檢查當前時間是否在旅遊時間之前
              final now = DateTime.now();
              if (now.isAfter(widget.tripPlan.startTime)) {
                // 如果當前時間已經超過旅遊開始時間，顯示提示
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('目前的時間在旅遊時間之後，請重新調整時間'),
                    ),
                  );
                }
              } else {
                // 時間正確，導航到行程狀態頁面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripStatusScreen(tripPlan: widget.tripPlan),
                  ),
                );
              }
            },
          ),
        // 其他现有按钮...
        ],
      ),
      body: Column(
        children: [
          // 显示已添加的景点列表
          Expanded(
            child: widget.tripPlan.attractions.isEmpty
                ? const Center(
                    child: Text(
                      '尚未添加景点',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: widget.tripPlan.attractions.length * 2 - 1, // 景点数量*2-1，包括景点和休息时间
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        // 只处理景点的拖动（偶数索引）
                        if (oldIndex % 2 == 0 && newIndex % 2 == 0) {
                          // 将 ReorderableListView 的索引转换为景点列表的索引
                          final oldAttractionIndex = oldIndex ~/ 2;
                          var newAttractionIndex = newIndex ~/ 2;
                          
                          // 调整新索引（ReorderableListView 的特性）
                          if (oldIndex < newIndex) {
                            newAttractionIndex -= 1;
                          }
                          
                          // 移动景点
                          final attraction = widget.tripPlan.attractions.removeAt(oldAttractionIndex);
                          widget.tripPlan.attractions.insert(newAttractionIndex, attraction);
                          
                          // 处理休息时间
                          _updateRestTimesAfterReorder(oldAttractionIndex, newAttractionIndex);
                        } else if (newIndex % 2 != 0) {
                          // 如果拖动到休息时间位置，调整到最近的景点位置
                          if (newIndex < oldIndex) {
                            newIndex = newIndex - 1;
                          } else {
                            newIndex = newIndex + 1;
                          }
                          
                          // 重新调用 onReorder
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              // 將 ReorderableListView 的索引转换为景点列表的索引
                              final oldAttractionIndex = oldIndex ~/ 2;
                              var newAttractionIndex = newIndex ~/ 2;
                              
                              // 调整新索引（ReorderableListView 的特性）
                              if (oldIndex < newIndex) {
                                newAttractionIndex -= 1;
                              }
                              
                              // 移动景点
                              final attraction = widget.tripPlan.attractions.removeAt(oldAttractionIndex);
                              widget.tripPlan.attractions.insert(newAttractionIndex, attraction);
                              
                              // 处理休息时间
                              _updateRestTimesAfterReorder(oldAttractionIndex, newAttractionIndex);
                            });
                          });
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      // 偶数索引显示景点，奇数索引显示休息时间（如果有）
                      if (index % 2 == 0) {
                        // 显示景点
                        final attractionIndex = index ~/ 2;
                        final attraction = widget.tripPlan.attractions[attractionIndex];
                        
                        // 在休息模式下添加晃动效果和选择功能
                        if (_isRestMode) {
                          return AnimatedBuilder(
                            key: ValueKey('attraction_$index'),
                            animation: _shakeController!,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation!.value, 0),
                                child: ListTile(
                                  title: Text(attraction.name),
                                  subtitle: Text(attraction.address),
                                  tileColor: _selectedAttractions.contains(attractionIndex)
                                      ? Colors.blue.withOpacity(0.3)
                                      : null,
                                  onTap: () => _toggleAttractionSelection(attractionIndex),
                                ),
                              );
                            },
                          );
                        } else {
                          // 修改景点显示的 ListTile（在 index % 2 == 0 的分支中）
                          return ListTile(
                            key: ValueKey('attraction_$index'),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(attraction.name),
                                ),
                                Text(
                                  '${attraction.stayDuration}分鐘',
                                  style: TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ],
                            ),
                            subtitle: Text(attraction.address),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 拖动手柄图标
                                const Icon(Icons.drag_handle),
                                // 编辑停留时间按鈕
                                IconButton(
                                  icon: const Icon(Icons.timer, color: Colors.green),
                                  onPressed: () {
                                    // 设置初始停留时间为当前值
                                    int dialogStayDuration = attraction.stayDuration;
                                    
                                    // 显示修改停留时间的对话框
                                    // 修改景点显示的 ListTile 中的对话框部分
                                    showDialog(
                                      context: context,
                                      builder: (context) => StatefulBuilder(
                                        builder: (context, setDialogState) => AlertDialog(
                                          title: const Text('設置景點的停留時間'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('設置在該景點的停留時間'),
                                              const SizedBox(height: 16),
                                              const Text('設置景點停留時間'),
                                              Row(
                                                children: [
                                                  const Text('停留時間(分鐘)：'),
                                                  Expanded(
                                                    child: Slider(
                                                      value: dialogStayDuration.toDouble(),
                                                      min: 5,
                                                      max: 240,
                                                      divisions: 45,
                                                      label: dialogStayDuration.toString(),
                                                      onChanged: (value) {
                                                        setDialogState(() {
                                                          dialogStayDuration = value.round();
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  Text('$dialogStayDuration'),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                // 更新停留时间
                                                setState(() {
                                                  attraction.stayDuration = dialogStayDuration;
                                                });
                                                
                                                Navigator.pop(context);
                                                
                                                // 顯示加載對話框
                                                _showLoadingDialog('正在更新停留時間...');
                                                
                                                // 保存到雲端
                                                await _saveTripPlanToCloud();
                                                
                                                // 關閉對話框並延遲刷新
                                                await _closeDialogAndRefresh();
                                                
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('已設置在該景點的停留時間：$dialogStayDuration 分鐘')),
                                                  );
                                                }
                                              },
                                              child: const Text('確定'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // 删除景点按鈕
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    // 顯示確認刪除的對話框
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('刪除景點'),
                                        content: Text('確認要刪除景點 ${attraction.name} 嗎？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                                      // 刪除景點
                                                      setState(() {
                                                        widget.tripPlan.attractions.removeAt(attractionIndex);
                                                        // 更新休息時間
                                                        _updateRestTimesAfterReorder(attractionIndex, attractionIndex);
                                                      });
                                                      
                                                      Navigator.pop(context);
                                                      
                                                      // 顯示加載對話框
                                                      _showLoadingDialog('正在刪除景點...');
                                                      
                                                      // 保存到雲端
                                                      await _saveTripPlanToCloud();
                                                      
                                                      // 關閉對話框並延遲刷新
                                                      await _closeDialogAndRefresh();
                                                      
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('已刪除景點：${attraction.name}')),
                                                        );
                                                      }
                                            },
                                            child: const Text('確定'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                      } else {
                        // 显示休息时间（如果有）
                        final prevIndex = index ~/ 2;
                        final nextIndex = prevIndex + 1;
                        
                        // 检查这两个景点之间是否有休息时间
                        final key = "$prevIndex-$nextIndex";
                        final restTime = _restTimes[key];
                        
                        // 修改休息时间小格子的显示（在 index % 2 == 1 的分支中）
                        if (restTime != null) {
                          // 获取休息时间信息
                          final restMinutes = restTime['minutes'];
                          final restName = restTime['name'];
                          
                          // 显示休息时间的小格子
                          return Container(
                            key: ValueKey('rest_$index'), // 添加唯一的 key
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 显示休息时间名稱
                                Text(
                                  restName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '時間：$restMinutes 分鐘',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Row(
                                      children: [
                                        // 修改休息時間按鈕
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () {
                                            // 設置初始休息時間和名稱為當前值
                                            int dialogRestMinutes = restMinutes;
                                            String dialogRestName = restName;
                                            
                                            // 显示修改休息时间的对话框
                                            showDialog(
                                              context: context,
                                              builder: (context) => StatefulBuilder(
                                                builder: (context, setDialogState) => AlertDialog(
                                                  title: const Text('修改休息時間'),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text('在 ${widget.tripPlan.attractions[prevIndex].name} 和 '
                                                          '${widget.tripPlan.attractions[nextIndex].name} 之间的休息'),
                                                      const SizedBox(height: 16),
                                                      // 休息时间名称输入
                                                      TextField(
                                                        decoration: const InputDecoration(
                                                          labelText: '休息時間名稱',
                                                          hintText: '例如：午餐、咖啡休息等',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        controller: TextEditingController(text: dialogRestName),
                                                        onChanged: (value) {
                                                          dialogRestName = value.isEmpty ? "休息時間" : value;
                                                        },
                                                      ),
                                                      const SizedBox(height: 16),
                                                      Row(
                                                        children: [
                                                          const Text('休息時間(分鐘)：'),
                                                          Expanded(
                                                            child: Slider(
                                                              value: dialogRestMinutes.toDouble(),
                                                              min: 5,
                                                              max: 180,
                                                              divisions: 23,
                                                              label: dialogRestMinutes.toString(),
                                                              onChanged: (value) {
                                                                // 使用setDialogState更新对话框内的状态
                                                                setDialogState(() {
                                                                  dialogRestMinutes = value.round();
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                          Text('$dialogRestMinutes'),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('取消'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        // 更新休息时间
                                                        setState(() {
                                                          _restTimes[key] = {
                                                            'minutes': dialogRestMinutes,
                                                            'name': dialogRestName,
                                                          };
                                                        });
                                                        
                                                        Navigator.pop(context);
                                                        
                                                        // 顯示加載對話框
                                                        _showLoadingDialog('正在更新休息時間...');
                                                        
                                                        // 同步休息時間並保存到雲端
                                                        _syncRestStopsWithRestTimes();
                                                        await _saveTripPlanToCloud();
                                                        
                                                        // 關閉對話框並延遲刷新
                                                        await _closeDialogAndRefresh();
                                                        
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('已更新休息時間為 $dialogRestName：$dialogRestMinutes 分鐘')),
                                                        );
                                                      },
                                                      child: const Text('確定'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        // 删除休息时间按鈕
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            // 显示确认删除的对话框
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('刪除休息時間'),
                                                content: Text('確定要刪除 ${widget.tripPlan.attractions[prevIndex].name} 和 '
                                                    '${widget.tripPlan.attractions[nextIndex].name} 之間的休息時間嗎?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('取消'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      // 删除休息时间
                                                      setState(() {
                                                        _restTimes.remove(key);
                                                        
                                                        // 同時從 tripPlan.restStops 中移除對應的休息時間
                                                        final fromAttrId = widget.tripPlan.attractions[prevIndex].id;
                                                        final toAttrId = widget.tripPlan.attractions[nextIndex].id;
                                                        
                                                        widget.tripPlan.restStops.removeWhere((stop) => 
                                                          (stop.fromAttractionId == fromAttrId && stop.toAttractionId == toAttrId) ||
                                                          (stop.fromAttractionId == toAttrId && stop.toAttractionId == fromAttrId) ||
                                                          (stop.fromAttractionId == 'attraction_$prevIndex' && stop.toAttractionId == 'attraction_$nextIndex') ||
                                                          (stop.fromAttractionId == 'attraction_$nextIndex' && stop.toAttractionId == 'attraction_$prevIndex')
                                                        );
                                                      });
                                                      
                                                      Navigator.pop(context);
                                                      
                                                      // 顯示加載對話框
                                                      _showLoadingDialog('正在刪除休息時間...');
                                                      
                                                      // 保存到雲端
                                                      await _saveTripPlanToCloud();
                                                      
                                                      // 關閉對話框並延遲刷新
                                                      await _closeDialogAndRefresh();
                                                      
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('已刪除休息時間')),
                                                        );
                                                      }
                                                    },
                                                    child: const Text('确定'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else {
                          // 如果没有休息时间，返回一个空的SizedBox
                          return SizedBox(
                            key: ValueKey('empty_rest_$index'), // 添加唯一的 key
                            height: 0
                          );
                        }
                      }
                    },
                  ),
          ),
          
          // 休息模式下的确认按鈕
          if (_isRestMode && _selectedAttractions.length == 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _confirmRest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('確認添加休息时间'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isRestMode = false;
                        _selectedAttractions.clear();
                        _shakeController?.stop();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          
          // 搜尋景點表單
          if (_showAttractionForm)
            Container(
              color: Colors.blue[100],
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '輸入景點名稱或地址',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: _searchAttractions,
                  ),
                  const SizedBox(height: 8),
                  
                  // 搜尋結果列表
                  if (_searchResults.isNotEmpty)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final attraction = _searchResults[index];
                          return ListTile(
                            title: Text(attraction[0]),
                            subtitle: Text(attraction[1]),
                            // 修改搜尋結果列表項的onTap處理邏輯
                            onTap: () {
                              // 顯示確認對話框
                              showDialog(
                                context: context,
                                builder: (context) {
                                  int dialogStayDuration = 60; // 預設停留時間，移到外部
                                  
                                  return StatefulBuilder(
                                    builder: (context, setDialogState) => AlertDialog(
                                      title: const Text('確認選擇景點'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('您確定要選擇以下景點嗎？'),
                                          const SizedBox(height: 12),
                                          Text('名稱：${attraction[0]}', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('地址：${attraction[1]}'),
                                          if (attraction[4].isNotEmpty) 
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text('描述：${attraction[4]}'),
                                            ),
                                          const SizedBox(height: 16),
                                          const Text('設置停留時間：'),
                                          Row(
                                            children: [
                                              const Text('停留時間（分鐘）：'),
                                              Expanded(
                                                child: Slider(
                                                  value: dialogStayDuration.toDouble(),
                                                  min: 5,
                                                  max: 240,
                                                  divisions: 45,
                                                  label: dialogStayDuration.toString(),
                                                  onChanged: (value) {
                                                    setDialogState(() {
                                                      dialogStayDuration = value.round();
                                                    });
                                                  },
                                                ),
                                              ),
                                              Text('$dialogStayDuration'),
                                            ],
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            // 確認選擇，添加景點
                                            setState(() {
                                              Attraction newAttraction = Attraction(
                                                name: attraction[0],
                                                address: attraction[1],
                                                latitude: double.parse(attraction[2]),
                                                longitude: double.parse(attraction[3]),
                                                description: attraction[4],
                                                id: attraction[5],
                                                stayDuration: dialogStayDuration, // 設置停留時間
                                              );
                                              
                                              // 添加景點到行程
                                              widget.tripPlan.attractions.add(newAttraction);
                                              
                                              // 同時創建對應的 AttractionVisit 記錄
                                              widget.tripPlan.visits.add(AttractionVisit(
                                                attraction: newAttraction,
                                                isVisited: false
                                              ));
                                              
                                              _searchController.clear();
                                              _searchResults = [];
                                              _showAttractionForm = false;
                                              _showAddOptions = false;
                                            });
                                            Navigator.pop(context);
                                            
                                            // 顯示加載對話框
                                            _showLoadingDialog('正在新增景點...');
                                            
                                            // 保存到雲端
                                            await _saveTripPlanToCloud();
                                            
                                            // 關閉對話框並延遲刷新
                                            await _closeDialogAndRefresh();
                                              
                                            // 顯示添加成功提示
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('已成功添加景點：${attraction[0]}，停留時間：$dialogStayDuration 分鐘')),
                                              );
                                            }
                                          },
                                          child: const Text('確定'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // 返回到上一個選單
                          setState(() {
                            _showAttractionForm = false;
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('取消新增'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_searchController.text.isNotEmpty) {
                            _searchAttractions(_searchController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[300],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('搜尋景點'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // 新增選項按鈕
          if (_showAddOptions && !_showAttractionForm)
            Container(
              color: Colors.blue[100],
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showAttractionForm = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('搜尋景點'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // 實現休息功能
                      if (widget.tripPlan.attractions.length < 2) {
                        if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('至少需要兩個景點才能添加休息時間')),
                        );
                      }
                        return;
                      }
                      
                      setState(() {
                        _isRestMode = true;
                        _showAddOptions = false;
                        _shakeController?.forward();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[300],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('休息'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showAddOptions = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('取消新增'),
                  ),
                ],
              ),
            ),
          
          // 底部新增按鈕
          if (!_showAddOptions && !_showAttractionForm && !_isRestMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showAddOptions = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  '新增行程',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 處理拖動排序後的休息時間更新
  void _updateRestTimesAfterReorder(int oldIndex, int newIndex) {
    // 創建新的休息時間 Map
    Map<String, Map<String, dynamic>> newRestTimes = {};
    
    // 遍歷所有景點對，重新計算休息時間
    for (int i = 0; i < widget.tripPlan.attractions.length - 1; i++) {
      // 檢查原始的休息時間 Map 中是否有對應的休息時間
      bool foundRest = false;
      
      // 遍歷原始的休息時間 Map
      _restTimes.forEach((key, value) {
        final indices = key.split('-').map(int.parse).toList();
        
        // 如果找到匹配的景點對，則保留休息時間
        if ((indices[0] == i && indices[1] == i + 1) ||
            (indices[1] == i && indices[0] == i + 1)) {
          newRestTimes["$i-${i + 1}"] = value;
          foundRest = true;
        }
      });
      
      // 如果沒有找到匹配的休息時間，則不添加
    }
    
    // 更新休息時間 Map
    _restTimes = newRestTimes;
  }
  
  // 顯示加載對話框
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止用戶點擊外部關閉對話框
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // 關閉對話框並延遲刷新
  Future<void> _closeDialogAndRefresh() async {
    // 等待3秒
    await Future.delayed(const Duration(seconds: 3));
    
    // 關閉對話框
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
  
  // 保存行程到雲端
  Future<void> _saveTripPlanToCloud() async {
    try {
    // 顯示保存中的提示
      _showLoadingDialog('正在保存行程到雲端...');
    
    // 确保 visits 和 attractions 同步
      widget.tripPlan.syncVisitsWithAttractions();

    // 显式更新 visits 中 attraction 的 stayDuration
      for (var visit in widget.tripPlan.visits) {
        final correspondingAttraction = widget.tripPlan.attractions.firstWhere(
          (att) => att.id == visit.attraction.id,
          orElse: () => visit.attraction, // Fallback to existing if not found (shouldn't happen if synced)
        );
        visit.attraction.stayDuration = correspondingAttraction.stayDuration;
      }
    
    // 同步休息時間
      _syncRestStopsWithRestTimes();
    
    // 調用 UserDataService 保存行程
      await UserDataService.saveTripPlan(widget.tripPlan);
      
      // 顯示保存成功的提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('行程已成功保存到雲端')),
        );
      }
    } catch (e) {
      // 顯示保存失敗的提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存行程失敗：$e')),
        );
      }
      print('保存行程失敗：$e');
    } finally {
      // 關閉對話框並延遲刷新
      await _closeDialogAndRefresh();
    }
  }
}