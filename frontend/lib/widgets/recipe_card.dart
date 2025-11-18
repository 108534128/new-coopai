//frontend/lib/widgets/recipe_card.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    Key? key,
    required this.recipe,
    this.onTap,
  }) : super(key: key);

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  final ApiService _apiService = ApiService();
  bool isFavorite = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final status = await _apiService.checkFavorite(widget.recipe.uid);
    if (mounted) {
      setState(() => isFavorite = status);
    }
  }

  Future<void> _toggleFavorite() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    Map<String, dynamic> result;
    if (isFavorite) {
      result = await _apiService.removeFavorite(widget.recipe.uid);
    } else {
      result = await _apiService.addFavorite(widget.recipe.uid);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['success']) {
          isFavorite = !isFavorite;
        }
      });

      // 顯示提示訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? const Color.fromARGB(255, 109, 161, 111) : const Color.fromARGB(255, 139, 77, 72),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(widget.recipe.image);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.grey[200]),
                      Image.network(
                        imageUrl,
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
                      ),
                      // 愛心按鈕 - 放在圖片右上角
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Color(0xFFD4A373) : Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: _toggleFavorite,
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recipe.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.recipe.cookMinutes != null 
                                  ? '${widget.recipe.cookMinutes} mins' 
                                  : 'N/A',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.thumb_up, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.recipe.likes} likes',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
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

  String _resolveImageUrl(String image) {
    if (image.isEmpty) return image;
    if (!kIsWeb) return image;

    final encoded = Uri.encodeComponent(image);
    return '${ApiService.baseUrl}/image-proxy?url=$encoded';
  }
}