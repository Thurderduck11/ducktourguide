import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show navigatorKey;

class MarkerManager {
  final Set<String> visitedAttractions = {};
  final FlutterTts flutterTts = FlutterTts();

  bool _ttsInitialized = false;

  MarkerManager() {
    _initializeTts();
  }
  
  Future<void> _initializeTts() async {
    try {
      await _initTts();
      // 檢查TTS引擎是否可用
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var engines = await flutterTts.getEngines;
        if (engines.isEmpty) {
          print('沒有可用的TTS引擎，初始化失敗');
          _ttsInitialized = false;
          return;
        }
      }
      
      _ttsInitialized = true;
      print('TTS完全初始化完成');
    } catch (e) {
      _ttsInitialized = false;
      print('TTS初始化過程中發生錯誤: $e');
    }
  }

  Future<void> _initTts() async {
    try {
      // 檢查TTS引擎是否可用（僅在移動平台上）
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var available = await flutterTts.getEngines;
        if (available.isEmpty) {
          print('沒有可用的TTS引擎，請安裝TTS引擎');
          _showTtsInstallPrompt();
          return;
        }
        print('可用的TTS引擎: $available');
        
        // 嘗試選擇最佳的TTS引擎
        String preferredEngine = "";
        
        // 優先嘗試使用Google TTS引擎
        for (var engine in available) {
          if (engine.toString().toLowerCase().contains('google')) {
            preferredEngine = engine.toString();
            print('選擇Google TTS引擎: $preferredEngine');
            break;
          }
        }
        
        // 如果沒有找到Google TTS引擎，使用第一個可用的引擎
        if (preferredEngine.isEmpty && available.isNotEmpty) {
          preferredEngine = available.first.toString();
          print('選擇默認TTS引擎: $preferredEngine');
        }
        
        // 設置選擇的引擎
        if (preferredEngine.isNotEmpty) {
          try {
            await flutterTts.setEngine(preferredEngine);
            print('成功設置TTS引擎: $preferredEngine');
          } catch (e) {
            print('設置TTS引擎失敗: $e');
          }
        }
      }
      
      // 設置TTS引擎參數
      await flutterTts.setLanguage("zh-TW");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      
      // 檢查語言是否支持
      try {
        var languages = await flutterTts.getLanguages;
        print('支持的語言: $languages');
        
        // 檢查是否支持中文
        bool supportsChinese = false;
        for (var lang in languages) {
          if (lang.toString().toLowerCase().contains('zh') || 
              lang.toString().toLowerCase().contains('chi')) {
            supportsChinese = true;
            await flutterTts.setLanguage(lang.toString());
            print('設置中文語言: $lang');
            break;
          }
        }
        
        if (!supportsChinese) {
          print('警告：TTS引擎不支持中文，將使用默認語言');
        }
      } catch (e) {
        print('獲取支持語言失敗: $e');
      }
      
      // 根據平台設置特定參數
      if (!kIsWeb) {
        if (Platform.isIOS) {
          // iOS 特定設置
          await flutterTts.setSharedInstance(true);
          await flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.ambient,
            [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker]
          );
        } else if (Platform.isAndroid) {
          // Android 特定設置
          await flutterTts.setQueueMode(1); // 添加到隊列而不是立即打斷
        }
      }
      
      // 設置回調
      flutterTts.setCompletionHandler(() {
        print('TTS播放完成');
      });
      
      flutterTts.setErrorHandler((error) {
        print('TTS錯誤: $error');
      });
      
      flutterTts.setStartHandler(() {
        print('TTS開始播放');
      });
      
      print('TTS引擎初始化成功');
    } catch (e) {
      print('TTS初始化錯誤: $e');
      rethrow; // 重新拋出異常以便上層處理
    }
  }

  Future<void> playAudioDescription(String title, String description) async {
    // 檢查TTS是否初始化
    if (!_ttsInitialized) {
      print('TTS尚未初始化，嘗試重新初始化...');
      try {
        await _initializeTts();
        if (!_ttsInitialized) {
          print('TTS初始化失敗，無法播放音頻');
          _showTtsInstallPrompt();
          return;
        }
      } catch (e) {
        print('TTS初始化失敗，無法播放音頻: $e');
        _showTtsInstallPrompt();
        return;
      }
    }
    
    // 檢查TTS引擎是否可用（僅在移動平台上）
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        var engines = await flutterTts.getEngines;
        if (engines.isEmpty) {
          print('沒有可用的TTS引擎，無法播放音頻');
          _showTtsInstallPrompt();
          return;
        }
        
        // 檢查TTS狀態
        var status = await flutterTts.getMaxSpeechInputLength;
        if (status == null || status <= 0) {
          print('TTS引擎狀態異常，嘗試重新初始化...');
          await _initializeTts();
        }
      } catch (e) {
        print('檢查TTS引擎失敗: $e');
      }
    }
    
    // 構建要播放的文本
    String textToSpeak = "景點：$title。$description";
    print('開始播放景點描述: $title');
    print('播放文本: $textToSpeak');
    
    try {
      // 停止任何正在播放的語音
      await flutterTts.stop();
      
      // 嘗試播放
      int result = await flutterTts.speak(textToSpeak);
      
      if (result == 1) {
        print('TTS播放請求成功');
      } else {
        print('TTS播放請求失敗: $result');
        // 嘗試使用不同的方法播放
        await _tryAlternativeTtsMethod(textToSpeak);
      }
    } catch (e) {
      print("TTS 錯誤: $e");
      // 嘗試重新初始化TTS
      _ttsInitialized = false;
      await _initializeTts();
      // 嘗試使用替代方法播放
      await _tryAlternativeTtsMethod("景點：$title。$description");
    }
  }
  
  // 嘗試使用替代方法播放TTS
  Future<void> _tryAlternativeTtsMethod(String text) async {
    try {
      print('嘗試使用替代方法播放TTS...');
      // 重置TTS引擎
      await flutterTts.stop();
      
      // 嘗試使用不同的參數
      await flutterTts.setSpeechRate(0.4); // 降低語速
      await flutterTts.setPitch(1.0);
      
      // 檢查引擎狀態
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        var engines = await flutterTts.getEngines;
        if (engines.isEmpty) {
          print('替代方法：沒有可用的TTS引擎');
          _showTtsErrorMessage();
          return;
        }
        
        // 嘗試選擇不同的引擎（如果有多個）
        if (engines.length > 1) {
          for (var engine in engines) {
            if (engine.toString() != await flutterTts.getDefaultEngine) {
              try {
                await flutterTts.setEngine(engine.toString());
                print('嘗試使用替代引擎: $engine');
                break;
              } catch (e) {
                print('設置替代引擎失敗: $e');
              }
            }
          }
        }
      }
      
      // 嘗試分段播放
      List<String> segments = text.split('。');
      bool anySuccess = false;
      
      for (var segment in segments) {
        if (segment.trim().isNotEmpty) {
          print('播放分段: $segment');
          var result = await flutterTts.speak(segment);
          print('分段播放結果: $result');
          
          if (result == 1) {
            anySuccess = true;
            // 等待足夠長的時間讓TTS完成播放
            int waitTime = 500 + (segment.length * 100);
            await Future.delayed(Duration(milliseconds: waitTime));
          } else {
            // 如果播放失敗，嘗試更短的片段
            if (segment.length > 50) {
              List<String> subSegments = _splitIntoShorterSegments(segment);
              for (var subSegment in subSegments) {
                if (subSegment.trim().isNotEmpty) {
                  result = await flutterTts.speak(subSegment);
                  if (result == 1) {
                    anySuccess = true;
                    await Future.delayed(Duration(milliseconds: 500 + (subSegment.length * 100)));
                  }
                }
              }
            }
          }
        }
      }
      
      // 恢復原始設置
      await flutterTts.setSpeechRate(0.5);
      
      // 如果所有嘗試都失敗，顯示錯誤訊息
      if (!anySuccess) {
        _showTtsErrorMessage();
      }
    } catch (e) {
      print('替代TTS方法失敗: $e');
      _showTtsErrorMessage();
    }
  }
  
  // 將長文本分割成更短的片段
  List<String> _splitIntoShorterSegments(String text) {
    List<String> result = [];
    int maxLength = 30;
    
    if (text.length <= maxLength) {
      result.add(text);
      return result;
    }
    
    // 嘗試按標點符號分割
    List<String> byPunctuation = text.split(RegExp(r'[，,。.！!？?；;：:]'));
    
    for (var segment in byPunctuation) {
      if (segment.trim().isEmpty) continue;
      
      if (segment.length <= maxLength) {
        result.add(segment);
      } else {
        // 如果沒有標點符號或段落仍然太長，按字數分割
        int start = 0;
        while (start < segment.length) {
          int end = start + maxLength;
          if (end > segment.length) end = segment.length;
          result.add(segment.substring(start, end));
          start = end;
        }
      }
    }
    
    return result;
  }
  
  // 顯示TTS錯誤訊息
  void _showTtsErrorMessage() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('無法播放語音導覽，請檢查設備TTS設置'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '設置',
            onPressed: () {
              _openTtsSettings();
            },
          ),
        ),
      );
    }
  }
  
  // 顯示TTS引擎安裝提示
  void _showTtsInstallPrompt() {
    print('請安裝TTS引擎以啟用語音導覽功能');
    
    // 使用全局鍵來獲取當前上下文
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('TTS引擎不可用'),
            content: const Text('您的設備上沒有可用的文字轉語音引擎，需要安裝TTS引擎才能使用語音導覽功能。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openTtsSettings();
                },
                child: const Text('前往設置'),
              ),
            ],
          );
        },
      );
    } else {
      print('無法顯示TTS安裝提示對話框：context為null');
    }
  }
  
  // 打開TTS設置頁面
  Future<void> _openTtsSettings() async {
    // 嘗試打開TTS設置頁面
    if (Platform.isAndroid) {
      // Android平台打開TTS設置
      try {
        // 嘗試打開Android的TTS設置頁面
        final Uri url = Uri.parse('package:com.android.settings');
        bool canLaunch = await canLaunchUrl(url);
        
        if (canLaunch) {
          // 直接打開TTS設置頁面
          await launchUrl(
            Uri.parse('android-settings://com.android.settings.TTS_SETTINGS'),
            mode: LaunchMode.externalApplication,
          );
        } else {
          // 如果無法直接打開TTS設置，嘗試打開語言設置
          await launchUrl(
            Uri.parse('android-settings://com.android.settings.LOCALE_SETTINGS'),
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        print('無法打開TTS設置: $e');
        // 顯示手動設置指南
        _showManualSettingsGuide();
      }
    } else if (Platform.isIOS) {
      // iOS平台提示用戶手動打開設置
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('iOS設置'),
              content: const Text('請前往設置 > 輔助功能 > 語音內容 > 語音，確保已啟用語音功能並下載所需語言。'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('確定'),
                ),
              ],
            );
          },
        );
      }
    }
  }
  
  void _showManualSettingsGuide() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('手動設置TTS'),
            content: const Text(
              '請按照以下步驟手動設置TTS引擎：\n\n'
              '1. 打開設備的「設置」應用\n'
              '2. 前往「系統」>「語言和輸入法」\n'
              '3. 選擇「文字轉語音輸出」或「TTS輸出」\n'
              '4. 安裝或啟用Google文字轉語音引擎\n'
              '5. 下載所需的語言包（中文）'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('確定'),
              ),
            ],
          );
        },
      );
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