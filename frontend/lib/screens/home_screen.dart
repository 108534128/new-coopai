// frontend/lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../services/api_service.dart';
import '../services/image_recognition_service.dart';
import '../screens/favorites_screen.dart';
import '../screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;
  
  // ===== 新增：搜尋相關變數 =====
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allKeywords = [];
  List<String> _selectedTags = [];
  bool _showFilters = false;
  
  // ===== 新增：影像辨識相關變數 =====
  final ImageRecognitionService _imageRecognitionService = ImageRecognitionService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isModelInitialized = false;
  bool _isRecognizing = false;
  File? _selectedImage;
  Map<String, dynamic>? _recognitionResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkLoginStatus();
      _loadRecipes();
      _loadCategories(); // 新增：載入分類和關鍵字
      _initializeImageRecognition(); // 新增：初始化影像辨識服務
    });
  }
  
  // ===== 新增：初始化影像辨識服務 =====
  Future<void> _initializeImageRecognition() async {
    try {
      await _imageRecognitionService.initialize();
      setState(() {
        _isModelInitialized = true;
      });
    } catch (e) {
      print('❌ 影像辨識服務初始化失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('影像辨識服務初始化失敗: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose(); // 新增：釋放資源
    _imageRecognitionService.dispose(); // 新增：釋放影像辨識服務
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipes = await _apiService.getRecipes();
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // ===== 新增：載入分類和關鍵字 =====
  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      final keywords = await _apiService.getKeywords();
      
      setState(() {
        _categories = categories;
        _allKeywords = keywords;
      });
    } catch (e) {
      print('載入分類失敗: $e');
    }
  }
  
  // ===== 新增：執行搜尋 =====
  Future<void> _performSearch() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final searchText = _searchController.text.trim();
      
      // 如果沒有輸入任何搜尋條件，載入所有食譜
      if (searchText.isEmpty && _selectedTags.isEmpty) {
        final recipes = await _apiService.getRecipes();  // ← 直接取得所有食譜
        setState(() {
          _recipes = recipes;
          _isLoading = false;
        });
        return;
      }
      
      // 有搜尋條件時，使用搜尋 API
      final recipes = await _apiService.searchRecipes(
        searchText: searchText.isEmpty ? null : searchText,
        tags: _selectedTags.isEmpty ? null : _selectedTags,
      );
      
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 搜尋錯誤: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // ===== 新增：清除搜尋 =====
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _selectedTags.clear();
      _isLoading = false;  // ← 確保清除 loading 狀態
    });
    _loadRecipes();  // 載入所有食譜
  }
  
  // ===== 新增：切換標籤選擇 =====
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    _performSearch(); // 自動搜尋
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFFE8F4F8), // 淺藍色標題欄
            foregroundColor: const Color(0xFF2C3E50), // 深灰藍色文字
            title: const Text(
              '智慧食材辨識與食譜推薦',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => context.go('/profile'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await authProvider.logout();
                    if (mounted) {
                      context.go('/login');
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('登出'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: const Color(0xFFFAFAFA),
            selectedItemColor: const Color(0xFFB3D9E8), // 稍微深一點的淺藍色
            unselectedItemColor: const Color(0xFF757575),
            selectedIconTheme: const IconThemeData(color: Color(0xFFB3D9E8)),
            selectedLabelStyle: const TextStyle(color: Color(0xFFB3D9E8)),
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '首頁',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt),
                label: '拍照辨識',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu),
                label: '食譜推薦',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: '我的收藏',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCameraTab();
      case 2:
        return _buildRecipesTab();
      case 3:
        return _buildFavoritesTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '歡迎回來！',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF93939B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${authProvider.user?.name ?? authProvider.user?.account}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF2C3E50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '開始探索美味的食譜吧！',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '快速功能',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.camera_alt,
                  title: '拍照辨識',
                  subtitle: '識別食材',
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.restaurant_menu,
                  title: '食譜推薦',
                  subtitle: '發現新食譜',
                  onTap: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.favorite,
                  title: '我的收藏',
                  subtitle: '收藏的食譜',
                  onTap: () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.history,
                  title: '歷史記錄',
                  subtitle: '查看歷史',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4F8).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: const Color(0xFFE1D6DA),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraTab() {
    // 檢查是否為 Web 平台
    final bool isWeb = kIsWeb;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Web 平台提示
          if (isWeb)
            Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFFAFAFA),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: const Color(0xFF64B5F6),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '影像辨識功能',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '此功能僅支援 Android 和 iOS 平台',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF424242),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '請使用 Android 模擬器或實體手機測試',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          
          // 模型初始化狀態（非 Web 平台）
          if (!isWeb && !_isModelInitialized)
            Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFFAFAFA),
                    ],
                  ),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '正在載入影像辨識模型...',
                      style: TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (!isWeb && _isModelInitialized) ...[
            // 拍照按鈕
            Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFFAFAFA),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRecognizing ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('選擇圖片'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64B5F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isRecognizing ? null : _takePicture,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('拍照'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 顯示選中的圖片
            if (_selectedImage != null) ...[
              Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImage!,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 辨識按鈕
              ElevatedButton.icon(
                onPressed: _isRecognizing ? null : _recognizeImage,
                icon: _isRecognizing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isRecognizing ? '辨識中...' : '開始辨識'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF64B5F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            
            // 顯示辨識結果
            if (_recognitionResult != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFFFAFAFA),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '辨識結果',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _recognitionResult!['message'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF424242),
                        ),
                      ),
                      if (_recognitionResult!['ingredients'] != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          '食材清單：',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_recognitionResult!['ingredients'] as Map<String, dynamic>)
                            .entries
                            .map((entry) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF66BB6A),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${entry.key}: ${entry.value} 個',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF424242),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  // ===== 新增：選擇圖片 =====
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognitionResult = null; // 清除之前的結果
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選擇圖片失敗: $e')),
        );
      }
    }
  }
  
  // ===== 新增：拍照 =====
  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognitionResult = null; // 清除之前的結果
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失敗: $e')),
        );
      }
    }
  }
  
  // ===== 新增：辨識圖片 =====
  Future<void> _recognizeImage() async {
    if (_selectedImage == null || !_isModelInitialized) {
      return;
    }
    
    setState(() {
      _isRecognizing = true;
      _recognitionResult = null;
    });
    
    try {
      final result = await _imageRecognitionService.recognize(_selectedImage!);
      
      setState(() {
        _recognitionResult = result;
        _isRecognizing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: const Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRecognizing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('辨識失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ===== 食譜頁籤加入搜尋功能 =====
  Widget _buildRecipesTab() {
    return Column(
      children: [
        // 搜尋框和篩選按鈕
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.white,
          child: Column(
            children: [
              // 搜尋列
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14), // 縮小字體
                      decoration: InputDecoration(
                        hintText: '搜尋食譜名稱、食材...',
                        hintStyle: const TextStyle(fontSize: 14), // 縮小提示文字
                        prefixIcon: const Icon(Icons.search, size: 20), // 縮小圖標
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44, // 增加圖標區域寬度，讓圖標往右移動
                          minHeight: 36,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20), // 縮小圖標
                                onPressed: _clearSearch,
                                padding: EdgeInsets.zero, // 減少按鈕內邊距
                                constraints: const BoxConstraints(), // 移除最小尺寸限制
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), // 稍微縮小圓角
                          borderSide: BorderSide.none, // 無邊框線
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), // 稍微縮小圓角
                          borderSide: BorderSide.none, // 無邊框線
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), // 稍微縮小圓角
                          borderSide: BorderSide.none, // 無邊框線
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        isDense: true, // 讓輸入框更緊湊
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // 減少水平內邊距，讓圖標和文字更靠近
                      ),
                      onChanged: (value) {
                        setState(() {}); // 更新 UI 顯示清除按鈕
                      },
                      onSubmitted: (value) {
                        _performSearch();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 搜尋按鈕
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF949EC5), size: 20),
                    onPressed: _performSearch,
                    style: IconButton.styleFrom(
                      backgroundColor: _selectedTags.isNotEmpty 
                          ? Colors.green[50] 
                          : Colors.grey[100], // 與篩選按鈕相同的背景色
                      padding: const EdgeInsets.all(8), // 縮小按鈕內邊距
                      minimumSize: const Size(36, 36), // 縮小按鈕最小尺寸
                    ),
                  ),
                  // 篩選按鈕
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                      color: _selectedTags.isNotEmpty ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: _selectedTags.isNotEmpty 
                          ? Colors.green[50] 
                          : Colors.grey[100],
                      padding: const EdgeInsets.all(8), // 縮小按鈕內邊距
                      minimumSize: const Size(36, 36), // 縮小按鈕最小尺寸
                    ),
                  ),
                ],
              ),
              
              // 已選標籤顯示
              if (_selectedTags.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedTags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _toggleTag(tag),
                        backgroundColor: Colors.green[100],
                        labelStyle: const TextStyle(color: Colors.green),
                      );
                    }).toList(),
                  ),
                ),
              
              // 標籤篩選區（展開/收起）
              if (_showFilters)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    maxHeight: 400,  // ← 限制最大高度
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(  // ← 新增：可滾動容器
                    child: _buildFilterSection(),
                  ),
                ),
            ],
          ),
        ),
        
        // 分隔線
        const Divider(height: 1),
        
        // 食譜列表
        Expanded(
          child: _buildRecipesList(),
        ),
      ],
    );
  }
  
  // ===== 新增：篩選區塊 =====
  Widget _buildFilterSection() {
    if (_categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('載入中...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '篩選條件',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (_selectedTags.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTags.clear();
                  });
                  _performSearch();
                },
                child: const Text('清除全部'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 依分類顯示關鍵字
        ..._categories.map((category) {
          final categoryId = category['id'];
          final categoryName = category['category_name'];
          final keywords = _allKeywords
              .where((kw) => kw['category_id'] == categoryId)
              .toList();
          
          if (keywords.isEmpty) return const SizedBox.shrink();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((kw) {
                  final keywordName = kw['keyword_name'];
                  final isSelected = _selectedTags.contains(keywordName);
                  
                  return FilterChip(
                    label: Text(keywordName),
                    selected: isSelected,
                    onSelected: (selected) {
                      _toggleTag(keywordName);
                    },
                    selectedColor: Colors.green[100],
                    checkmarkColor: Colors.green,
                  );
                }).toList(),
              ),
              const Divider(),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  // ===== 新增：食譜列表顯示 =====
  Widget _buildRecipesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗：$_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '找不到符合的食譜',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('清除搜尋'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RefreshIndicator(
        onRefresh: _performSearch,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _recipes.length,
          itemBuilder: (context, index) {
            final recipe = _recipes[index];
            return RecipeCard(
              recipe: recipe,
              onTap: () {
                context.push(extra: recipe, '/recipe/${recipe.uid}');
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return const FavoritesScreen();
  }
}