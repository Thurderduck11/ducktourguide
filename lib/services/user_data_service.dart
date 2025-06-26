import 'package:appwrite/appwrite.dart';
import '../models/trip_plan.dart';
import '../models/attraction.dart';
import '../SetDataBase.dart' as set_db;
import 'auth_service.dart';
import 'attraction_service.dart';

class UserDataService {
  static final Databases _database = set_db.database;
  static const String _userTripsCollectionId = set_db.userTripsCollectionId;
  
  // 保存JSON數據到Appwrite
  static Future<void> saveTripPlan(TripPlan tripPlan) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        print('用戶未登入');
        throw Exception('用戶未登入');
      } else {
        print('當前登入用戶: ${user.$id}, ${user.name}');
        
        // 檢查 session 是否有效
        try {
          final sessions = await AuthService.account.listSessions();
          print('當前活動 session 數量: ${sessions.sessions.length}');
          if (sessions.sessions.isEmpty) {
            print('警告：沒有活動的 session');
          }
        } catch (e) {
          print('獲取 session 時出錯: $e');
        }
      }
      
      // 將模型轉換為JSON
      final tripData = tripPlan.toJson();
      tripData['userId'] = user.$id; // 添加用戶ID
      
      // 設置文檔權限 - 修改這部分
      final permissions = [
        // 只給當前用戶完整權限
        Permission.read(Role.user(user.$id)),   // 允許當前用戶讀取
        Permission.update(Role.user(user.$id)), // 允許當前用戶修改
        Permission.delete(Role.user(user.$id)), // 允許當前用戶刪除
        Permission.write(Role.user(user.$id)),  // 允許當前用戶寫入
        
        // 如果需要其他用戶也能查看（可選）
        Permission.read(Role.any()),            // 允許任何人讀取
      ];
      
      // 創建或更新文檔
      if (tripPlan.id != null && tripPlan.id!.isNotEmpty) {
        // 更新現有文檔
        await _database.updateDocument(
          databaseId: set_db.databaseId,
          collectionId: _userTripsCollectionId,
          documentId: tripPlan.id!,
          data: tripData,
          permissions: permissions,
        );
      } else {
        // 創建新文檔
        final response = await _database.createDocument(
          databaseId: set_db.databaseId,
          collectionId: _userTripsCollectionId,
          documentId: ID.unique(), // 生成唯一ID
          data: tripData,
          permissions: permissions,
        );
        
        // 更新模型的ID
        tripPlan.id = response.$id;
      }
    } catch (e) {
      // 錯誤處理
      if (e is AppwriteException) {
        print('Appwrite錯誤碼: ${e.code}');
        print('Appwrite錯誤信息: ${e.message}');
      }
      print('保存行程失敗：$e');
      rethrow;
    }
  }
  
  // 獲取用戶的所有行程
  static Future<List<TripPlan>> getUserTrips() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) throw Exception('用戶未登入');
      
      // 先獲取所有景點
      final attractionService = AttractionService();
      final allAttractions = await attractionService.fetchAttractions();
      
      // 打印所有景點資料
      /*print('\n=== 所有景點資料 ===');
      for (var attraction in allAttractions) {
        print('\n景點名稱: ${attraction.name}');
        print('景點ID: ${attraction.id}');
        print('描述: ${attraction.description}');
        print('地址: ${attraction.address}');
        print('緯度: ${attraction.latitude}');
        print('經度: ${attraction.longitude}');
        print('------------------------');
      }
      print('=== 景點資料結束 ===\n');
      */

      // 獲取用戶的行程
      final response = await _database.listDocuments(
        databaseId: set_db.databaseId,
        collectionId: _userTripsCollectionId,
        queries: [
          Query.equal('userId', user.$id)
        ],
      );

      // 將文檔轉換為TripPlan對象
      return response.documents.map((doc) {
        return TripPlan.fromJson(doc.data, allAttractions: allAttractions);
      }).toList();
    } catch (e) {
      // 錯誤處理
      if (e is AppwriteException) {
        print('Appwrite錯誤碼: ${e.code}');
        print('Appwrite錯誤信息: ${e.message}');
      }
      rethrow;
    }
  }
  
  // 刪除行程
  static Future<void> deleteTripPlan(String tripId) async {
    try {
      await _database.deleteDocument(
        databaseId: set_db.databaseId,
        collectionId: _userTripsCollectionId,
        documentId: tripId,
      );
    } catch (e) {
      // 錯誤處理
      if (e is AppwriteException) {
        print('Appwrite錯誤碼: ${e.code}');
        print('Appwrite錯誤信息: ${e.message}');
      }
      rethrow;
    }
  }
}