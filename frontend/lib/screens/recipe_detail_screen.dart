import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../screens/recipe_walkthrough_screen.dart';
import '../services/api_service.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cookMinutes = recipe.cookMinutes;
    final showCookTime = cookMinutes != null && cookMinutes > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.grey[200]),
                      if (recipe.image.isNotEmpty)
                        Image.network(
                          _resolveImageUrl(recipe.image),
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
              Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.updatedAt.isNotEmpty)
                    Text(
                      '上次更新時間: ${recipe.updatedAt}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (showCookTime) ...[
                Text(
                  '時間:  $cookMinutes mins ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                '食材',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...recipe.ingredientsList.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('- $ingredient'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '步驟',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...recipe.instructionsList.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${entry.key + 1}. ${entry.value}'),
                ),
              ),
              if (recipe.instructionsList.isNotEmpty) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _openWalkthrough(context),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('開始步驟教學'),
                  ),
                ),
              ],
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

  void _openWalkthrough(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeWalkthroughScreen(recipe: recipe),
      ),
    );
  }
}
