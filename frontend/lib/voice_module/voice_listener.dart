import 'package:flutter/material.dart';
import 'voice_service.dart';

/// 語音監聽器 - 處理語音指令並執行相應動作
class VoiceListener {
  VoiceService? _voiceService;
  Function(String command, Map<String, dynamic> data)? _commandCallback;
  
  /// 設置語音服務
  void setVoiceService(VoiceService voiceService) {
    _voiceService = voiceService;
    _voiceService!.setVoiceCommandCallbacks(
      onCommand: _handleVoiceCommand,
      onError: _handleVoiceError,
    );
    debugPrint('🌐 語音監聽器已設置');
  }
  
  /// 設置指令回調
  void setCommandCallback(Function(String command, Map<String, dynamic> data)? callback) {
    _commandCallback = callback;
  }
  
  /// 處理語音指令
  void _handleVoiceCommand(String command) {
    debugPrint('🌐 收到語音指令: $command');
    
    // 根據指令執行相應動作
    switch (command) {
      case 'next':
        _executeNextCommand();
        break;
      case 'previous':
        _executePreviousCommand();
        break;
      case 'repeat':
        _executeRepeatCommand();
        break;
      default:
        debugPrint('❌ 未知的語音指令: $command');
    }
  }
  
  /// 處理語音錯誤
  void _handleVoiceError(String error) {
    debugPrint('🌐 語音錯誤: $error');
  }
  
  /// 執行下一步指令
  void _executeNextCommand() {
    debugPrint('🌐 執行下一步指令');
    
    // 通知外部應用程式
    _commandCallback?.call('next', {
      'action': 'next_step',
      'description': '跳轉到下一步',
    });
    
    // 語音回應
    _voiceService?.speak('好的，執行下一步');
  }
  
  /// 執行上一步指令
  void _executePreviousCommand() {
    debugPrint('🌐 執行上一步指令');
    
    // 通知外部應用程式
    _commandCallback?.call('previous', {
      'action': 'previous_step',
      'description': '跳轉到上一步',
    });
    
    // 語音回應
    _voiceService?.speak('好的，執行上一步');
  }
  
  /// 執行重複指令
  void _executeRepeatCommand() {
    debugPrint('🌐 執行重複指令');
    
    // 通知外部應用程式
    _commandCallback?.call('repeat', {
      'action': 'repeat_step',
      'description': '重複當前步驟',
    });
    
    // 語音回應
    _voiceService?.speak('好的，重複當前步驟');
  }
  
  /// 手動處理指令（用於測試）
  void handleCommand(String command, Map<String, dynamic> data) {
    _commandCallback?.call(command, data);
  }
}
