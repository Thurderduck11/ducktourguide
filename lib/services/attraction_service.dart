import 'package:latlong2/latlong.dart';
import '../config/database.dart';
import '../models/attraction.dart';

class AttractionService {
  Future<List<Attraction>> fetchAttractions() async {
    try {
      final response = await database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );

      return response.documents.map((doc) {
        return Attraction(
          name: doc.data['Name'] ?? '',
          latitude: doc.data['latitude'] ?? 0.0,
          longitude: doc.data['longitude'] ?? 0.0,
          address: doc.data['Address'] ?? '',
          description: doc.data['Description'] ?? '',
          imageUrl: doc.data['Picture'] ?? '',
        );
      }).toList();
    } catch (e) {
      print("Failed to fetch attractions: $e");
      rethrow;
    }
  }
}