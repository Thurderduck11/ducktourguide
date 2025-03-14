import 'package:excel/excel.dart';
import 'dart:io';
import '../config/database.dart';

Future<void> processExcelAndUpload(String excelPath, String imagesPath) async {
  try {
    // 讀取 Excel 檔案
    var bytes = File(excelPath).readAsBytesSync();
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
      
      // 假設列的順序是：Name, Address, Description, Latitude, Longitude
      String name = row[0]?.value?.toString() ?? '';
      String address = row[1]?.value?.toString() ?? '';
      String description = row[2]?.value?.toString() ?? '';
      double latitude = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
      double longitude = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
      
      // 構建圖片路徑
      String imageUrl = '$imagesPath/$name.jpg';
      
      // 上傳到 Appwrite
      await database.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: 'unique()',
        data: {
          'Name': name,
          'Address': address,
          'Description': description,
          'latitude': latitude,
          'longitude': longitude,
          'imageUrl': imageUrl,
        },
      );
      
      print("已上傳景點: $name");
    }
    
    print("所有景點上傳完成");
  } catch (e) {
    print("處理 Excel 或上傳時發生錯誤: $e");
  }
}