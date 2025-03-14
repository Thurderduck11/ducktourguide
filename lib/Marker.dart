import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'SetDataBase.dart';

class MarkerManager {
  final FlutterTts flutterTts = FlutterTts();
  final Set<String> visitedAttractions = <String>{};
  List<Map<String, dynamic>> markersData = [];

  Future<void> fetchMarkersData() async {
    try {
      final response = await database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );

      markersData = response.documents.map((doc) {
        return {
          'point': LatLng(doc.data['latitude'], doc.data['longitude']),
          'title': doc.data['Name'],
          'address': doc.data['Address'],
          'description': doc.data['Description'],
          'imageUrl': doc.data['Picture'],
          'color': Colors.red, // Default color
          'visited': false, // New property to track if the marker is visited
        };
      }).toList();
    } catch (e) {
      print("Failed to fetch marker data: $e");
    }
  }

  Marker createMarker(Map<String, dynamic> data, Function(String, String, String, String, Color) showLocationInfo) {
    return Marker(
      point: data['point'],
      width: 50,
      height: 50,
      child: GestureDetector(
        onTap: () => showLocationInfo(data['title'], data['address'], data['description'],data['imageUrl'], data['color']),
        child: Icon(Icons.location_on, color: data['visited'] ? Colors.green : data['color'], size: 40.0),
      ),
    );
  }

  Future<void> checkNearbyAttractions(Function setState) async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    double userLat = position.latitude;
    double userLng = position.longitude;

    print("Current Position: Latitude: $userLat, Longitude: $userLng");

    final response = await database.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
    );

    bool foundAttraction = false;

    for (var doc in response.documents) {
      double attractionLat = doc.data["latitude"];
      double attractionLng = doc.data["longitude"];
      String attractionName = doc.data["Name"];
      String description = doc.data["Description"];

      double distance = Geolocator.distanceBetween(
        userLat, userLng, attractionLat, attractionLng,
      );

      print("Checking attraction: $attractionName, Distance: $distance meters");

      if (distance <= 50 && !visitedAttractions.contains(attractionName)) {
        print("接近景點： $attractionName ($distance 公尺)");
        await playAudioDescription(attractionName, description);
        visitedAttractions.add(attractionName);
        foundAttraction = true;

        setState(() {
          markersData = markersData.map((data) {
            if (data['title'] == attractionName) {
              data['visited'] = true;
            }
            return data;
          }).toList();
        });
        break; // Avoid playing multiple attractions' audio
      }
    }
    if (!foundAttraction) {
      print("未找到附近的景點");
    }
  }

  Future<void> playAudioDescription(String name, String description) async {
    String text = "在你的附近發現一個景點，$name，以下是他的介紹，$description";
    await flutterTts.speak(text);
  }

  void scheduleDailyReset(Function setState) {
    final now = DateTime.now();
    var nextReset = DateTime(now.year, now.month, now.day, 5); // Today at 5 AM

    // If the current time is past 5 AM, set the reset time to 5 AM the next day
    if (now.isAfter(nextReset)) {
      nextReset = nextReset.add(Duration(days: 1));
    }

    final durationUntilReset = nextReset.difference(now);

    Timer(durationUntilReset, () {
      visitedAttractions.clear();
      setState(() {
        markersData = markersData.map((data) {
          data['visited'] = false;
          return data;
        }).toList();
      });
      print("Visited attractions list has been reset.");
      scheduleDailyReset(setState); // Schedule the next reset
    });
  }
}