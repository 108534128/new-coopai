// frontend/lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Recipe> _searchResults = [];
  List<Map<String, dynamic>> _categories = [];
  Map<int, List<Map<String, dynamic>>> _keywordsByCategory = {};
  List<String> _allTags = [];
  
  bool _isLoading = false;
  bool _isLoadingFilters = true;
  String? _errorMessage;
  
  // 選中的篩選條件
  Set<String> _selectedTags = {};
  Set<int> _selectedCategoryIds = {};
  Set<int> _selectedKeywordIds = {};
  
  // 顯示模式
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadFiltersData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 載入篩選資料（分類、關鍵字、標籤）
  Future<void> _loadFiltersData() async {
    setState(() {
      _isLoadingFilters = true;
    });

    try {
      // 並行載入所有資料
      final results = await Future.wait([
        _apiService.getCategories(),
        _apiService.getAllTags(),
      ]);

      _categories = results[0] as List<Map<String, dynamic>>;
      _allTags = results[1] as List<String>;

      // 載入每個分類的關鍵字
      for (var category in _categories) {
        final categoryId = category['id'] as int;
        final keywords = await _apiService.getKeywordsByCategory(categoryId);
        _keywordsByCategory[categoryId] = keywords;
      }

      setState(() {
        _isLoadingFilters = false;
      });
    } catch (e) {
      print('❌ 載入篩選資料錯誤: $e');
      setState(() {
        _isLoadingFilters = false;
        _errorMessage = '載入篩選資料失敗';
      });
    }
  }

  /// 執行搜尋
  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.searchRecipes(
        keyword: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        tags: _selectedTags.isEmpty ? null : _selectedTags.toList(),
        categoryIds: _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds.map((id) => id.toString()).toList(),
        keywordIds: _selectedKeywordIds.isEmpty ? null : _selectedKeywordIds.map((id) => id.toString()).toList(),
        limit: 100,
      );

      if (result['success'] == true) {
        setState(() {
          _searchResults = result['recipes'] as List<Recipe>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _errorMessage = result['error'] ?? '搜尋失敗';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _errorMessage = '搜尋發生錯誤: $e';
        _isLoading = false;
      });
    }
  }

  /// 清除所有篩選條件
  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedTags.clear();
      _selectedCategoryIds.clear();
      _selectedKeywordIds.clear();
      _searchResults.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋食譜'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? '隱藏篩選' : '顯示篩選',
          ),
          if (_searchController.text.isNotEmpty || 
              _selectedTags.isNotEmpty || 
              _selectedCategoryIds.isNotEmpty || 
              _selectedKeywordIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
              tooltip: '清除篩選',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋框
          _buildSearchBar(),
          
          // 篩選區域
          if (_showFilters) _buildFiltersSection(),
          
          // 搜尋結果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  /// 搜尋框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入食譜名稱、食材或關鍵字...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '搜尋',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 篩選區域
  Widget _buildFiltersSection() {
    if (_isLoadingFilters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標籤篩選
            if (_allTags.isNotEmpty) _buildTagsFilter(),
            
            const Divider(),
            
            // 分類和關鍵字篩選
            if (_categories.isNotEmpty) _buildCategoriesFilter(),
          ],
        ),
      ),
    );
  }

  /// 標籤篩選
  Widget _buildTagsFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '標籤篩選',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 分類和關鍵字篩選
  Widget _buildCategoriesFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分類篩選',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._categories.map((category) {
            final categoryId = category['id'] as int;
            final categoryName = category['category_name'] as String;
            final keywords = _keywordsByCategory[categoryId] ?? [];
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  categoryName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: keywords.map((keyword) {
                        final keywordId = keyword['id'] as int;
                        final keywordName = keyword['keyword_name'] as String;
                        final isSelected = _selectedKeywordIds.contains(keywordId);
                        
                        return FilterChip(
                          label: Text(keywordName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedKeywordIds.add(keywordId);
                                _selectedCategoryIds.add(categoryId);
                              } else {
                                _selectedKeywordIds.remove(keywordId);
                                // 檢查該分類下是否還有其他被選中的關鍵字
                                final hasOtherSelected = keywords.any((kw) => 
                                  kw['id'] != keywordId && 
                                  _selectedKeywordIds.contains(kw['id'] as int)
                                );
                                if (!hasOtherSelected) {
                                  _selectedCategoryIds.remove(categoryId);
                                }
                              }
                            });
                          },
                          selectedColor: Colors.green.shade100,
                          checkmarkColor: Colors.green,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 搜尋結果
  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('重
                試'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '輸入關鍵字或選擇篩選條件開始搜尋',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final recipe = _searchResults[index];
        return RecipeCard(recipe: recipe);
      },
    );
  }
}


