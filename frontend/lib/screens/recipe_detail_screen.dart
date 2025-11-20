import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../widgets/favorite_button.dart';
import '../services/api_service.dart';
import 'recipe_walkthrough_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isIngredientsExpanded = false;
  bool _isStepsExpanded = false;
  bool _isTimePortionExpanded = false;

  @override
  void initState() {
    super.initState();
    // 自動記錄到歷史
    _addToHistory();
  }

  Future<void> _addToHistory() async {
    await _apiService.addHistory(widget.recipe.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFCCD5AE), // 米綠色標題欄（與首頁一致）
        foregroundColor: const Color(0xFFFEFAE0), // 米白色文字
        title: Text(
          widget.recipe.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFEFAE0),
          ),
        ),
        actions: [
          // 愛心按鈕
          FavoriteButton(
            recipeId: widget.recipe.uid,
            size: 28,
            onFavoriteChanged: (isFavorite) {
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 食譜卡片(包含圖片)
              Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
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
                        ),
                        if (widget.recipe.image.isNotEmpty)
                          Image.network(
                            _resolveImageUrl(widget.recipe.image),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF64B5F6),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error_outline, color: Color(0xFFB0BEC5)),
                              );
                            },
                          )
                        else
                          const Center(
                            child: Icon(Icons.image_not_supported, color: Color(0xFFB0BEC5)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 食譜名稱
              Text(
                widget.recipe.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF32201C),
                ),
              ),
              const SizedBox(height: 20),
              
              // 標籤（移到按鈕上方）
              if (widget.recipe.tag.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.recipe.tag.split(',').map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5DC), // 米色
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD4A373).withOpacity(0.3), // 咖啡色邊框
                        ),
                      ),
                      child: Text(
                        tag.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF32201C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // 三個按鈕
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isTimePortionExpanded = !_isTimePortionExpanded;
                        });
                      },
                      icon: Icon(
                        _isTimePortionExpanded ? Icons.access_time : Icons.access_time_outlined,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text('時間與份量', style: TextStyle(fontSize: 12)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTimePortionExpanded
                            ? const Color(0xFFF5F5DC) // 米色
                            : Colors.white,
                        foregroundColor: const Color(0xFF32201C),
                        elevation: _isTimePortionExpanded ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isTimePortionExpanded
                                ? const Color(0xFFD4A373) // 咖啡色邊框
                                : const Color(0xFFE0E0E0).withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isIngredientsExpanded = !_isIngredientsExpanded;
                        });
                      },
                      icon: Icon(
                        _isIngredientsExpanded ? Icons.restaurant_menu : Icons.restaurant_menu_outlined,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text('食材', style: TextStyle(fontSize: 12)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isIngredientsExpanded
                            ? const Color(0xFFF5F5DC) // 米色
                            : Colors.white,
                        foregroundColor: const Color(0xFF32201C),
                        elevation: _isIngredientsExpanded ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isIngredientsExpanded
                                ? const Color(0xFFD4A373) // 咖啡色邊框
                                : const Color(0xFFE0E0E0).withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isStepsExpanded = !_isStepsExpanded;
                        });
                      },
                      icon: Icon(
                        _isStepsExpanded ? Icons.menu_book : Icons.menu_book_outlined,
                        size: 16,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text('烹飪步驟', style: TextStyle(fontSize: 12)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isStepsExpanded
                            ? const Color(0xFFF5F5DC) // 米色
                            : Colors.white,
                        foregroundColor: const Color(0xFF32201C),
                        elevation: _isStepsExpanded ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isStepsExpanded
                                ? const Color(0xFFD4A373) // 咖啡色邊框
                                : const Color(0xFFE0E0E0).withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // 時間與份量區塊（點擊按鈕後顯示）
              if (_isTimePortionExpanded)
                Card(
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5DC).withOpacity(0.5), // 米色
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.access_time, size: 20, color: Color(0xFFD4A373)), // 咖啡色
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.recipe.cookMinutes != null 
                                ? '${widget.recipe.cookMinutes} 分鐘' 
                                : '時間未指定',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF424242),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5DC).withOpacity(0.5), // 米色
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.restaurant, size: 20, color: Color(0xFFD4A373)), // 咖啡色
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.recipe.porsi.isNotEmpty 
                                ? widget.recipe.porsi 
                                : '份量未指定',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF424242),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // 食材列表（點擊按鈕後顯示）
              if (_isIngredientsExpanded) ...[
                const SizedBox(height: 24),
                Card(
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4F8).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  size: 20,
                                  color: Color(0xFF8C9BA6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '食材清單',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF32201C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...widget.recipe.ingredientsList.map(
                            (ingredient) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Color(0xFFD8E2DA),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      ingredient,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF424242),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              
              // 烹飪步驟（點擊按鈕後顯示）
              if (_isStepsExpanded) ...[
                const SizedBox(height: 24),
                Card(
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4F8).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.menu_book,
                                  size: 20,
                                  color: Color(0xFF8C9BA6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '烹飪步驟',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF32201C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...widget.recipe.instructionsList.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 步驟編號
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1D6DA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 步驟內容
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0).withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        entry.value,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.6,
                                          color: Color(0xFF424242),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ], 
              const SizedBox(height: 24),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 8 + MediaQuery.of(context).viewPadding.bottom, 
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWalkthrough(context, widget.recipe),
                      icon: const Icon(Icons.menu_book_outlined, size: 20),
                      label: const Text(
                        '開始步驟教學',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A373), // 咖啡色
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ],
          ),
        ),
      ),
    );
  }

  String _resolveImageUrl(String image) {
    if (image.isEmpty) return image;
    if (!kIsWeb) return image;

    final encoded = Uri.encodeComponent(image);
    return '${ApiService.baseUrl}/image-proxy?url=$encoded';
  }

  void _openWalkthrough(BuildContext context, Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeWalkthroughScreen(recipe: recipe),
      ),
    );
  }
}
