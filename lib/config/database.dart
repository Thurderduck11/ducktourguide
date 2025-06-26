import 'package:appwrite/appwrite.dart';

// 創建 Appwrite 客戶端
final client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('67c37669001b422e83e6') // 請替換為您的實際專案ID
    .setSelfSigned(status: true); // 添加這一行

// 創建數據庫實例
final database = Databases(client);

// 數據庫和集合ID
const String databaseId = '67c37890000902e1e89b'; // 請替換為您的實際數據庫ID
const String collectionId = '67c378f40032f3b1b9df'; // 請替換為您的實際集合ID