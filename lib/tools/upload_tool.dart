import 'dart:io';
import 'package:excel/excel.dart';
import 'package:appwrite/appwrite.dart';

// 設置 Appwrite 客戶端
Client client = Client()
    .setEndpoint('https://cloud.appwrite.io/v1')
    .setProject('67c37669001b422e83e6')
    .setSelfSigned(status: true);

Databases database = Databases(client);
Storage storage = Storage(client);

// Appwrite 設定
const String bucketId = "67c4efcb0000f7348f23";
const String databaseId = "67c37890000902e1e89b";
const String collectionId = "67c378f40032f3b1b9df";
const String projectId = "67c37669001b422e83e6";

Future<List<Map<String, String>>> readExcelFile(String filePath, {String? sheetName}) async {
  try {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    List<Map<String, String>> locations = [];
    var sheet = sheetName != null && excel.tables.containsKey(sheetName)
        ? excel.tables[sheetName]
        : excel.tables[excel.tables.keys.first];

    if (sheet != null) {
      for (var row in sheet.rows.skip(1)) {
        var location = {
          'Name': row[1]?.value?.toString() ?? '',
          'Address': row[2]?.value?.toString() ?? '',
          'Description': row[5]?.value?.toString() ?? '',
          'latitude': row[4]?.value?.toString() ?? '',
          'longitude': row[3]?.value?.toString() ?? '',
        };
        print(location);
        if (location['Name']!.isNotEmpty && 
            location['latitude']!.isNotEmpty && 
            location['longitude']!.isNotEmpty) {
          locations.add(location);
          print('讀取到的資料: $location');
        }
      }
    }
    print('讀取 Excel 成功，共 ${locations.length} 條記錄');
    return locations;
  } catch (e) {
    print('讀取 Excel 失敗：$e');
    return [];
  }
}

Future<String?> uploadImageToAppwrite(String imagePath, String fileName) async {
  try {
    print('嘗試加載圖片: $imagePath');
    var imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      print('圖片文件不存在: $imagePath');
      return null;
    }
    
    final response = await storage.createFile(
      bucketId: bucketId,
      fileId: ID.unique(),
      file: InputFile.fromPath(path: imagePath, filename: "$fileName.png"),
    );

    String fileUrl = "https://cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${response.$id}/view?project=$projectId";
    print('圖片上傳成功: $fileUrl');
    return fileUrl;
  } catch (e) {
    print("圖片上傳失敗: $e");
    return null;
  }
}

Future<void> processExcelAndUpload(String excelPath, String imageFolderPath) async {
  List<Map<String, String>> locations = await readExcelFile(excelPath);

  for (var location in locations) {
    String name = location['Name'] ?? '';
    String address = location['Address'] ?? '';
    String latitude = location['latitude'] ?? '';
    String longitude = location['longitude'] ?? '';
    String description = location['Description'] ?? '';

    String imagePath = "$imageFolderPath/$name.png";
    String? imageUrl = await uploadImageToAppwrite(imagePath, name);

    if (imageUrl == null) {
      print("圖片 $imagePath 上傳失敗，跳過此景點");
      continue;
    }

    await database.createDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: {
        'Name': name,
        'Address': address,
        'latitude': double.parse(latitude),
        'longitude': double.parse(longitude),
        'Description': description,
        'Picture': imageUrl,
      },
    );

    print("成功上傳景點: $name, 圖片 URL: $imageUrl");
  }
}

void main() async {
  // 使用絕對路徑
  String excelPath = "C:\\Users\\dydy1\\studioprojects\\ducktourguide\\assets\\data\\attractions.xlsx";
  String imageFolderPath = "C:\\Users\\dydy1\\studioprojects\\ducktourguide\\assets\\img\\attractions";
  
  await processExcelAndUpload(excelPath, imageFolderPath);
  exit(0); // 確保程序結束
}