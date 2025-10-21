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
      appBar: AppBar(
        title: Text(widget.recipe.name),
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
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.grey[200]),
                      if (widget.recipe.image.isNotEmpty)
                        Image.network(
                          _resolveImageUrl(widget.recipe.image),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error_outline, color: Colors.grey),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                    ],
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
                ),
              ),
              const SizedBox(height: 8),
              
              // 烹飪時間和份量
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    widget.recipe.cookMinutes != null 
                        ? '${widget.recipe.cookMinutes} 分鐘' 
                        : '時間未指定',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.restaurant, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    widget.recipe.porsi.isNotEmpty 
                        ? widget.recipe.porsi 
                        : '份量未指定',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              // 標籤
              if (widget.recipe.tag.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: widget.recipe.tag.split(',').map((tag) {
                    return Chip(
                      label: Text(tag.trim()),
                      backgroundColor: Colors.green[50],
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // 食材列表
              const Text(
                '食材',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.recipe.ingredientsList.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // 烹飪步驟
              const Text(
                '烹飪步驟',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.recipe.instructionsList.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 步驟編號
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 步驟內容
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ), 
              const SizedBox(height: 24),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 8 + MediaQuery.of(context).viewPadding.bottom, 
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWalkthrough(context, widget.recipe),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('開始步驟教學'),
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
