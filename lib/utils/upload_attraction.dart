import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../config/database.dart' as db_config;
import 'package:appwrite/appwrite.dart';
import '../SetDataBase.dart' as set_db;

Future<void> processExcelAndUpload(String excelPath, String imagesPath) async {
  try {
    // 使用 rootBundle 讀取 assets 中的 Excel 檔案
    final byteData = await rootBundle.load(excelPath);
    var bytes = byteData.buffer.asUint8List();
    var excel = Excel.decodeBytes(bytes);
    
    // 假設第一個工作表包含數據
    var sheet = excel.tables.keys.first;
    var table = excel.tables[sheet];
    
    if (table == null) {
      print("Excel 檔案中沒有工作表");
      return;
    }
    
    // 跳過標題行
    for (int i = 1; i < table.rows.length; i++) {
      var row = table.rows[i];
      print(row);
      // 假設列的順序是：Name, Address, Description, Latitude, Longitude
      String name = row[0]?.value?.toString() ?? '';
      String address = row[1]?.value?.toString() ?? '';
      String description = row[4]?.value?.toString() ?? '';
      double latitude = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
      double longitude = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
      
      // 構建圖片路徑 - 這裡只是設置了一個路徑字符串，實際上需要上傳圖片
      String imageUrl = '$imagesPath/$name.png';
      
      try {
        // 上傳到 Appwrite - 使用命名空間來區分
        await set_db.database.createDocument(
          databaseId: set_db.databaseId,
          collectionId: set_db.collectionId,
          documentId: ID.unique(),
          data: {
            'Name': name,
            'Address': address,
            'Description': description,
            'latitude': latitude,
            'longitude': longitude,
            'Picture': imageUrl,
          },
        );
        
        print("已上傳景點: $name");
      } catch (e) {
        print("上傳景點 $name 時發生錯誤: $e");
      }
    }
    
    print("所有景點上傳完成");
  } catch (e) {
    print("處理 Excel 或上傳時發生錯誤: $e");
    rethrow; // 重新拋出異常，讓調用者知道發生了錯誤
  }
}