import 'package:flutter/foundation.dart';
// import 'package:flutter_tts/flutter_tts.dart'; // 暫時註解掉

class FlutterTTSService {
  // FlutterTts? _flutterTts; // 暫時註解掉

  FlutterTTSService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 暫時註解掉 FlutterTts 初始化
      // _flutterTts = FlutterTts();
      // await _flutterTts!.setLanguage("zh-TW");
      // await _flutterTts!.setSpeechRate(0.5);
      // await _flutterTts!.setVolume(1.0);
      // await _flutterTts!.setPitch(1.0);
      debugPrint('Flutter TTS 服務初始化完成（模擬模式）');
    } catch (e) {
      debugPrint('Flutter TTS 初始化失敗: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      debugPrint('模擬語音合成: $text');
      // 暫時註解掉實際的語音合成
      // await _flutterTts?.speak(text);
    } catch (e) {
      debugPrint('模擬語音合成失敗: $e');
    }
  }

  Future<void> stop() async {
    try {
      debugPrint('停止語音合成（模擬模式）');
      // 暫時註解掉實際的停止功能
      // await _flutterTts?.stop();
    } catch (e) {
      debugPrint('停止語音合成失敗: $e');
    }
  }
}