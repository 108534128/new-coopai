// frontend/lib/screens/camera_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/food_detection_service.dart';
import 'recipe_search_result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  final FoodDetectionService _detectionService = FoodDetectionService();
  
  File? _selectedImage;
  bool _isProcessing = false;
  bool _isServiceInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeDetectionService();
  }

  /// 初始化辨識服務
  Future<void> _initializeDetectionService() async {
    try {
      print('🚀 開始初始化食材辨識服務...');
      await _detectionService.initialize();
      setState(() {
        _isServiceInitialized = true;
      });
      print('✅ 食材辨識服務初始化完成');
    } catch (e) {
      print('❌ 初始化食材辨識服務失敗: $e');
      setState(() {
        _error = '辨識服務初始化失敗，請重新啟動 APP';
        _isServiceInitialized = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _error = null;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        
        await _processImage();
      }
    } catch (e) {
      print('❌ 選擇圖片錯誤: $e');
      setState(() {
        _error = '選擇圖片失敗：$e';
      });
    }
  }

  Future<void> _processImage() async {
    if (!_isServiceInitialized) {
      setState(() {
        _error = '辨識服務尚未初始化，請稍候...';
      });
      // 嘗試重新初始化
      await _initializeDetectionService();
      if (!_isServiceInitialized) {
        return;
      }
    }

    if (_selectedImage == null) {
      setState(() {
        _error = '請先選擇圖片';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      print('🔍 開始辨識圖片: ${_selectedImage!.path}');
      
      // 使用真實的 AI 辨識服務
      final detectedIngredients = await _detectionService.detectFood(_selectedImage!.path);
      
      print('✅ 偵測到的食材: $detectedIngredients');
      
      if (detectedIngredients.isEmpty) {
        setState(() {
          _error = '未偵測到食材，請確保圖片清晰且包含可辨識的食材';
        });
        return;
      }
      
      // 根據偵測到的食材搜尋食譜
      await _searchRecipesByIngredients(detectedIngredients);
      
    } catch (e) {
      print('❌ 處理圖片錯誤: $e');
      setState(() {
        _error = '辨識失敗：$e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 根據食材搜尋食譜
  Future<void> _searchRecipesByIngredients(Map<String, int> ingredientsWithCount) async {
    try {
      // 提取食材名稱列表用於搜尋
      final ingredients = ingredientsWithCount.keys.toList();
      
      // 使用 API 搜尋包含所有偵測到食材的食譜
      final recipes = await _apiService.searchRecipes(
        searchText: null,
        tags: ingredients, // 將食材作為標籤搜尋
      );
      
      print('✅ 找到 ${recipes.length} 個包含食材的食譜');
      
      // 導航到結果頁面
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeSearchResultScreen(
              detectedIngredients: ingredientsWithCount,
              recipes: recipes,
            ),
          ),
        );
      }
      
    } catch (e) {
      print('❌ 搜尋食譜錯誤: $e');
      setState(() {
        _error = '搜尋食譜失敗：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在 Web 平台上顯示不支援訊息
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFCCD5AE),
          foregroundColor: const Color(0xFFFEFAE0),
          title: const Text(
            '拍照辨識',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFFEFAE0),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5DC).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 80,
                    color: Color(0xFFD4A373),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Web 版本不支援拍照辨識功能',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF32201C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '請使用手機版 APP 或桌面版應用程式\n來使用 AI 食材辨識功能',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4A373).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFFD4A373),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '提示：您可以使用搜尋功能來尋找喜愛的食譜',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 原有的相機功能（僅在非 Web 平台）
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 標題欄
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt,
                    color: Color(0xFFD4A373),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '食材辨識',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4A373),
                    ),
                  ),
                ],
              ),
            ),

            // 主要內容區域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 錯誤訊息
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 圖片預覽區域
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '請選擇或拍攝食材照片',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // 處理中指示器
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A373).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFD4A373),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              '辨識中，請稍候...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFFD4A373),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 操作按鈕
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text(
                              '拍照',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A373),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text(
                              '相簿',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFD4A373),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFD4A373),
                                  width: 2,
                                ),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 使用說明
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5DC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFF32201C),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '使用提示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF32201C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem('確保光線充足'),
                          _buildTipItem('食材盡量平鋪，避免重疊'),
                          _buildTipItem('相機與食材保持適當距離'),
                          _buildTipItem('可辨識 26 種常見蔬菜食材'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detectionService.dispose();
    super.dispose();
  }
}
