import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/recipe.dart';
import '../services/direct_voice_service.dart';

class RecipeWalkthroughScreen extends StatefulWidget {
  const RecipeWalkthroughScreen({required this.recipe, super.key});

  final Recipe recipe;

  @override
  State<RecipeWalkthroughScreen> createState() => _RecipeWalkthroughScreenState();
}

class _RecipeWalkthroughScreenState extends State<RecipeWalkthroughScreen> {
  late final PageController _controller;
  late final List<String> _steps;
  late final AudioPlayer _audioPlayer;
  late final DirectVoiceService _voiceService;
  int _currentPage = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _isTimerPaused = false;
  bool _isPlayingEndSound = false;
  int? _originalSeconds;
  bool _isVoiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _steps = widget.recipe.instructionsList;
    _controller = PageController();
    _initAudioPlayer();
    _initVoiceService();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    try {
      // 預加載音效文件以確保可以播放
      await _audioPlayer.setSource(AssetSource('sounds/timer_end.mp3'));
      debugPrint('音效初始化成功');
    } catch (e) {
      debugPrint('音效初始化失敗: $e');
    }
  }

  Future<void> _initVoiceService() async {
    _voiceService = DirectVoiceService();
    try {
      await _voiceService.initialize();
      
      // 設置語音指令回調
      _voiceService.setVoiceCommandCallback((command) {
        debugPrint('收到語音指令: $command');
        _handleVoiceCommand(command);
      });
      
      // 設置錯誤回調
      _voiceService.setVoiceErrorCallback((error) {
        debugPrint('語音錯誤: $error');
        _showVoiceError(error);
      });
      
      debugPrint('語音服務初始化成功');
      
      // 立即自動啟動麥克風和語音控制
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (mounted) {
          debugPrint('🎤 [AUTO] 自動開啟麥克風並啟動語音控制...');
          try {
            // 先嘗試啟動語音喚醒模式（靜默啟動，自動開啟麥克風持續監聽）
            await _voiceService.startWakeMode(silent: true);
            
            // 等待一下確保服務啟動
            await Future.delayed(const Duration(milliseconds: 500));
            
            // 設置語音狀態為啟用
            if (mounted) {
              setState(() {
                _isVoiceEnabled = true;
              });
            }
            
            debugPrint('✅ [AUTO] 麥克風已自動開啟，正在持續監聽語音指令');
            
            // 稍後播放歡迎語音，不干擾語音識別
            Future.delayed(const Duration(milliseconds: 3000), () async {
              if (mounted && _isVoiceEnabled) {
                await _voiceService.speak('歡迎使用${widget.recipe.name}食譜演練。麥克風已自動開啟，隨時說嘿廚師來控制食譜。');
              }
            });
            
          } catch (e) {
            debugPrint('❌ [AUTO] 自動啟動語音控制失敗: $e');
            // 失敗時設置UI狀態，讓用戶可以手動啟動
            if (mounted) {
              setState(() {
                _isVoiceEnabled = false;
              });
            }
          }
        }
      });
      
    } catch (e) {
      debugPrint('語音服務初始化失敗: $e');
    }
  }

  void _handleVoiceCommand(String command) {
    if (!mounted) return;
    
    debugPrint('處理語音指令: $command');
    
    switch (command) {
      case 'next':
        _handleNext(context);
        break;
      case 'previous':
        _handlePrevious();
        break;
      case 'repeat':
        _repeatCurrentStep();
        break;
      case 'stop':
        _stopTimer();
        break;
      case 'continue':
        if (_isTimerPaused) {
          _resumeTimer();
        }
        break;
      case 'finish':
        Navigator.of(context).maybePop();
        break;
      default:
        debugPrint('未知的語音指令: $command');
    }
  }

  void _handlePrevious() {
    if (_currentPage > 0) {
      final prevPage = _currentPage - 1;
      _controller.animateToPage(
        prevPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _repeatCurrentStep() {
    if (_steps.isNotEmpty && _currentPage < _steps.length) {
      final currentStep = _steps[_currentPage];
      _voiceService.speak('重複步驟 ${_currentPage + 1}: $currentStep');
    }
  }

  void _showVoiceError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('語音錯誤: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleTTS() {
    setState(() {
      _isVoiceEnabled = !_isVoiceEnabled;
    });
    
    if (_isVoiceEnabled) {
      _speakCurrentStep();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('語音朗讀已啟用'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _voiceService.stopSpeaking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('語音朗讀已關閉'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleVoiceControl() async {
    if (_voiceService.isWakeModeActive) {
      await _voiceService.stopWakeMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('語音控制已關閉'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      await _voiceService.startWakeMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('語音控制已啟用，請說「嘿廚師」開始'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
    setState(() {});
  }

  void _speakCurrentStep() {
    if (_steps.isNotEmpty && _currentPage < _steps.length && _isVoiceEnabled) {
      final currentStep = _steps[_currentPage];
      final stepText = '步驟 ${_currentPage + 1}: $currentStep';
      _voiceService.speak(stepText);
    }
  }

  Future<void> _playTimerEndSound() async {
    try {
      // 停止任何可能正在播放的音效
      await _audioPlayer.stop();
      
      // 設置音量為最大
      await _audioPlayer.setVolume(1.0);
      
      // 播放音效
      await _audioPlayer.play(AssetSource('sounds/timer_end.mp3'));
      
      debugPrint('開始播放計時器結束音效');
      
      // 監聽音效播放完成
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlayingEndSound = false;
            _isTimerRunning = false; // 音效播放完才完全結束計時器
          });
        }
      });
    } catch (e) {
      debugPrint('播放音效時發生錯誤: $e');
      setState(() {
        _isPlayingEndSound = false;
        _isTimerRunning = false;
      });
    }
  }

  // 解析步驟中的時間（分鐘）
  int? _parseMinutes(String step) {
    final regex = RegExp(r'(\d+)\s*分鐘');
    final match = regex.firstMatch(step);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _remainingSeconds = minutes * 60;
      _originalSeconds = _remainingSeconds;
      _isTimerRunning = true;
      _isTimerPaused = false;
      _isPlayingEndSound = false;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          // 在這裡不重置 _isTimerRunning，保持顯示 0:00
          _isTimerPaused = false;
          if (!_isPlayingEndSound) {
            _isPlayingEndSound = true;
            _playTimerEndSound();
          }
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isTimerPaused = false;
    });
    _startCountdown();
  }

  void _stopTimer() {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _isTimerRunning = false;
      _isTimerPaused = false;
      _isPlayingEndSound = false;
      _remainingSeconds = _originalSeconds ?? 0;  // 重置為原始時間
      _originalSeconds = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _audioPlayer.dispose();
    
    // 異步停止語音服務
    _voiceService.stopWakeMode().catchError((error) {
      debugPrint('停止語音服務失敗: $error');
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFCCD5AE), // 米綠色標題欄（與首頁一致）
        foregroundColor: const Color(0xFFFEFAE0), // 米白色文字
        title: Text(
          '${widget.recipe.name} 步驟',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFEFAE0),
          ),
        ),
        actions: [
          // TTS 按鈕
          IconButton(
            onPressed: _isVoiceEnabled ? null : _toggleTTS,
            icon: Icon(
              _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isVoiceEnabled ? const Color(0xFFD4A373) : const Color(0xFFFEFAE0), // 咖啡色/米白色
            ),
            tooltip: '語音朗讀步驟',
          ),
          // 語音控制按鈕
          IconButton(
            onPressed: _toggleVoiceControl,
            icon: Icon(
              _voiceService.isWakeModeActive ? Icons.mic : Icons.mic_off,
              color: _voiceService.isWakeModeActive ? const Color(0xFFD4A373) : const Color(0xFFFEFAE0), // 咖啡色/米白色
            ),
            tooltip: '語音控制',
          ),
        ],
      ),
      body: steps.isEmpty
          ? const Center(
              child: Text('目前沒有可顯示的步驟'),
            )
          : Column(
              children: [
                _StepIndicator(current: _currentPage, total: steps.length),
                const Divider(height: 1),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                      
                      // 自動朗讀新步驟
                      if (_isVoiceEnabled) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _speakCurrentStep();
                        });
                      }
                    },
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Card(
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          color: Colors.white,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  const Color(0xFFFAFAFA),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '步驟 ${index + 1}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                    ),
                                    const Spacer(),
                                    // 語音狀態指示器
                                    if (_voiceService.isSpeaking && _currentPage == index)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.volume_up,
                                              color: Color(0xFF64B5F6),
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '朗讀中...',
                                              style: TextStyle(
                                                color: Color(0xFF1976D2),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_voiceService.isWakeModeActive)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.mic,
                                              color: Color(0xFFFF9A9E),
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '語音控制',
                                              style: TextStyle(
                                                color: Color(0xFFE91E63),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAFAFA),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFE0E0E0).withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            step,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              height: 1.6,
                                              color: const Color(0xFF424242),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // 語音控制區域
                                        if (index == _currentPage) ...[
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAFAFA),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFFE0E0E0).withOpacity(0.5),
                                                width: 1,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF64B5F6).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.record_voice_over,
                                                        color: Colors.black,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      '語音功能',
                                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                        color: Colors.black,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      onPressed: () => _speakCurrentStep(),
                                                      icon: const Icon(Icons.volume_up, size: 16),
                                                      label: const Text('朗讀步驟', style: TextStyle(fontSize: 12)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFFE0F2F1), // 淺青色
                                                        foregroundColor: const Color(0xFF004D40), // 深青色文字
                                                        elevation: 0,
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                        minimumSize: const Size(0, 36),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                    if (_voiceService.isWakeModeActive)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE8F5E9),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(
                                                            color: const Color(0xFF81C784).withOpacity(0.3),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          '可說「下一步」「上一步」「重複」',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Color(0xFF4CAF50),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    // 測試按鈕（開發用）
                                                    ElevatedButton.icon(
                                                      onPressed: () => _voiceService.simulateWakeWord('嘿廚師'),
                                                      icon: const Icon(Icons.bug_report, size: 16),
                                                      label: const Text('測試語音', style: TextStyle(fontSize: 12)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFFFFF3E0), // 淺米色
                                                        foregroundColor: const Color(0xFFBF360C), // 深橙色文字
                                                        elevation: 0,
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                        minimumSize: const Size(0, 36),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        if (_parseMinutes(step) != null) ...[
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFFE8F5E9),
                                                  const Color(0xFFF1F8E9),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFFA5D6A7).withOpacity(0.4),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withOpacity(0.05),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF81C784).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.timer_outlined,
                                                        color: Color(0xFF4CAF50),
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    if (_isTimerRunning || _isTimerPaused)
                                                      Text(
                                                        '剩餘時間: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: const Color(0xFF2E7D32),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      )
                                                    else
                                                      Text(
                                                        '需要 ${_parseMinutes(step)} 分鐘',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: const Color(0xFF2E7D32),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                if (_isTimerRunning || _isTimerPaused) ...[
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (_isTimerRunning && !_isPlayingEndSound && _remainingSeconds > 0) ...[
                                                        if (_isTimerPaused)
                                                          ElevatedButton.icon(
                                                            onPressed: _resumeTimer,
                                                            icon: const Icon(Icons.play_arrow, size: 18),
                                                            label: const Text('繼續'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFF66BB6A),
                                                              foregroundColor: Colors.white,
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          ElevatedButton.icon(
                                                            onPressed: _pauseTimer,
                                                            icon: const Icon(Icons.pause, size: 18),
                                                            label: const Text('暫停'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFFFFB74D),
                                                              foregroundColor: Colors.white,
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                            ),
                                                          ),
                                                        const SizedBox(width: 8),
                                                      ],
                                                      ElevatedButton.icon(
                                                        onPressed: _stopTimer,
                                                        icon: const Icon(Icons.stop, size: 18),
                                                        label: const Text('停止'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFFEF5350),
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ] else ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () => _startTimer(_parseMinutes(step)!),
                                                    icon: const Icon(Icons.timer, size: 18),
                                                    label: const Text('開始計時'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF66BB6A),
                                                      foregroundColor: Colors.white,
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: steps.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16, 
                  8, 
                  16,
                  16 + MediaQuery.of(context).viewPadding.bottom 
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 語音控制提示
                    if (_voiceService.isWakeModeActive) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFEBEE),
                              const Color(0xFFFFF3E0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF9A9E).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9A9E).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.mic,
                                color: Color(0xFFE91E63),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _voiceService.isCommandModeActive
                                    ? '🎤 正在聆聽指令...'
                                    : '🎤 語音控制啟動中，請說「嘿廚師」開始',
                                style: const TextStyle(
                                  color: Color(0xFFC2185B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // 主要按鈕
                    Row(
                      children: [
                        // 上一步按鈕
                        if (_currentPage > 0)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handlePrevious,
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text('上一步'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCCD5AE), // 米綠色
                                foregroundColor: Colors.white, // 白色文字
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 12),
                        // 下一步/完成按鈕
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleNext(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A373), // 咖啡色
                              foregroundColor: Colors.white, // 白色文字
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == steps.length - 1 ? '完成' : '下一步',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage == steps.length - 1 ? Icons.check_circle : Icons.arrow_forward,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _handleNext(BuildContext context) {
    final steps = _steps;
    if (steps.isEmpty) return;

    // 停止任何正在播放的音效
    if (_isPlayingEndSound) {
      _audioPlayer.stop();
      setState(() {
        _isPlayingEndSound = false;
      });
    }

    if (_currentPage >= steps.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }

    final nextPage = _currentPage + 1;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5DC), // 米色
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 ${current + 1} / $total 步',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF32201C),
                    ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.swipe_up_alt_outlined,
              color: Color(0xFF90A4AE),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
