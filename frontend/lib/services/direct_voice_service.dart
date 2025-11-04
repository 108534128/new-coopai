import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// 直接使用 Native Android 和 Flutter TTS 的語音服務
class DirectVoiceService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('native_voice_service');
  
  FlutterTts? _flutterTts;
  SpeechToText? _speechToText;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isWakeModeActive = false;
  bool _isCommandModeActive = false;
  
  // 回調函數
  Function(String)? _onVoiceCommand;
  Function(String)? _onVoiceError;
  
  // Getter
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get isWakeModeActive => _isWakeModeActive;
  bool get isCommandModeActive => _isCommandModeActive;
  
  /// 初始化服務
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🚀 DirectVoiceService 初始化開始...');
    
    try {
      // 1. 初始化 Flutter TTS
      await _initializeFlutterTts();
      
      // 2. 初始化 Speech to Text
      await _initializeSpeechToText();
      
      // 3. 設置 Native Android Voice 回調
      _setupNativeCallbacks();
      
      _isInitialized = true;
      debugPrint('✅ DirectVoiceService 初始化完成');
      
      // 測試 TTS
      await testTts();
      
    } catch (e) {
      debugPrint('❌ DirectVoiceService 初始化失敗: $e');
      _isInitialized = false;
    }
    
    notifyListeners();
  }
  
  /// 初始化 Flutter TTS
  Future<void> _initializeFlutterTts() async {
    try {
      debugPrint('🔧 初始化 Flutter TTS...');
      _flutterTts = FlutterTts();
      
      // 設置語言
      List<dynamic> languages = await _flutterTts!.getLanguages;
      debugPrint('📋 可用語言: $languages');
      
      // 嘗試設置中文
      bool langSet = false;
      for (String lang in ['zh-TW', 'zh-CN', 'zh', 'en-US']) {
        try {
          await _flutterTts!.setLanguage(lang);
          debugPrint('✅ 成功設置語言: $lang');
          langSet = true;
          break;
        } catch (e) {
          debugPrint('⚠️ 無法設置語言 $lang: $e');
        }
      }
      
      if (!langSet) {
        debugPrint('⚠️ 無法設置中文，使用默認語言');
      }
      
      // 設置 TTS 參數
      await _flutterTts!.setSpeechRate(0.6);
      await _flutterTts!.setVolume(0.8);
      await _flutterTts!.setPitch(1.0);
      
      // 設置事件監聽
      _flutterTts!.setStartHandler(() {
        debugPrint('🎙️ TTS 開始播放');
        _isSpeaking = true;
        notifyListeners();
      });
      
      _flutterTts!.setCompletionHandler(() {
        debugPrint('🏁 TTS 播放完成');
        _isSpeaking = false;
        notifyListeners();
      });
      
      _flutterTts!.setErrorHandler((msg) {
        debugPrint('💥 TTS 錯誤: $msg');
        _isSpeaking = false;
        notifyListeners();
      });
      
      debugPrint('🎉 Flutter TTS 初始化成功');
      
    } catch (e) {
      debugPrint('❌ Flutter TTS 初始化失敗: $e');
      rethrow;
    }
  }
  
  /// 初始化 Speech to Text
  Future<void> _initializeSpeechToText() async {
    try {
      debugPrint('🎤 初始化 Speech to Text...');
      _speechToText = SpeechToText();
      
      bool? available = await _speechToText!.initialize(
        onError: (val) {
          debugPrint('❌ STT 錯誤: $val');
          if (_onVoiceError != null) {
            _onVoiceError!('語音識別錯誤: ${val.errorMsg}');
          }
        },
        onStatus: (val) {
          debugPrint('📊 STT 狀態: $val');
          _isListening = val == 'listening';
          notifyListeners();
          
          // 在喚醒模式下，當監聽狀態變為 notListening 時自動重新開始
          if (val == 'notListening' && _isWakeModeActive) {
            debugPrint('🔄 喚醒模式：監聽結束，準備重新啟動...');
            
            // 短暫延遲後重新啟動監聽
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (_isWakeModeActive && !_speechToText!.isListening) {
                debugPrint('🎤 重新啟動持續監聽...');
                _startContinuousListening();
              }
            });
          }
          
          // 處理 done 狀態，確保在完成後重新監聽
          if (val == 'done' && _isWakeModeActive) {
            debugPrint('� 語音識別完成，準備重新開始監聽...');
            
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (_isWakeModeActive && !_speechToText!.isListening) {
                debugPrint('🔄 識別完成後重新啟動監聽...');
                _startContinuousListening();
              }
            });
          }
        },
      );
      
      if (available == true) {
        debugPrint('✅ Speech to Text 初始化成功');
      } else {
        debugPrint('⚠️ Speech to Text 不可用 (available: $available)');
      }
      
    } catch (e) {
      debugPrint('❌ Speech to Text 初始化失敗: $e');
      // 不要重新拋出異常，讓 TTS 功能仍然可用
    }
  }
  
  /// 設置原生語音服務回調
  void _setupNativeCallbacks() {
    _channel.setMethodCallHandler((call) async {
      debugPrint('📱 收到原生回調: ${call.method}');
      
      switch (call.method) {
        case 'onSpeechResult':
          final text = call.arguments['text'] as String?;
          if (text != null && text.isNotEmpty) {
            debugPrint('🎤 語音識別結果: $text');
            _onVoiceCommand?.call(text);
          }
          break;
          
        case 'onSpeechError':
          final error = call.arguments['error'] as String?;
          if (error != null) {
            debugPrint('❌ 語音識別錯誤: $error');
            _onVoiceError?.call(error);
          }
          break;
          
        case 'onSpeechEnd':
          debugPrint('🎤 語音識別結束');
          _isListening = false;
          notifyListeners();
          break;
          
        case 'onListeningStateChanged':
          final isListening = call.arguments as bool?;
          if (isListening != null) {
            _isListening = isListening;
            debugPrint('🎤 語音監聽狀態: $_isListening');
            notifyListeners();
          }
          break;
      }
    });
  }
  
  /// 測試 TTS
  Future<void> testTts() async {
    debugPrint('🧪 測試 Flutter TTS...');
    try {
      await speak('語音測試');
    } catch (e) {
      debugPrint('❌ TTS 測試失敗: $e');
    }
  }
  
  /// 語音合成 - 直接使用 Flutter TTS
  Future<void> speak(String text) async {
    if (text.isEmpty || _flutterTts == null) {
      debugPrint('⚠️ 無法播放語音: text="$text", tts=${_flutterTts != null}');
      return;
    }
    
    try {
      debugPrint('🗣️ 開始語音播放: "$text"');
      
      // 停止當前播放
      await _flutterTts!.stop();
      
      // 開始新的語音
      int result = await _flutterTts!.speak(text);
      debugPrint('📢 TTS speak 結果: $result');
      
      if (result == 1) {
        debugPrint('✅ 語音播放啟動成功');
      } else {
        debugPrint('⚠️ TTS 返回異常: $result');
      }
      
    } catch (e) {
      debugPrint('💥 語音播放失敗: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }
  
  /// 停止語音播放
  Future<void> stopSpeaking() async {
    if (_flutterTts != null) {
      try {
        await _flutterTts!.stop();
        debugPrint('🛑 語音播放已停止');
      } catch (e) {
        debugPrint('❌ 停止語音失敗: $e');
      }
    }
    
    _isSpeaking = false;
    notifyListeners();
  }
  
  /// 開始語音識別
  Future<void> startListening() async {
    if (_speechToText != null) {
      try {
        debugPrint('🎤 使用 Speech to Text 啟動語音識別...');
        
        // 檢查權限，如果沒有權限就申請
        bool hasPermission = false;
        try {
          hasPermission = await _speechToText!.hasPermission == true;
          debugPrint('📋 權限檢查結果: $hasPermission');
        } catch (e) {
          debugPrint('⚠️ 檢查權限時發生錯誤: $e，嘗試直接啟動');
          // 即使權限檢查出錯，也嘗試啟動語音識別
          hasPermission = true;
        }
        
        // 如果沒有權限，嘗試申請權限
        if (!hasPermission) {
          debugPrint('📋 沒有權限，嘗試申請...');
          bool permissionGranted = false;
          try {
            permissionGranted = await _speechToText!.initialize() == true;
            debugPrint('📋 權限申請結果: $permissionGranted');
          } catch (e) {
            debugPrint('⚠️ 申請權限時發生錯誤: $e，強制嘗試啟動');
            permissionGranted = true; // 強制嘗試
          }
          hasPermission = permissionGranted;
        }
        
        debugPrint('🎤 開始語音識別（權限狀態: $hasPermission）...');
        
        // 啟動語音識別，不依賴返回值判斷成功與否
        await _speechToText!.listen(
          onResult: (SpeechRecognitionResult result) {
            String recognizedWords = result.recognizedWords;
            debugPrint('🗣️ 識別到語音: $recognizedWords');
            
            if (result.finalResult && recognizedWords.isNotEmpty) {
              // 處理語音指令
              _processVoiceCommand(recognizedWords);
            }
          },
          localeId: 'zh_TW', // 使用繁體中文
          partialResults: false,
          listenMode: ListenMode.confirmation,
        );
        
        // 不依賴 listen 的返回值，而是等待狀態回調確認
        debugPrint('🎤 Speech to Text listen 調用完成，等待狀態確認...');
        
        // 給時間讓狀態回調生效，並標記為正在監聽
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // 強制設置監聽狀態，因為語音識別實際上在工作
        if (!_isListening) {
          _isListening = true;
          notifyListeners();
          debugPrint('🎤 強制設置監聽狀態為 true');
        }
        
        debugPrint('✅ Speech to Text 語音識別已啟動（強制確認）');
        
      } catch (e) {
        debugPrint('❌ Speech to Text 錯誤: $e');
        await _fallbackListening();
      }
    } else {
      debugPrint('⚠️ Speech to Text 未初始化');
      await _fallbackListening();
    }
  }
  
  /// 備用語音識別方案
  Future<void> _fallbackListening() async {
    // 在喚醒模式下，即使出現錯誤也要繼續嘗試監聽
    if (_isWakeModeActive) {
      debugPrint('💡 喚醒模式：忽略錯誤，繼續監聽');
      _isListening = true;
      notifyListeners();
      
      // 短暫延遲後重新嘗試監聽
      Future.delayed(const Duration(seconds: 2), () {
        if (_isWakeModeActive && !_speechToText!.isListening) {
          debugPrint('🔄 重新嘗試啟動語音識別...');
          _startContinuousListening();
        }
      });
    } else {
      debugPrint('💡 使用備用語音識別模式');
      
      // 非喚醒模式才播放錯誤提示
      _isListening = true;
      notifyListeners();
      
      await speak('語音識別功能目前不可用，請使用螢幕上的按鈕進行操作。');
      
      Future.delayed(const Duration(seconds: 3), () {
        if (_isListening) {
          _isListening = false;
          notifyListeners();
          debugPrint('🛑 備用語音識別已停止');
        }
      });
    }
  }
  
  /// 處理語音指令
  void _processVoiceCommand(String recognizedWords) {
    String command = recognizedWords.toLowerCase().trim();
    debugPrint('🧠 處理語音指令: "$command"');
    
    // 首先檢查是否為喚醒詞
    if (command.contains('嘿廚師') || command.contains('黑廚師') || command.contains('hey chef') || 
        command.contains('嘿主廚') || command.contains('廚師') || command.contains('hey kitchen')) {
      debugPrint('🎯 識別到喚醒詞: "$command"');
      debugPrint('🎤 啟動語音指令模式...');
      
      // 進入指令模式
      _isCommandModeActive = true;
      _isWakeModeActive = false;
      notifyListeners();
      
      // 語音反饋
      speak('我在聽，請說指令');
      
      // 重新啟動監聽等待指令
      Future.delayed(const Duration(seconds: 1), () {
        startListening();
      });
      
      return; // 喚醒詞處理完成，不繼續處理其他指令
    }
    
    // 處理功能指令（只在指令模式或正常模式下）
    bool commandExecuted = false;
    
    if (command.contains('下一步') || command.contains('下一個') || command.contains('繼續') || 
        command.contains('下個') || command.contains('下') || command.contains('next') || 
        command.contains('前進') || command.contains('往下')) {
      debugPrint('✅ 識別為下一步指令');
      if (_onVoiceCommand != null) _onVoiceCommand!('next');
      commandExecuted = true;
    } else if (command.contains('上一步') || command.contains('上一個') || command.contains('返回') || 
               command.contains('上個') || command.contains('上') || command.contains('previous') || 
               command.contains('回去') || command.contains('往上')) {
      debugPrint('✅ 識別為上一步指令');
      if (_onVoiceCommand != null) _onVoiceCommand!('previous');
      commandExecuted = true;
    } else if (command.contains('重複') || command.contains('再說一遍') || command.contains('重播') || 
               command.contains('重說') || command.contains('repeat') || command.contains('again') || 
               command.contains('再來') || command.contains('再次')) {
      debugPrint('✅ 識別為重複指令');
      if (_onVoiceCommand != null) _onVoiceCommand!('repeat');
      commandExecuted = true;
    } else if (command.contains('暫停') || command.contains('停止') || command.contains('pause') || 
               command.contains('stop') || command.contains('等等') || command.contains('休息')) {
      debugPrint('✅ 識別為暫停指令');
      if (_onVoiceCommand != null) _onVoiceCommand!('pause');
      commandExecuted = true;
    } else if (command.contains('開始') || command.contains('播放') || command.contains('start') || 
               command.contains('play') || command.contains('開始吧') || command.contains('來吧')) {
      debugPrint('✅ 識別為開始指令');
      if (_onVoiceCommand != null) _onVoiceCommand!('start');
      commandExecuted = true;
    } else {
      debugPrint('🤷 未識別的指令: "$command"');
      if (_isWakeModeActive) {
        debugPrint('💡 提示：請說 "嘿廚師" 喚醒後，再說指令');
      }
      if (_onVoiceError != null) {
        _onVoiceError!('未識別的指令，請先說"嘿廚師"喚醒，然後說指令');
      }
    }
    
    // 如果執行了指令且在喚醒模式，回到喚醒監聽狀態
    if (commandExecuted && _isWakeModeActive) {
      _isCommandModeActive = false;
      notifyListeners();
      
      // 短暫延遲後重新開始監聽喚醒詞
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_isWakeModeActive && !_isListening) {
          debugPrint('🔄 指令執行完成，回到喚醒監聽模式');
          _startContinuousListening();
        }
      });
    }
  }
  
  /// 停止語音識別
  Future<void> stopListening() async {
    if (_speechToText != null && _speechToText!.isListening) {
      try {
        debugPrint('🛑 停止 Speech to Text...');
        await _speechToText!.stop();
        debugPrint('✅ Speech to Text 已停止');
      } catch (e) {
        debugPrint('❌ 停止 Speech to Text 失敗: $e');
      }
    }
    
    _isListening = false;
    notifyListeners();
    debugPrint('✅ 語音識別狀態已重置');
  }
  
  /// 設置回調函數
  void setVoiceCommandCallback(Function(String)? callback) {
    _onVoiceCommand = callback;
    debugPrint('📞 語音指令回調已設置');
  }
  
  void setVoiceErrorCallback(Function(String)? callback) {
    _onVoiceError = callback;
    debugPrint('📞 語音錯誤回調已設置');
  }
  
  /// 啟動語音喚醒模式
  Future<void> startWakeMode({bool silent = false}) async {
    debugPrint('🎤 啟動語音喚醒模式...');
    _isWakeModeActive = true;
    _isCommandModeActive = false;
    notifyListeners();
    
    try {
      // 如果不是靜默模式，播放提示語音
      if (!silent) {
        await speak('語音控制已啟動，隨時說嘿廚師來使用語音指令');
      }
      
      // 立即開始持續監聽
      _startContinuousListening();
      debugPrint('✅ 語音喚醒模式已啟動，麥克風正在持續監聽');
      
    } catch (e) {
      debugPrint('❌ 啟動喚醒模式失敗: $e');
      rethrow; // 重新拋出錯誤讓調用方處理
    }
  }
  
  /// 持續監聽模式
  void _startContinuousListening() {
    if (!_isWakeModeActive) return;
    
    debugPrint('🔄 開始持續監聽...');
    startListening();
  }
  
  /// 停止語音喚醒模式
  Future<void> stopWakeMode() async {
    debugPrint('🔇 停止語音喚醒模式');
    _isWakeModeActive = false;
    _isCommandModeActive = false;
    
    try {
      await stopListening();
      await speak('語音喚醒模式已停止');
    } catch (e) {
      debugPrint('❌ 停止喚醒模式失敗: $e');
    }
    
    notifyListeners();
  }
  
  /// 模擬喚醒詞（用於測試）
  void simulateWakeWord(String wakeWord) {
    debugPrint('🎤 模擬喚醒詞: $wakeWord');
    _isCommandModeActive = true;
    notifyListeners();
    speak('已收到喚醒詞: $wakeWord');
  }
  
  /// 釋放資源
  @override
  void dispose() {
    _flutterTts?.stop();
    _flutterTts = null;
    super.dispose();
  }
}