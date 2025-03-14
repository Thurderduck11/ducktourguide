import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class MarkerManager {
  final Set<String> visitedAttractions = {};
  final FlutterTts flutterTts = FlutterTts();

  MarkerManager() {
    _initTts();
  }

  void _initTts() async {
    await flutterTts.setLanguage("zh-TW");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> playAudioDescription(String title, String description) async {
    try {
      await flutterTts.speak("景點：$title。$description");
    } catch (e) {
      print("TTS 錯誤: $e");
    }
  }

  Marker createMarker(Map<String, dynamic> data, Function showInfoCallback) {
    final bool visited = data['visited'] ?? false;
    final Color markerColor = visited ? Colors.green : (data['color'] ?? Colors.red);
    
    return Marker(
      point: data['point'],
      width: 80.0,
      height: 80.0,
      child: GestureDetector(
        onTap: () {
          showInfoCallback(
            data['title'],
            data['address'],
            data['description'],
            data['imageUrl'] ?? '',
            markerColor,
          );
        },
        child: Column(
          children: [
            Icon(
              visited ? Icons.check_circle : Icons.location_on,
              color: markerColor,
              size: 30.0,
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data['title'],
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}