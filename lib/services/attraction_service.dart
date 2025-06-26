import 'package:latlong2/latlong.dart';
import '../config/database.dart';
import '../models/attraction.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class AttractionService {
  Future<List<Attraction>> fetchAttractions() async {
    try {
      final response = await database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );

      return response.documents.map((doc) {
        return Attraction(
          id: doc.$id, // 保存Document ID
          name: doc.data['Name'] ?? '',
          latitude: doc.data['latitude'] ?? 0.0,
          longitude: doc.data['longitude'] ?? 0.0,
          address: doc.data['Address'] ?? '',
          description: doc.data['Description'] ?? '',
          imageUrl: doc.data['Picture'] ?? '',
          stayDuration: doc.data['stayDuration'] ?? 60,
        );
      }).toList();
    } catch (e) {
      print("Failed to fetch attractions: $e");
      rethrow;
    }
  }
  
  // 根據ID獲取單個景點
  Future<Attraction?> getAttractionById(String attractionId) async {
    try {
      final doc = await database.getDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: attractionId,
      );
      
      return Attraction(
        id: doc.$id,
        name: doc.data['Name'] ?? '',
        latitude: doc.data['latitude'] ?? 0.0,
        longitude: doc.data['longitude'] ?? 0.0,
        address: doc.data['Address'] ?? '',
        description: doc.data['Description'] ?? '',
        imageUrl: doc.data['Picture'] ?? '',
        stayDuration: doc.data['stayDuration'] ?? 60,
      );
    } catch (e) {
      print("Failed to get attraction by ID: $e");
      return null;
    }
  }
}