class Attraction {
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String description;
  final String imageUrl;

  Attraction({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.description,
    this.imageUrl = '',
  });
}