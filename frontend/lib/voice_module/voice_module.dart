import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'voice_service.dart';
import 'voice_listener.dart';

/// 語音模組 - 可以整合到任何 Flutter 應用程式中
class VoiceModule {
  static VoiceModule? _instance;
  static VoiceModule get instance => _instance ??= VoiceModule._();
  
  VoiceModule._();
  
  late VoiceService _voiceService;
  late VoiceListener _voiceListener;
  
  bool _isInitialized = false;
  
  /// 初始化語音模組
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🎤 初始化語音模組...');
    
    _voiceService = VoiceService();
    _voiceListener = VoiceListener();
    
    await _voiceService.initialize();
    _voiceListener.setVoiceService(_voiceService);
    
    _isInitialized = true;
    debugPrint('✅ 語音模組初始化完成');
  }
  
  /// 設置語音指令回調
  void setVoiceCommandCallback(Function(String command, Map<String, dynamic> data)? callback) {
    _voiceListener.setCommandCallback(callback);
  }
  
  /// 啟動語音監聽
  void startListening() {
    if (!_isInitialized) {
      debugPrint('❌ 語音模組尚未初始化');
      return;
    }
    _voiceService.startWakeMode();
  }
  
  /// 停止語音監聽
  void stopListening() {
    if (!_isInitialized) return;
    _voiceService.stopWakeMode();
  }
  
  /// 手動觸發語音指令（用於測試）
  void simulateCommand(String command, Map<String, dynamic> data) {
    _voiceListener.handleCommand(command, data);
  }
  
  /// 獲取語音服務狀態
  bool get isListening => _voiceService.isWakeModeActive;
  bool get isInitialized => _isInitialized;
}
