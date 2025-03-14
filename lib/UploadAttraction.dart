import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:appwrite/appwrite.dart';
import 'package:ducktourguide/SetDataBase.dart';

Future<List<Map<String, String>>> readExcelFile(String assetPath, {String? sheetName}) async {
  try {
    ByteData data = await rootBundle.load(assetPath);
    var bytes = data.buffer.asUint8List();
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
          'longitude': row[4]?.value?.toString() ?? '',
          'latitude': row[3]?.value?.toString() ?? '',
          'Description': row[5]?.value?.toString() ?? '',
        };
        locations.add(location);
        print('讀取到的資料: $location');
      }
    }
    print('讀取 Excel 成功');
    return locations;
  } catch (e) {
    print('讀取 Excel 失敗：$e');
    return [];
  }
}

Future<String?> uploadImageToAppwrite(String assetPath) async {
  try {
    ByteData byteData = await rootBundle.load(assetPath);
    Uint8List imageBytes = byteData.buffer.asUint8List();

    final response = await storage.createFile(
      bucketId: bucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: imageBytes, filename: "image.jpg"),
    );

    return "https://cloud.appwrite.io/v1/storage/buckets/$bucketId/files/${response.$id}/view?project=$projectId";
  } catch (e) {
    print("圖片上傳失敗: $e");
    return null;
  }
}

// **讀取 Excel 並上傳圖片 + 存入 Appwrite Database**
Future<void> processExcelAndUpload(String excelPath, String imageFolderPath) async {
  List<Map<String, String>> locations = await readExcelFile(excelPath);

  for (var location in locations) {
    String name = location['Name'] ?? '';
    String Address  = location['Address'] ?? '';
    String latitude = location['latitude'] ?? '';
    String longitude = location['longitude'] ?? '';
    String Description = location['Description'] ?? '';

    if (name.isEmpty || latitude.isEmpty || longitude.isEmpty) {
      print("忽略無效的資料: $location");
      continue;
    }

    String imagePath = "$imageFolderPath/$name.png"; // 假設圖片命名與景點名稱相同
    String? imageUrl = await uploadImageToAppwrite(imagePath);

    if (imageUrl == null) {
      print("圖片 $imagePath 上傳失敗，跳過此景點");
      continue;
    }

    // 上傳景點資訊到 Appwrite Database
    await database.createDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: {
        'Name': name,
        'Address': Address,
        'latitude': double.parse(latitude),
        'longitude': double.parse(longitude),
        'Description': Description,
        'Picture': imageUrl,
      },
    );

    print("成功上傳景點: $name, 圖片 URL: $imageUrl");
  }
}

void main() async {
  await processExcelAndUpload("assets/data/attractions.xlsx", "assets/img/attractions");
}
