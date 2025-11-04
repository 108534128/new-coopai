import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用語音整合服務 - 可以整合到任何現有的 Flutter 應用程式中
class UniversalVoiceService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('native_voice_service');
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  
  // 語音指令回調 - 讓外部應用程式處理
  Function(String command, Map<String, dynamic> context)? _onVoiceCommand;
  Function(String error)? _onVoiceError;
  
  // 外部應用程式的狀態回調 - 獲取當前狀態
  Function()? _getCurrentStep;
  Function()? _getTotalSteps;
  Function()? _getCurrentStepContent;
  Function()? _getCurrentStepTitle;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  
  /// 初始化語音服務
  Future<void> initialize() async {
    try {
      debugPrint('🎤 初始化通用語音服務...');
      
      _channel.setMethodCallHandler(_handleMethodCall);
      
      try {
        await _channel.invokeMethod('initialize');
        debugPrint('✅ 原生語音服務初始化成功');
      } catch (e) {
        debugPrint('⚠️ 原生語音服務不可用: $e');
      }
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ 通用語音服務初始化完成');
      
    } catch (e) {
      debugPrint('❌ 語音服務初始化失敗: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }
  
  /// 設置外部應用程式的回調函數
  void setExternalCallbacks({
    Function(String command, Map<String, dynamic> context)? onVoiceCommand,
    Function(String error)? onVoiceError,
    Function()? getCurrentStep,
    Function()? getTotalSteps,
    Function()? getCurrentStepContent,
    Function()? getCurrentStepTitle,
  }) {
    _onVoiceCommand = onVoiceCommand;
    _onVoiceError = onVoiceError;
    _getCurrentStep = getCurrentStep;
    _getTotalSteps = getTotalSteps;
    _getCurrentStepContent = getCurrentStepContent;
    _getCurrentStepTitle = getCurrentStepTitle;
    
    debugPrint('🔗 外部回調函數已設置');
  }
  
  /// 啟動語音監聽
  Future<void> startListening() async {
    if (!_isInitialized) {
      debugPrint('❌ 語音服務尚未初始化');
      return;
    }
    
    try {
      debugPrint('🎤 啟動語音監聽...');
      await _channel.invokeMethod('startWakeMode');
      await _channel.invokeMethod('startListening');
      _isListening = true;
      notifyListeners();
      
      debugPrint('✅ 語音監聽已啟動');
      
    } catch (e) {
      debugPrint('❌ 啟動語音監聽失敗: $e');
    }
  }
  
  /// 停止語音監聽
  Future<void> stopListening() async {
    try {
      debugPrint('🔇 停止語音監聽');
      await _channel.invokeMethod('stopWakeMode');
      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 停止語音監聽失敗: $e');
    }
  }
  
  /// 語音合成
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    try {
      debugPrint('🔊 語音合成: $text');
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      debugPrint('❌ 語音合成失敗: $e');
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
        if (_isListening) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _channel.invokeMethod('startListening');
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
      if (cleanText.contains(key)) {
        matchedCommand = commandMap[key];
        break;
      }
    }
    
    if (matchedCommand != null) {
      debugPrint('✅ 找到匹配指令: $cleanText -> $matchedCommand');
      
      // 獲取當前狀態
      final currentStep = _getCurrentStep?.call() ?? 0;
      final totalSteps = _getTotalSteps?.call() ?? 0;
      final stepContent = _getCurrentStepContent?.call() ?? '';
      final stepTitle = _getCurrentStepTitle?.call() ?? '';
      
      // 創建上下文資料
      final context = {
        'currentStep': currentStep,
        'totalSteps': totalSteps,
        'stepContent': stepContent,
        'stepTitle': stepTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // 通知外部應用程式
      _onVoiceCommand?.call(matchedCommand, context);
      
      // 語音回應
      _speakCommandResponse(matchedCommand, context);
      
    } else {
      debugPrint('❌ 未找到匹配的指令: $cleanText');
    }
  }
  
  /// 語音回應指令
  void _speakCommandResponse(String command, Map<String, dynamic> context) {
    String response = '';
    
    switch (command) {
      case 'next':
        final currentStep = context['currentStep'] as int;
        final totalSteps = context['totalSteps'] as int;
        if (currentStep < totalSteps - 1) {
          response = '好的，跳轉到下一步';
        } else {
          response = '已經是最後一步了';
        }
        break;
        
      case 'previous':
        final currentStep = context['currentStep'] as int;
        if (currentStep > 0) {
          response = '好的，跳轉到上一步';
        } else {
          response = '已經是第一步了';
        }
        break;
        
      case 'repeat':
        final stepTitle = context['stepTitle'] as String;
        if (stepTitle.isNotEmpty) {
          response = '重複步驟：$stepTitle';
        } else {
          response = '好的，重複當前步驟';
        }
        break;
    }
    
    if (response.isNotEmpty) {
      speak(response);
    }
  }
  
  /// 手動觸發語音指令（用於測試）
  void simulateCommand(String command) {
    debugPrint('🎤 模擬語音指令: $command');
    
    // 獲取當前狀態
    final currentStep = _getCurrentStep?.call() ?? 0;
    final totalSteps = _getTotalSteps?.call() ?? 0;
    final stepContent = _getCurrentStepContent?.call() ?? '';
    final stepTitle = _getCurrentStepTitle?.call() ?? '';
    
    // 創建上下文資料
    final context = {
      'currentStep': currentStep,
      'totalSteps': totalSteps,
      'stepContent': stepContent,
      'stepTitle': stepTitle,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // 通知外部應用程式
    _onVoiceCommand?.call(command, context);
    
    // 語音回應
    _speakCommandResponse(command, context);
  }
}
