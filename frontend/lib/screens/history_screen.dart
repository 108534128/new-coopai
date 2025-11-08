import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    
    final data = await _apiService.getHistory(limit: 100);
    
    if (mounted) {
      setState(() {
        history = data;
        isLoading = false;
      });
      
      // Debug: 印出第一筆資料看看有沒有 image
      if (history.isNotEmpty) {
        print('📸 第一筆歷史記錄的圖片 URL: ${history[0]['image']}');
      }
    }
  }

  Future<void> _deleteHistoryItem(int historyId, int index) async {
    final success = await _apiService.deleteHistoryItem(historyId);
    
    if (success && mounted) {
      setState(() => history.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除歷史紀錄')),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    final result = await _apiService.clearHistory();
    
    if (result['success'] && mounted) {
      setState(() => history.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清空 ${result['deleted_count']} 筆歷史紀錄'),
        ),
      );
    }
  }

  String _formatTime(String? searchTime) {
    if (searchTime == null) return '';
    
    try {
      final dateTime = DateTime.parse(searchTime);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return '剛剛';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} 分鐘前';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} 小時前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} 天前';
      } else {
        return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE8F4F8), // 淺藍色標題欄
        foregroundColor: const Color(0xFF2C3E50), // 深灰藍色文字
        title: const Text(
          '歷史紀錄',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFF2C3E50)),
              tooltip: '清空歷史',
              onPressed: _showClearAllDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2C3E50)),
            tooltip: '重新整理',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF64B5F6),
              ),
            )
          : history.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
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
              color: const Color(0xFFE8F4F8).withOpacity(0.5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.history,
              size: 60,
              color: Color(0xFF8C9BA6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '還沒有瀏覽紀錄',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF424242),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '瀏覽過的食譜會顯示在這裡',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F8).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFF8C9BA6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '共 ${history.length} 筆紀錄 · 左滑可刪除',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHistory,
            color: const Color(0xFF64B5F6),
            child: ListView.builder(
              itemCount: history.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final item = history[index];
                return _buildHistoryCard(item, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, int index) {
    // Debug: 印出每筆資料的圖片 URL
    print('🖼️ 歷史記錄 ${item['name']}: ${item['image']}');
    
    return Dismissible(
      key: Key('history_${item['history_uid']}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              '刪除',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認刪除'),
            content: const Text('確定要刪除這筆歷史紀錄嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('刪除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteHistoryItem(item['history_uid'], index);
      },
      child: Card(
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
            leading: _buildRecipeImage(item['image']),
            title: Text(
              item['name'] ?? '未命名食譜',
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4F8).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        size: 12,
                        color: Color(0xFF8C9BA6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(item['search_time']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ],
                ),
                if (item['tag'] != null && item['tag'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
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
                            item['tag'],
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
              ],
            ),
            onTap: () {
              try {
                final recipeObj = Recipe.fromJson(item);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(recipe: recipeObj),
                  ),
                ).then((_) => _loadHistory());
              } catch (e) {
                print('轉換 Recipe 錯誤: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('無法開啟食譜詳情')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeImage(dynamic imageUrl) {
    // 處理 imageUrl 可能是 null 或空字串的情況
    final String? url = imageUrl?.toString();
    
    print('🔍 正在處理圖片 URL: $url');
    
    if (url == null || url.isEmpty || url == 'null') {
      print('❌ 圖片 URL 為空,顯示預設圖示');
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

    // 如果是在 Web 環境且不是本機 URL,使用 image proxy
    String finalImageUrl = url;
    if (kIsWeb && !url.startsWith('http://localhost') && !url.startsWith('https://localhost')) {
      final encoded = Uri.encodeComponent(url);
      finalImageUrl = '${ApiService.baseUrl}/image-proxy?url=$encoded';
      print('🌐 使用 proxy URL: $finalImageUrl');
    } else {
      print('📍 直接使用原始 URL: $url');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        finalImageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ 圖片載入失敗: $error');
          print('❌ URL: $finalImageUrl');
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
          if (loadingProgress == null) {
            print('✅ 圖片載入完成');
            return child;
          }
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
                color: Color(0xFF64B5F6),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空歷史紀錄'),
        content: Text('確定要清空所有 ${history.length} 筆歷史紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistory();
            },
            child: const Text('確定清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}