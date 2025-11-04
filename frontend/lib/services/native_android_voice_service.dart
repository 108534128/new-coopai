import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAndroidVoiceService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isWakeModeActive = false; // 語音控制模式是否啟用 (持續監聽喚醒詞)
  bool _isCommandModeActive = false; // 是否已喚醒，正在等待指令
  
  // MethodChannel 用於與原生 Android 通信
  static const MethodChannel _channel = MethodChannel('native_voice_service');
  
  // 語音指令回調
  Function(String)? _onVoiceCommand;
  Function(String)? _onVoiceError;
  
  // 喚醒詞（更寬鬆的匹配）
  final List<String> _wakeWords = [
    '嘿廚師',
    '廚師助手', 
    '開始烹飪',
    '語音助手',
    '嘿 cookpal',
    'cookpal',
    // 添加更多可能的發音變體
    '黑廚師',    // 您說的「黑廚師」
    '配廚師',    // 您說的「配廚師」
    '嘿廚師助手',
    '廚師',
    '助手',
    'cookpal助手',
    '語音',
    '開始',
    '烹飪'
  ];
  
  // 支援的指令
  final Map<String, String> _commands = {
    '下一頁': 'next',
    '下一步': 'next',
    '上一頁': 'previous',
    '上一步': 'previous',
    '重複': 'repeat',
    '再說一次': 'repeat',
    '停止': 'stop',
    '暫停': 'stop',
    '繼續': 'continue',
    '完成': 'finish',
  };

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isWakeModeActive => _isWakeModeActive;
  bool get isCommandModeActive => _isCommandModeActive;

  NativeAndroidVoiceService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      debugPrint('🎤 初始化原生 Android 語音服務...');
      
      // 設置 MethodChannel 回調
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // 嘗試初始化原生語音服務
      try {
        await _channel.invokeMethod('initialize');
        debugPrint('✅ 原生 Android 語音服務初始化成功');
        
        // 等待 TTS 初始化完成
        debugPrint('⏳ 等待語音合成初始化完成...');
        await Future.delayed(const Duration(milliseconds: 3000));
        debugPrint('✅ 語音合成初始化等待完成');
        
      } catch (e) {
        debugPrint('❌ 原生 Android 語音服務初始化失敗: $e');
      }
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ 原生 Android 語音服務初始化完成');
      await speak('語音服務已啟動，請說出喚醒詞開始');
      
    } catch (e) {
      debugPrint('❌ 語音服務初始化失敗: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  // 處理來自原生 Android 的方法調用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
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
        
        // 如果是客戶端錯誤或沒有匹配，重新開始監聽
        if (error.contains('客戶端錯誤') || error.contains('沒有匹配結果')) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_isWakeModeActive) {
              _startListening();
            }
          });
        }
        break;
        
      case 'onSpeechEnd':
        debugPrint('🎤 語音識別結束');
        _isListening = false;
        notifyListeners();
        
        // 如果還在喚醒模式，重新開始監聽
        if (_isWakeModeActive) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _startListening();
          });
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
        
      case 'onTtsError':
        final String error = call.arguments['error'] ?? '';
        debugPrint('🔊 語音合成錯誤: $error');
        _isSpeaking = false;
        notifyListeners();
        break;
        
      default:
        debugPrint('❓ 未知的方法調用: ${call.method}');
    }
  }

  // 設置語音指令回調
  void setVoiceCommandCallbacks({
    required Function(String) onCommand,
    required Function(String) onError,
  }) {
    _onVoiceCommand = onCommand;
    _onVoiceError = onError;
    debugPrint('語音指令回調已設置');
  }

  // 啟動語音喚醒模式
  Future<void> startWakeMode() async {
    if (!_isInitialized) {
      debugPrint('語音服務尚未初始化');
      return;
    }

    try {
      debugPrint('🎤 啟動原生 Android 語音喚醒模式...');
      _isWakeModeActive = true;
      _isCommandModeActive = false; // 重置為等待喚醒詞狀態
      notifyListeners();
      
      debugPrint('✅ 原生 Android 語音喚醒模式已啟動，等待喚醒詞...');
      await speak('語音服務已啟動，請說出喚醒詞開始');
      
      // 開始監聽
      _startListening();
      
    } catch (e) {
      debugPrint('啟動語音喚醒模式失敗: $e');
    }
  }

  // 停止語音喚醒模式
  Future<void> stopWakeMode() async {
    try {
      debugPrint('🔇 停止語音喚醒模式');
      _isWakeModeActive = false;
      _isCommandModeActive = false;
      _isListening = false;
      notifyListeners();
      
      // 停止原生語音識別
      try {
        await _channel.invokeMethod('stopListening');
      } catch (e) {
        debugPrint('停止原生語音識別失敗: $e');
      }
      
    } catch (e) {
      debugPrint('停止語音喚醒模式失敗: $e');
    }
  }

  // 開始監聽語音
  Future<void> _startListening() async {
    if (!_isWakeModeActive) return;
    
    try {
      debugPrint('🎤 開始原生 Android 語音監聽...');
      
      // 嘗試使用原生語音識別
      try {
        await _channel.invokeMethod('startListening');
        debugPrint('✅ 原生語音識別已啟動');
        _isListening = true;
        notifyListeners();
      } catch (e) {
        debugPrint('❌ 原生語音識別失敗: $e');
        // 不要回退到模擬模式，讓用戶知道需要修復原生實現
        _isListening = false;
        notifyListeners();
        throw e; // 重新拋出錯誤，讓調用者知道失敗了
      }
      
    } catch (e) {
      debugPrint('開始語音監聽失敗: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  // 模擬語音輸入（僅在原生不可用時使用）
  void _simulateVoiceInput() {
    debugPrint('🎤 使用模擬語音輸入模式');
    // 這裡不自動模擬，只等待用戶手動觸發
  }

  // 手動觸發語音指令（用於測試）
  void simulateVoiceCommand(String command) {
    debugPrint('🎤 手動觸發語音指令: $command');
    _processVoiceCommand(command);
  }

  // 手動觸發喚醒詞（用於測試）
  void simulateWakeWord(String wakeWord) {
    debugPrint('🎤 手動觸發喚醒詞: $wakeWord');
    _handleWakeWord();
  }

  // 處理語音指令
  void _processVoiceCommand(String text) {
    debugPrint('🔍 處理語音指令: $text');
    
    // 清理語音識別結果，移除多餘的文字
    String cleanedText = _cleanVoiceResult(text);
    debugPrint('🔍 清理後的語音指令: $cleanedText');
    
    final lowerText = cleanedText.toLowerCase();
    
    // 檢查是否為喚醒詞
    if (_isWakeWord(lowerText)) {
      debugPrint('🔔 偵測到喚醒詞！');
      _handleWakeWord();
    } else if (_isWakeModeActive && _isCommandModeActive) {
      // 只有在喚醒模式下且已進入指令模式才處理指令
      debugPrint('🔍 在喚醒模式下處理指令: $lowerText');
      _processCommand(lowerText);
    } else {
      debugPrint('🔍 非喚醒模式或未進入指令模式，忽略指令: $lowerText');
      // 如果不在指令模式，但收到了語音，重新開始監聽喚醒詞
      if (_isWakeModeActive) {
        Future.delayed(const Duration(milliseconds: 500), () {
          debugPrint('🔄 忽略指令後，重新開始監聽喚醒詞');
          _startListening();
        });
      }
    }
  }

  // 清理語音識別結果
  String _cleanVoiceResult(String text) {
    // 移除常見的多餘文字
    String cleaned = text;
    
    // 移除系統提示文字
    cleaned = cleaned.replaceAll('請說出你的指令', '');
    cleaned = cleaned.replaceAll('請說出您的指令', '');
    cleaned = cleaned.replaceAll('說出你的指令', '');
    cleaned = cleaned.replaceAll('說出您的指令', '');
    cleaned = cleaned.replaceAll('你的指令', '');
    cleaned = cleaned.replaceAll('您的指令', '');
    cleaned = cleaned.replaceAll('指令', '');
    
    // 移除多餘的空白和標點
    cleaned = cleaned.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned;
  }

  // 檢查是否為喚醒詞（更智能的匹配）
  bool _isWakeWord(String text) {
    final lowerText = text.toLowerCase().trim();

    // 直接匹配
    for (var wakeWord in _wakeWords) {
      if (lowerText.contains(wakeWord.toLowerCase())) {
        debugPrint('🔔 直接匹配到喚醒詞: $wakeWord');
        return true;
      }
    }

    // 模糊匹配（處理發音相似的情況）
    final fuzzyMatches = [
      {'嘿廚師', '黑廚師', '配廚師', '嘿廚師助手'},
      {'廚師助手', '廚師', '助手'},
      {'開始烹飪', '開始', '烹飪'},
      {'語音助手', '語音', '助手'},
      {'cookpal', 'cook pal', 'cookpal助手'}
    ];

    for (var group in fuzzyMatches) {
      for (var word in group) {
        if (lowerText.contains(word.toLowerCase())) {
          debugPrint('🔔 模糊匹配到喚醒詞: $word (組: ${group.join(', ')})');
          return true;
        }
      }
    }
    
    return false;
  }

  // 處理喚醒詞
  Future<void> _handleWakeWord() async {
    _isCommandModeActive = true; // 進入指令模式
    notifyListeners();
    debugPrint('🔔 喚醒詞被觸發！開始持續監聽模式');
    await speak('我在聽，請說出您的指令');
    
    // 短暫延遲後重新開始監聽
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_isWakeModeActive) {
      debugPrint('🔄 重新啟動語音識別進行持續監聽');
      _startListening();
    }
  }

  // 處理語音指令
  void _processCommand(String text) {
    debugPrint('🔍 處理語音指令: $text');
    
    // 尋找匹配的指令
    for (final entry in _commands.entries) {
      if (text.contains(entry.key.toLowerCase())) {
        debugPrint('✅ 找到匹配指令: ${entry.key} -> ${entry.value}');
        
        // 語音回應指令
        _speakCommandResponse(entry.key, entry.value);
        
        _onVoiceCommand?.call(entry.value);
        
        // 執行指令後，短暫延遲再重新開始監聽
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (_isWakeModeActive) {
            debugPrint('🔄 指令執行完成，重新開始監聽');
            _startListening();
          }
        });
        return;
      }
    }
    
    debugPrint('❓ 未識別的指令: $text');
    speak('我沒有聽懂，請再說一次');
    
    // 未識別指令後，短暫延遲再重新開始監聽
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (_isWakeModeActive) {
        debugPrint('🔄 未識別指令後，重新開始監聽');
        _startListening();
      }
    });
  }

  // 語音回應指令
  void _speakCommandResponse(String command, String action) {
    String response = '';
    
    switch (action) {
      case 'next':
        response = '好的，執行下一步';
        break;
      case 'previous':
        response = '好的，執行上一步';
        break;
      case 'repeat':
        response = '好的，重複當前步驟';
        break;
      case 'stop':
        response = '好的，停止語音播放';
        break;
      case 'continue':
        response = '好的，繼續烹飪';
        break;
      case 'finish':
        response = '好的，烹飪完成';
        break;
      default:
        response = '好的，執行指令';
    }
    
    speak(response);
  }

  // 語音合成（使用原生 Android TextToSpeech）
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    try {
      debugPrint('🔊 原生 Android 語音合成: $text');
      
      // 使用原生 TextToSpeech
      await _channel.invokeMethod('speak', {'text': text});
      debugPrint('✅ 原生語音合成已啟動');
      
    } catch (e) {
      debugPrint('❌ 原生語音合成失敗: $e');
    }
  }

  // 模擬語音合成
  void _simulateSpeech(String text) {
    debugPrint('🔊 模擬語音合成: $text');
    
    // 模擬語音播放時間
    final duration = Duration(milliseconds: (text.length * 80).clamp(500, 3000));
    
    _isSpeaking = true;
    notifyListeners();
    
    Future.delayed(duration, () {
      _isSpeaking = false;
      notifyListeners();
      debugPrint('🔊 模擬語音合成完成: $text');
    });
  }

  // 停止語音合成
  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
      debugPrint('停止語音播放');
      
      // 停止語音後，重新開始監聽
      if (_isWakeModeActive) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          debugPrint('🔄 停止語音後，重新開始監聽');
          _startListening();
        });
      }
    } catch (e) {
      debugPrint('停止語音合成失敗: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
