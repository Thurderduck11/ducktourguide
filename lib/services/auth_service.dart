import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import '../config/database.dart' as db_config;
import '../SetDataBase.dart' as set_db;

class AuthService {
  static final Client client = db_config.client;
  static final Account account = Account(client);
  static final Databases databases = set_db.database;
  static final Realtime realtime = Realtime(client); // 添加 Realtime 實例
  
  // 用戶註冊
  static Future<User> createAccount(String email, String password, String name) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      
      // 創建用戶文檔
      await createUserDocument(user);
      
      return user;
    } catch (e) {
      rethrow;
    }
  }
  
  // 在用戶註冊後創建用戶文檔
  static Future<void> createUserDocument(User user) async {
    try {
      print('創建用戶文檔，用戶ID: ${user.$id}');
      
      // 創建用戶文檔
      await databases.createDocument(
        databaseId: set_db.databaseId,
        collectionId: set_db.usersCollectionId, // 使用正確的用戶集合 ID
        documentId: user.$id, // 使用 Appwrite 用戶 ID 作為文檔 ID
        data: {
          'userId': user.$id,
          'name': user.name,
          'email': user.email,
          'createdAt': DateTime.now().toIso8601String(),
          // 添加其他用戶屬性
        },
      );
      print('用戶文檔創建成功');
    } catch (e) {
      print('創建用戶文檔時出錯: $e');
      // 這裡我們不重新拋出錯誤，因為即使用戶文檔創建失敗，用戶仍然可以註冊成功
    }
  }
  
  
  
  // 用戶登入 - 確保先清除現有 session
  static Future<Session> login(String email, String password) async {
    try {
      // 嘗試清除任何現有的 session
      try {
        await logout();
        print('成功清除現有 session');
      } catch (e) {
        print('清除現有 session 時出錯 (可能沒有活動的 session): $e');
        // 這裡我們不重新拋出錯誤，因為用戶可能沒有活動的 session
      }
      
      // 創建新的 session
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      
      print('成功創建新 session: ${session.$id}');
      return session;
    } catch (e) {
      print('登入時出錯: $e');
      rethrow;
    }
  }
  
  // 用戶登出 - 確保刪除所有 session
  static Future<void> logout() async {
    try {
      // 先獲取所有 session
      final sessions = await account.listSessions();
      
      // 逐一刪除每個 session
      for (var session in sessions.sessions) {
        try {
          await account.deleteSession(sessionId: session.$id);
          print('成功刪除 session: ${session.$id}');
        } catch (e) {
          print('刪除 session ${session.$id} 時出錯: $e');
        }
      }
      
      print('所有 session 已刪除');
    } catch (e) {
      print('登出時出錯: $e');
      rethrow;
    }
  }
  
  // 獲取當前用戶
  static Future<User?> getCurrentUser() async {
    try {
      final user = await account.get();
      return user;
    } catch (e) {
      return null;
    }
  }
  
  // 檢查用戶是否已登入
  static Future<bool> isLoggedIn() async {
    try {
      await account.get();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // 重設密碼
  static Future<void> resetPassword(String email) async {
    try {
      await account.createRecovery(
        email: email,
        url: 'https://yourapp.com/reset-password', // 您需要設置一個密碼重設頁面的URL
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // 添加登入狀態監聽器
  static RealtimeSubscription onUserStatusChange() {
    return realtime.subscribe(['account']);
  }
  
  // 添加這個方法到 AuthService 類中
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    // 顯示確認對話框
    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認登出'),
          content: const Text('您確定要登出帳號嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
    
    return result ?? false; // 如果用戶關閉對話框而不選擇，預設為取消登出
  }
}