// frontend/lib/screens/recipe_search_result_screen.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class RecipeSearchResultScreen extends StatelessWidget {
  final Map<String, int> detectedIngredients;
  final List<Recipe> recipes;

  const RecipeSearchResultScreen({
    super.key,
    required this.detectedIngredients,
    required this.recipes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCD5AE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF32201C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '相關食譜',
          style: TextStyle(
            color: Color(0xFF32201C),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // 偵測到的食材區塊
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    const Text(
                      '辨識到的食材',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF32201C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detectedIngredients.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5DC), // 米色
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD4A373).withOpacity(0.3), // 咖啡色邊框
                        ),
                      ),
                      child: Text(
                        '${entry.key} × ${entry.value}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF32201C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // 食譜列表
          Expanded(
            child: recipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '未找到相關食譜',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = recipes[index];
                            return RecipeCard(
                              recipe: recipe,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailScreen(recipe: recipe),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
