import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 語音服務介面 - 處理語音識別和合成
class VoiceService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('native_voice_service');
  
  // 備用 TTS 服務
  FlutterTts? _flutterTts;
  
  bool _isInitialized = false;
  bool _isWakeModeActive = false;
  bool _isCommandModeActive = false;
  bool _isSpeaking = false;
  
  // 語音指令回調
  Function(String)? _onVoiceCommand;
  Function(String)? _onVoiceError;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isWakeModeActive => _isWakeModeActive;
  bool get isCommandModeActive => _isCommandModeActive;
  bool get isSpeaking => _isSpeaking;
  
  /// 初始化語音服務
  Future<void> initialize() async {
    try {
      debugPrint('🎤 初始化語音服務...');
      
      // 初始化備用 TTS
      _flutterTts = FlutterTts();
      await _setupTts();
      
      _channel.setMethodCallHandler(_handleMethodCall);
      
      try {
        await _channel.invokeMethod('initialize');
        debugPrint('✅ 原生語音服務初始化成功');
      } catch (e) {
        debugPrint('⚠️ 原生語音服務不可用，使用備用 TTS: $e');
      }
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ 語音服務初始化完成');
      
      // TTS 現在已經完全初始化，可以直接說話
      await speak('語音服務已啟動');
      
    } catch (e) {
      debugPrint('❌ 語音服務初始化失敗: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// 設置 TTS 參數
  Future<void> _setupTts() async {
    if (_flutterTts == null) return;
    
    try {
      await _flutterTts!.setLanguage('zh-TW');
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setVolume(1.0);
      
      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      
      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _flutterTts!.setErrorHandler((msg) {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('TTS錯誤: $msg');
      });
    } catch (e) {
      debugPrint('TTS 設置失敗: $e');
    }
  }
  
  /// 設置語音指令回調
  void setVoiceCommandCallbacks({
    Function(String)? onCommand,
    Function(String)? onError,
  }) {
    _onVoiceCommand = onCommand;
    _onVoiceError = onError;
    debugPrint('語音指令回調已設置');
  }
  
  /// 啟動語音喚醒模式
  Future<void> startWakeMode() async {
    if (!_isInitialized) {
      debugPrint('❌ 語音服務尚未初始化');
      return;
    }
    
    try {
      debugPrint('🎤 啟動語音喚醒模式...');
      
      // 嘗試原生喚醒模式
      try {
        await _channel.invokeMethod('startWakeMode');
      } catch (e) {
        debugPrint('⚠️ 原生喚醒模式不可用: $e');
      }
      
      _isWakeModeActive = true;
      _isCommandModeActive = true; // 直接進入指令模式
      notifyListeners();
      
      debugPrint('✅ 語音喚醒模式已啟動，直接進入指令模式');
      await speak('語音服務已啟動，請說出您的指令');
      await _startListening();
      
    } catch (e) {
      debugPrint('❌ 啟動語音喚醒模式失敗: $e');
    }
  }
  
  /// 停止語音喚醒模式
  Future<void> stopWakeMode() async {
    try {
      debugPrint('🔇 停止語音喚醒模式');
      
      // 嘗試停止原生喚醒模式
      try {
        await _channel.invokeMethod('stopWakeMode');
      } catch (e) {
        debugPrint('⚠️ 停止原生喚醒模式失敗: $e');
      }
      
      _isWakeModeActive = false;
      _isCommandModeActive = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 停止語音喚醒模式失敗: $e');
    }
  }
  
  /// 開始語音監聽
  Future<void> _startListening() async {
    if (!_isWakeModeActive) return;
    
    try {
      debugPrint('🎤 開始語音監聽...');
      
      // 嘗試原生語音監聽
      try {
        await _channel.invokeMethod('startListening');
      } catch (e) {
        debugPrint('⚠️ 原生語音監聽不可用: $e');
        
        // 備用方案：提示用戶語音監聽不可用
        if (_flutterTts != null) {
          await _flutterTts!.speak('語音監聽功能暫時不可用');
        }
      }
    } catch (e) {
      debugPrint('❌ 開始語音監聽失敗: $e');
    }
  }
  
  /// 語音合成
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    try {
      debugPrint('🔊 語音合成: $text');
      
      // 嘗試原生服務
      try {
        await _channel.invokeMethod('speak', {'text': text});
        debugPrint('✅ 原生語音合成已啟動');
        return;
      } catch (e) {
        debugPrint('⚠️ 原生語音合成失敗，使用備用 TTS: $e');
        
        // 使用備用 TTS
        if (_flutterTts != null) {
          await _flutterTts!.speak(text);
          debugPrint('✅ 備用 TTS 已啟動');
        } else {
          debugPrint('❌ 備用 TTS 未初始化');
        }
      }
    } catch (e) {
      debugPrint('❌ 語音合成完全失敗: $e');
    }
  }
  
  /// 停止語音合成
  Future<void> stopSpeaking() async {
    try {
      // 嘗試停止原生服務
      try {
        await _channel.invokeMethod('stopSpeaking');
      } catch (e) {
        debugPrint('⚠️ 停止原生語音合成失敗: $e');
      }
      
      // 停止備用 TTS
      if (_flutterTts != null) {
        await _flutterTts!.stop();
        _isSpeaking = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ 停止語音合成失敗: $e');
    }
  }
  
  /// 處理原生方法調用
  Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('📱 收到原生方法調用: ${call.method}');
    
    switch (call.method) {
      case 'onSpeechResult':
        final String text = call.arguments['text'] ?? '';
        debugPrint('🎤 收到語音識別結果: $text');
        _processVoiceCommand(text);
        break;
        
      case 'onSpeechError':
        final String error = call.arguments['error'] ?? '';
        debugPrint('❌ 語音識別錯誤: $error');
        _onVoiceError?.call(error);
        break;
        
      case 'onSpeechEnd':
        debugPrint('🎤 語音識別結束');
        if (_isWakeModeActive) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _startListening();
        }
        break;
        
      case 'onTtsStart':
        debugPrint('🔊 開始語音合成');
        _isSpeaking = true;
        notifyListeners();
        break;
        
      case 'onTtsDone':
        debugPrint('🔊 語音合成完成');
        _isSpeaking = false;
        notifyListeners();
        break;
        
      default:
        debugPrint('❓ 未知的方法調用: ${call.method}');
    }
  }
  
  /// 處理語音指令
  void _processVoiceCommand(String text) {
    if (text.isEmpty) return;
    
    debugPrint('🔍 處理語音指令: $text');
    
    // 清理語音指令
    String cleanText = text.trim();
    debugPrint('🔍 清理後的語音指令: $cleanText');
    
    // 檢查是否為指令模式
    if (_isCommandModeActive) {
      debugPrint('🔍 在指令模式下處理指令: $cleanText');
      _processCommand(cleanText);
    }
  }
  
  /// 處理具體指令
  void _processCommand(String text) {
    debugPrint('🔍 處理語音指令: $text');
    
    // 定義指令映射
    final Map<String, String> commandMap = {
      '下一步': 'next',
      '下一頁': 'next',
      '上一步': 'previous',
      '上一頁': 'previous',
      '重複': 'repeat',
      '重複步驟': 'repeat',
    };
    
    // 優先匹配更長的指令
    String? matchedCommand;
    for (String key in commandMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length))) {
      if (text.contains(key)) {
        matchedCommand = commandMap[key];
        break;
      }
    }
    
    if (matchedCommand != null) {
      debugPrint('✅ 找到匹配指令: $text -> $matchedCommand');
      _onVoiceCommand?.call(matchedCommand);
    } else {
      debugPrint('❌ 未找到匹配的指令: $text');
    }
  }
  
  /// 手動觸發喚醒詞（用於測試）
  void simulateWakeWord(String wakeWord) {
    debugPrint('🎤 模擬喚醒詞: $wakeWord');
    _handleWakeWord(wakeWord);
  }
  
  /// 處理喚醒詞
  void _handleWakeWord(String wakeWord) {
    debugPrint('🔔 偵測到喚醒詞: $wakeWord');
    _isCommandModeActive = true;
    notifyListeners();
    
    speak('我在聽，請說出您的指令');
    _startListening();
  }
  
  /// 手動觸發喚醒詞
  void triggerWakeWord() {
    debugPrint('🎤 手動觸發喚醒詞: 嘿廚師');
    _handleWakeWord('嘿廚師');
  }
}
