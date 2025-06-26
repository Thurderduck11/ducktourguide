import 'dart:io';

void main() {
  final directory = Directory('assets/img/attractions');
  final buffer = StringBuffer();

  buffer.writeln('name: ducktourguide');
  buffer.writeln('description: "A new Flutter project."');
  buffer.writeln('publish_to: \'none\'');
  buffer.writeln('version: 1.0.0+1');
  buffer.writeln('environment:');
  buffer.writeln('  sdk: ^3.5.4');
  buffer.writeln('dependencies:');
  buffer.writeln('  flutter:');
  buffer.writeln('    sdk: flutter');
  buffer.writeln('  cupertino_icons: ^1.0.8');
  buffer.writeln('  geolocator: ^13.0.2');
  buffer.writeln('  flutter_tts: ^4.2.2');
  buffer.writeln('  http: ^1.3.0');
  buffer.writeln('  flutter_map: ^8.1.0');  // 更新版本
  buffer.writeln('  latlong2: ^0.9.1');
  buffer.writeln('  geocoding: ^3.0.0');  // 更新版本
  buffer.writeln('  appwrite: ^14.0.0');
  buffer.writeln('  excel: ^4.0.6');  // 更新版本
  buffer.writeln('  flutter_web_auth_2: ^3.1.2');
  buffer.writeln('  flutter_local_notifications: ^17.2.1');  // 添加新依賴
  buffer.writeln('  shared_preferences: ^2.2.2');  // 添加新依賴
  buffer.writeln('dependency_overrides:');
  buffer.writeln('  flutter_web_auth_2: ^4.1.0');
  buffer.writeln('dev_dependencies:');
  buffer.writeln('  flutter_test:');
  buffer.writeln('    sdk: flutter');
  buffer.writeln('  flutter_lints: ^5.0.0');
  buffer.writeln('flutter:');
  buffer.writeln('  uses-material-design: true');
  buffer.writeln('  assets:');
  buffer.writeln('    - assets/img/attractions/');
  buffer.writeln('    - assets/data/attractions.xlsx');

  // 添加特定的圖片資源
  buffer.writeln('    - assets/img/attractions/模具工程系.png');
  buffer.writeln('    - assets/img/attractions/電子工程系.png');
  buffer.writeln('    - assets/img/attractions/高雄科技大學.png');

  // 動態添加其他圖片資源
  if (directory.existsSync()) {
    directory.listSync(recursive: true).forEach((file) {
      if (file is File && file.path.endsWith('.png')) {
        String path = file.path.replaceAll('\\', '/');
        // 避免重複添加已經手動添加的圖片
        if (!['assets/img/attractions/模具工程系.png', 
             'assets/img/attractions/電子工程系.png', 
             'assets/img/attractions/高雄科技大學.png'].contains(path)) {
          buffer.writeln('    - $path');
        }
      }
    });
  }

  final pubspecFile = File('pubspec.yaml');
  pubspecFile.writeAsStringSync(buffer.toString());
  print('pubspec.yaml file has been updated.');
}