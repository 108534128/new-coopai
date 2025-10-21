import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/recipe.dart';

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
  int _currentPage = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  bool _isTimerPaused = false;
  bool _isPlayingEndSound = false;
  int? _originalSeconds;

  @override
  void initState() {
    super.initState();
    _steps = widget.recipe.instructionsList;
    _controller = PageController();
    _initAudioPlayer();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.recipe.name} 步驟'),
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
                    },
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '步驟 ${index + 1}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step,
                                          style: Theme.of(context).textTheme.bodyLarge,
                                        ),
                                        const SizedBox(height: 16),
                                        if (_parseMinutes(step) != null) ...[
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade100,
                                                width: 1,
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.timer_outlined,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (_isTimerRunning || _isTimerPaused)
                                                      Text(
                                                        '剩餘時間: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: Colors.green.shade700,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      )
                                                    else
                                                      Text(
                                                        '需要 ${_parseMinutes(step)} 分鐘',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: Colors.green.shade700,
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
                                                      icon: const Icon(Icons.play_arrow),
                                                      label: const Text('繼續'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    )
                                                  else
                                                    ElevatedButton.icon(
                                                      onPressed: _pauseTimer,
                                                      icon: const Icon(Icons.pause),
                                                      label: const Text('暫停'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                ],
                                                ElevatedButton.icon(
                                                  onPressed: _stopTimer,
                                                  icon: const Icon(Icons.stop),
                                                  label: const Text('停止'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                ),
                                                    ],
                                                  ),
                                                ] else ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () => _startTimer(_parseMinutes(step)!),
                                                    icon: const Icon(Icons.timer),
                                                    label: const Text('開始計時'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.green,
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
                child: ElevatedButton(
                  onPressed: () => _handleNext(context),
                  child: Text(_currentPage == steps.length - 1 ? '完成' : '下一步'),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '第 ${current + 1} / $total 步',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Icon(Icons.swipe_up_alt_outlined),
        ],
      ),
    );
  }
}
