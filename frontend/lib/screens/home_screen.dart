// frontend/lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../widgets/custom_text_field.dart';
import '../services/api_service.dart';
import '../screens/favorites_screen.dart';
import '../screens/history_screen.dart';
import '../screens/camera_screen.dart';
import 'recipe_detail_screen.dart';

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
  
  // ===== 新增：分頁相關變數 =====
  final int _pageSize = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  
  // ===== 新增：搜尋相關變數 =====
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allKeywords = [];
  List<String> _selectedTags = [];
  bool _showFilters = false;
  String _selectedCategory = '家常菜'; // 新增：當前選中的分類
  
  // ===== 新增：推薦相關變數 =====
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoadingRecommendations = false;
  String _recommendationType = '';
  Map<String, dynamic>? _userPreferences;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.checkLoginStatus().then((_) {
        if (authProvider.isLoggedIn) {
          _loadRecipes();
          _loadCategories(); // 新增：載入分類和關鍵字
          _loadRecommendations(); // 新增：載入推薦
        }
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose(); // 新增：釋放資源
    _scrollController.dispose(); // 新增：釋放 ScrollController
    super.dispose();
  }

  Future<void> _loadRecipes({bool isRefresh = true}) async {
    print('📦 _loadRecipes 被調用，isRefresh: $isRefresh, 當前 _isLoading: $_isLoading');
    
    if (_isLoading) {
      print('⚠️ _isLoading 為 true，返回不執行');
      return;
    }
    
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _hasMoreData = true;
      });
      print('✅ 設置 _isLoading = true，開始載入');
    } else {
      if (!_hasMoreData || _isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      // TODO: 修改 API 支援分頁參數
      final recipes = await _apiService.getRecipes();
      print('📦 獲取到 ${recipes.length} 個食譜');
      
      // 模擬分頁邏輯（暫時先用這種方式）
      final startIndex = (isRefresh ? 0 : _recipes.length);
      final endIndex = startIndex + _pageSize;
      final pageRecipes = recipes.skip(startIndex).take(_pageSize).toList();
      
      setState(() {
        if (isRefresh) {
          _recipes = pageRecipes;
        } else {
          _recipes.addAll(pageRecipes);
        }
        
        _hasMoreData = pageRecipes.length == _pageSize && endIndex < recipes.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
      print('✅ _loadRecipes 完成，當前顯示 ${_recipes.length} 個食譜');
    } catch (e) {
      print('❌ _loadRecipes 錯誤: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }
  
  // ===== 新增：滿動監聽器 =====
  void _scrollListener() {
    // 只在主頁面（index 0）支援分頁
    if (_selectedIndex != 0) return;
    
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // 當滿動到接近底部時載入更多數據
      if (_searchController.text.trim().isEmpty && _selectedTags.isEmpty) {
        _loadRecipes(isRefresh: false);
      } else {
        _performSearch(isRefresh: false);
      }
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
  
  // ===== 新增：載入推薦 =====
  Future<void> _loadRecommendations() async {
    setState(() => _isLoadingRecommendations = true);
    
    try {
      final result = await _apiService.getRecommendations(limit: 10);
      
      if (mounted) {
        setState(() {
          if (result['success']) {
            _recommendations = List<Map<String, dynamic>>.from(result['recommendations']);
            _recommendationType = result['recommendation_type'] ?? '';
            _userPreferences = result['user_preferences'];
            
            // 調試：檢查推薦數據
            print('載入了 ${_recommendations.length} 個推薦');
            if (_recommendations.isNotEmpty) {
              print('第一個推薦的圖片: ${_recommendations[0]['image']}');
              print('第一個推薦的名稱: ${_recommendations[0]['name']}');
            }
          }
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
      print('載入推薦失敗: $e');
    }
  }
  
  // ===== 新增：執行搜尋 =====
  Future<void> _performSearch({bool isRefresh = true}) async {
    if (_isLoading) return;
    
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _hasMoreData = true;
      });
    } else {
      if (!_hasMoreData || _isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final searchText = _searchController.text.trim();
      
      // 如果沒有輸入任何搜尋條件，載入所有食譜
      if (searchText.isEmpty && _selectedTags.isEmpty) {
        // 直接獲取所有食譜，不要調用 _loadRecipes（避免 _isLoading 衝突）
        final recipes = await _apiService.getRecipes();
        
        final startIndex = (isRefresh ? 0 : _recipes.length);
        final endIndex = startIndex + _pageSize;
        final pageRecipes = recipes.skip(startIndex).take(_pageSize).toList();
        
        setState(() {
          if (isRefresh) {
            _recipes = pageRecipes;
          } else {
            _recipes.addAll(pageRecipes);
          }
          
          _hasMoreData = pageRecipes.length == _pageSize && endIndex < recipes.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      // 有搜尋條件時，使用搜尋 API
      final recipes = await _apiService.searchRecipes(
        searchText: searchText.isEmpty ? null : searchText,
        tags: _selectedTags.isEmpty ? null : _selectedTags,
      );
      
      // 模擬分頁邏輯（暫時先用這種方式）
      final startIndex = (isRefresh ? 0 : _recipes.length);
      final endIndex = startIndex + _pageSize;
      final pageRecipes = recipes.skip(startIndex).take(_pageSize).toList();
      
      setState(() {
        if (isRefresh) {
          _recipes = pageRecipes;
        } else {
          _recipes.addAll(pageRecipes);
        }
        
        _hasMoreData = pageRecipes.length == _pageSize && endIndex < recipes.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('❌ 搜尋錯誤: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }
  
  // ===== 新增：清除搜尋 =====
  Future<void> _clearSearch() async {
    print('🔍 開始清除搜尋...');
    print('🔍 清除前 _isLoading: $_isLoading');
    
    setState(() {
      _searchController.clear();
      _selectedTags.clear();
      _isLoading = false;  // 確保重置載入狀態
      _isLoadingMore = false;
      _hasMoreData = true;
      _error = null;
      _recipes = []; // 清空現有食譜列表
    });
    
    print('🔍 清除後 _isLoading: $_isLoading');
    print('🔍 開始調用 _loadRecipes...');
    
    // 直接載入所有食譜
    await _loadRecipes();
    
    print('🔍 _loadRecipes 完成，當前食譜數: ${_recipes.length}');
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
  
  // ===== 新增：選擇分類 =====
  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    // 可以根據分類進行篩選或其他操作
    print('選擇分類: $category');
    // 這裡可以添加根據分類篩選食譜的邏輯
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
          backgroundColor: const Color(0xFFF8F9FA), 
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFFCCD5AE), 
            foregroundColor: const Color(0xFFFEFAE0), 
            title: const Text(
              '智慧食材辨識與食譜推薦',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFFFEFAE0),
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
                        Icon(Icons.logout, color: Color(0xFFD4A373)),
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
            selectedItemColor: const Color(0xFFD4A373), 
            unselectedItemColor: const Color(0xFF757575),
            selectedIconTheme: const IconThemeData(color: Color(0xFFD4A373)),
            selectedLabelStyle: const TextStyle(color: Color(0xFFD4A373)),
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
                icon: Icon(Icons.history),
                label: '瀏覽紀錄',
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
        return _buildHistoryTab();
      case 3:
        return _buildFavoritesTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      controller: _scrollController, // 新增：滾動控制器支援分頁
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用者問候部分
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '你好！${authProvider.user?.name ?? authProvider.user?.account ?? 'User123'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4A373),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '今天想做什麼料理？',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: 30,
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // 搜尋欄
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5DC),
              borderRadius: BorderRadius.circular(25),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _searchController,
                    hintText: '試試「番茄炒蛋」．．．．．．',
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      _performSearch();
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _clearSearch(),
                    child: const Icon(
                      Icons.clear,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 水平滾動標籤欄
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('家常菜', _selectedCategory == '家常菜', () => _selectCategory('家常菜')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('健康餐', _selectedCategory == '健康餐', () => _selectCategory('健康餐')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('湯品', _selectedCategory == '湯品', () => _selectCategory('湯品')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('甜點', _selectedCategory == '甜點', () => _selectCategory('甜點')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('義式', _selectedCategory == '義式', () => _selectCategory('義式')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('日式', _selectedCategory == '日式', () => _selectCategory('日式')),
                      const SizedBox(width: 8),
                      _buildCategoryChip('中式', _selectedCategory == '中式', () => _selectCategory('中式')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _selectedTags.isNotEmpty ? const Color(0xFFD4A373) : const Color(0xFFD4A373),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                style: IconButton.styleFrom(
                  backgroundColor: _selectedTags.isNotEmpty 
                      ? const Color(0xFFD4A373).withOpacity(0.1) 
                      : Colors.grey[100],
                ),
              ),
            ],
          ),
          
          // 篩選區塊（展開/收起）
          if (_showFilters)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(
                maxHeight: 400,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: _buildFilterSection(),
              ),
            ),
          
          const SizedBox(height: 20),
          
          // 推薦給你標題和類型說明
          Row(
            children: [
              const Text(
                '推薦給你',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4A373),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 推薦食譜橫向滾動列表
          _buildRecommendationsSection(),
          
          const SizedBox(height: 24),
          
          // 所有食譜標題
          const Text(
            '所有食譜',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4A373),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 食譜卡片網格（支援分頁）
          _buildRecipeGrid(),
          
          // 載入更多指示器
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraTab() {
    return const CameraScreen();
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
                    color: Color(0xFFD4A373),
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
                    selectedColor: const Color(0xFFD4A373).withOpacity(0.2),
                    checkmarkColor: const Color(0xFFD4A373),
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
  
  Widget _buildRecommendationsSection() {
    if (_isLoadingRecommendations) {
      return Container(
        height: 200,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4A373),
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.recommend,
                size: 32,
                color: Color(0xFFBDBDBD),
              ),
              SizedBox(height: 8),
              Text(
                _isLoadingRecommendations 
                    ? '載入推薦中...' 
                    : '瀏覽更多食譜來獲得個人化推薦',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
              ),
              if (!_isLoadingRecommendations)
                TextButton(
                  onPressed: _loadRecommendations,
                  child: Text('重新載入'),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 橫向滾動的推薦列表
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              final item = _recommendations[index];
              return _buildRecommendationCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item) {
    final imageUrl = _resolveImageUrl(item['image']?.toString() ?? '');
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            print('點擊推薦食譜: ${item['name']}, 圖片: ${item['image']}');
            _navigateToRecipeDetail(item);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 食譜圖片
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      color: const Color(0xFFF5F5F5),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / 
                                          loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: const Color(0xFFD4A373),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('圖片載入失敗: ${item['image']} - $error');
                                return _buildImagePlaceholder(100);
                              },
                            )
                          : _buildImagePlaceholder(100),
                    ),
                  ),
                  // 推薦標籤
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A373),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '推薦',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // 食譜資訊
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 食譜名稱
                      Text(
                        item['name'] ?? '未知食譜',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      
                      // 底部資訊
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item['likes'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const Spacer(),
                          if (item['cook_minutes'] != null)
                            Text(
                              '${item['cook_minutes']}分',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.restaurant,
            size: 24,
            color: Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 4),
          Text(
            '圖片載入中',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRecipeDetail(Map<String, dynamic> recipeData) {
    try {
      final recipe = Recipe.fromJson(recipeData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    } catch (e) {
      print('❌ 無法解析食譜數據: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟食譜詳情')),
      );
    }
  }

  String _resolveImageUrl(String image) {
    if (image.isEmpty) return image;
    if (!kIsWeb) return image;

    final encoded = Uri.encodeComponent(image);
    return '${ApiService.baseUrl}/image-proxy?url=$encoded';
  }

  Widget _buildFavoritesTab() {
    return const FavoritesScreen();
  }

  // ===== 新增：建立分類標籤 =====
  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4A373) : const Color(0xFFF5F5DC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4A373) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF666666),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ===== 新增：建立食譜網格 =====
  Widget _buildRecipeGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗：$_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecipes,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            '沒有找到食譜',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
    );
  }

  Widget _buildHistoryTab() {
    return const HistoryScreen();
  }
}