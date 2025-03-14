import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'UploadAttraction.dart';
import 'package:ducktourguide/SetDataBase.dart';
import 'Marker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = LatLng(22.6518, 120.3285);
  double _currentZoom = 15.0;
  StreamSubscription<Position>? _positionStream;
  String _currentAddress = "正在獲取地址...";
  final MarkerManager _markerManager = MarkerManager();
  List<Map<String, dynamic>> _markersData = [];

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _fetchMarkersData();
    _scheduleDailyReset();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    var locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _mapController.move(_currentLocation, _currentZoom);
        });
        _currentAddress = await _getAddressFromLatLng(position);
        setState(() {});
        _checkNearbyAttractions();
      },
      onError: (error) {
        print("GPS 錯誤: $error");
      },
    );
  }

  Future<String> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return "${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
      }
    } catch (e) {
      print("獲取地址錯誤: $e");
    }
    return "無法獲取地址";
  }

  Future<void> _fetchMarkersData() async {
    try {
      final response = await database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );

      setState(() {
        _markersData = response.documents.map((doc) {
          return {
            'point': LatLng(doc.data['latitude'], doc.data['longitude']),
            'title': doc.data['Name'],
            'address': doc.data['Address'],
            'description': doc.data['Description'],
            'imageUrl': doc.data['Picture'],
            'color': Colors.red,
            'visited': false,
          };
        }).toList();
      });
    } catch (e) {
      print("Failed to fetch marker data: $e");
    }
  }

  Future<void> _checkNearbyAttractions() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    double userLat = position.latitude;
    double userLng = position.longitude;

    print("Current Position: Latitude: $userLat, Longitude: $userLng");

    bool foundAttraction = false;

    for (var data in _markersData) {
      double attractionLat = data['point'].latitude;
      double attractionLng = data['point'].longitude;
      String attractionName = data['title'];
      String description = data['description'];

      double distance = Geolocator.distanceBetween(
        userLat, userLng, attractionLat, attractionLng,
      );

      print("Checking attraction: $attractionName, Distance: $distance meters");

      if (distance <= 50 && !_markerManager.visitedAttractions.contains(attractionName)) {
        print("接近景點： $attractionName ($distance 公尺)");
        await _markerManager.playAudioDescription(attractionName, description);
        _markerManager.visitedAttractions.add(attractionName);
        foundAttraction = true;

        setState(() {
          _markersData = _markersData.map((data) {
            if (data['title'] == attractionName) {
              data['visited'] = true;
            }
            return data;
          }).toList();
        });
        break;
      }
    }
    if (!foundAttraction) {
      print("未找到附近的景點");
    }
  }

  void _scheduleDailyReset() {
    final now = DateTime.now();
    var nextReset = DateTime(now.year, now.month, now.day, 5);

    if (now.isAfter(nextReset)) {
      nextReset = nextReset.add(Duration(days: 1));
    }

    final durationUntilReset = nextReset.difference(now);

    Timer(durationUntilReset, () {
      _markerManager.visitedAttractions.clear();
      setState(() {
        _markersData = _markersData.map((data) {
          data['visited'] = false;
          return data;
        }).toList();
      });
      print("Visited attractions list has been reset.");
      _scheduleDailyReset();
    });
  }

  void _showLocationInfo(String title, String address, String description, String imageUrl, Color color) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                child: Container(
                                  width: 405, // Adjust the width here
                                  height: 305, // Adjust the height here
                                  padding: const EdgeInsets.all(16.0),
                                  child: Image.network(
                                    imageUrl,
                                    width: 400, // Adjust the width of the image here
                                    height: 300,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: Icon(Icons.volume_up, color: Colors.blue, size: 40.0),
                        onPressed: () {
                          _markerManager.playAudioDescription(title, description);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "簡介",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("景點Map")),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    _markerManager.createMarker({
                      'point': _currentLocation,
                      'title': "目前位置",
                      'address': _currentAddress,
                      'description': "這是你目前的位置。",
                      'imageUrl': "",
                      'color': Colors.blue,
                      'visited': false,
                    }, _showLocationInfo),
                    ..._markersData.map((data) => _markerManager.createMarker(data, _showLocationInfo)).toList(),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await processExcelAndUpload("assets/data/attractions.xlsx", "assets/img/attractions");
              await _fetchMarkersData();
              setState(() {});
            },
            child: Text("測試 UploadAttraction"),
          ),
        ],
      ),
    );
  }
}