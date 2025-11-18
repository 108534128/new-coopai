import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> favorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    
    final data = await _apiService.getFavorites();
    
    if (mounted) {
      setState(() {
        favorites = data;
        isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String recipeId, int index) async {
    final result = await _apiService.removeFavorite(recipeId);
    
    if (result['success'] && mounted) {
      setState(() => favorites.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFCCD5AE), // 米綠色標題欄（與首頁一致）
        foregroundColor: const Color(0xFFFEFAE0), // 米白色文字
        title: const Text(
          '我的最愛',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFEFAE0),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFEFAE0)),
            tooltip: '重新整理',
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4A373), // 咖啡色（與首頁一致）
              ),
            )
          : favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5DC).withOpacity(0.5), // 米色背景
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 60,
              color: Color(0xFFD4A373), // 咖啡色圖示
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '還沒有最愛的食譜',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF424242),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊食譜頁面的愛心按鈕加入最愛',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: const Color(0xFFD4A373), // 咖啡色
      child: ListView.builder(
        itemCount: favorites.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final recipe = favorites[index];
          return _buildRecipeCard(recipe, index);
        },
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _buildRecipeImage(recipe['image']),
          title: Text(
            recipe['name'] ?? '未命名食譜',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (recipe['tag'] != null && recipe['tag'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4F8).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.label,
                          size: 12,
                          color: Color(0xFF8C9BA6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          recipe['tag'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF424242),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (recipe['cook_minutes'] != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5DC).withOpacity(0.5), // 米色
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        size: 12,
                        color: Color(0xFFD4A373), // 咖啡色
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${recipe['cook_minutes']} 分鐘',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red, size: 28),
            onPressed: () => _showRemoveDialog(recipe, index),
          ),
          onTap: () {
            // 將 Map 轉換成 Recipe 物件
            try {
              final recipeObj = Recipe.fromJson(recipe);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(recipe: recipeObj),
                ),
              ).then((_) => _loadFavorites());
            } catch (e) {
              print('轉換 Recipe 錯誤: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('無法開啟食譜詳情')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE0E0E0),
              const Color(0xFFF5F5F5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.restaurant,
          size: 35,
          color: Color(0xFFB0BEC5),
        ),
      );
    }

    // 如果是在 Web 環境,使用 image proxy
    String finalImageUrl = imageUrl;
    if (kIsWeb && !imageUrl.startsWith('http://localhost') && !imageUrl.startsWith('https://localhost')) {
      final encoded = Uri.encodeComponent(imageUrl);
      finalImageUrl = '${ApiService.baseUrl}/image-proxy?url=$encoded';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        finalImageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('圖片載入錯誤: $error');
          print('圖片 URL: $imageUrl');
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE0E0E0),
                  const Color(0xFFF5F5F5),
                ],
              ),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 35,
              color: Color(0xFFB0BEC5),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE0E0E0),
                  const Color(0xFFF5F5F5),
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4A373), // 咖啡色
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRemoveDialog(Map<String, dynamic> recipe, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除最愛'),
        content: Text('確定要將「${recipe['name'] ?? '此食譜'}」從最愛中移除嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFavorite(recipe['uid'], index);
            },
            child: const Text('確定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}