// frontend/lib/services/api_service.dart


import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/recipe.dart';

class ApiService {
  static const String _envApiHost = String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_envApiHost.isNotEmpty) {
      return _envApiHost.replaceAll(RegExp(r'\/+\$'), '') + '/api';
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
  }
  
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================== 食譜相關 ====================

  Future<List<Recipe>> getRecipes({int page = 1, int perPage = 200}) async {
    try {
      print('🔍 正在獲取食譜列表...');
      print('📍 URL: $baseUrl/recipes?page=$page&per_page=$perPage');
      
      final headers = await _getHeaders();
      print('🔑 Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/recipes?page=$page&per_page=$perPage'),
        headers: headers,
      );

      print('📤 Response status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!data.containsKey('recipes')) {
          print('❌ Response does not contain recipes key');
          print('🔍 Available keys: ${data.keys.toList()}');
          throw Exception('Invalid response format: missing recipes key');
        }
        
        final List<dynamic> recipesJson = data['recipes'];
        print('📊 Found ${recipesJson.length} recipes');
        
        final recipes = recipesJson.map((json) {
          try {
            return Recipe.fromJson(json);
          } catch (e) {
            print('❌ Error parsing recipe: $e');
            print('🔍 Problematic JSON: $json');
            rethrow;
          }
        }).toList();
        
        print('✅ Successfully loaded ${recipes.length} recipes');
        return recipes;
      } else {
        final errorBody = response.body;
        print('❌ Server returned ${response.statusCode}');
        print('❌ Error body: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching recipes: $e');
      print('📋 Stack trace: $stackTrace');
      throw Exception('Failed to load recipes: $e');
    }
  }

  // ==================== 新增：搜尋食譜 ====================
  Future<List<Recipe>> searchRecipes({
    String? searchText,
    List<String>? tags,
    int page = 1,
    int perPage = 200,
  }) async {
    try {
      print('🔍 正在搜尋食譜...');
      print('📝 搜尋文字: $searchText');
      print('🏷️ 標籤: $tags');
      
      // 建立基礎 URL 字串
      String urlString = '$baseUrl/recipes/search?page=$page&per_page=$perPage';
      
      // 添加搜尋文字參數
      if (searchText != null && searchText.isNotEmpty) {
        urlString += '&q=${Uri.encodeComponent(searchText)}';
      }
      
      // 添加多個標籤參數（每個標籤都用 tags= 參數）
      if (tags != null && tags.isNotEmpty) {
        for (var tag in tags) {
          urlString += '&tags=${Uri.encodeComponent(tag)}';
        }
      }
      
      final uri = Uri.parse(urlString);
      print('📍 搜尋 URL: $uri');
      
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers);

      print('📤 Response status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!data.containsKey('recipes')) {
          print('❌ Response does not contain recipes key');
          throw Exception('Invalid response format: missing recipes key');
        }
        
        final List<dynamic> recipesJson = data['recipes'];
        print('📊 Found ${recipesJson.length} recipes');
        
        final recipes = recipesJson.map((json) {
          try {
            return Recipe.fromJson(json);
          } catch (e) {
            print('❌ Error parsing recipe: $e');
            print('🔍 Problematic JSON: $json');
            rethrow;
          }
        }).toList();
        
        print('✅ Successfully loaded ${recipes.length} recipes');
        return recipes;
      } else {
        final errorBody = response.body;
        print('❌ Server returned ${response.statusCode}');
        print('❌ Error body: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }
    } catch (e, stackTrace) {
      print('❌ Error searching recipes: $e');
      print('📋 Stack trace: $stackTrace');
      throw Exception('Failed to search recipes: $e');
    }
  }

  // ==================== 新增：取得所有分類 ====================
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> categoriesJson = data['categories'];
        return List<Map<String, dynamic>>.from(categoriesJson);
      }
      return [];
    } catch (e) {
      print('❌ 取得分類錯誤: $e');
      return [];
    }
  }

  // ==================== 新增：取得關鍵字 ====================
  Future<List<Map<String, dynamic>>> getKeywords({int? categoryId}) async {
    try {
      String url = '$baseUrl/keywords';
      if (categoryId != null) {
        url += '?category_id=$categoryId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keywordsJson = data['keywords'];
        return List<Map<String, dynamic>>.from(keywordsJson);
      }
      return [];
    } catch (e) {
      print('❌ 取得關鍵字錯誤: $e');
      return [];
    }
  }

  // ==================== 獲取單個食譜詳情 ====================
  Future<Recipe> getRecipeDetails(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recipes/$recipeId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final recipeJson = data['recipe'];
        if (recipeJson is Map<String, dynamic>) {
          return Recipe.fromJson(recipeJson);
        }
        throw Exception('Invalid response format: missing recipe data');
      } else {
        throw Exception('Failed to load recipe details');
      }
    } catch (e) {
      print('Error fetching recipe details: $e');
      throw Exception('Failed to load recipe details');
    }
  }

  // ==================== 用戶相關 ====================

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('健康檢查失敗: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'account': account,
          'password': password,
          'name': name,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? '註冊失敗');
      }
    } catch (e) {
      throw Exception('註冊失敗: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'account': account,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
        }
        return data;
      } else {
        throw Exception(data['message'] ?? '登入失敗');
      }
    } catch (e) {
      throw Exception('登入失敗: $e');
    }
  }

  Future<User> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return User.fromJson(data['user']);
      } else {
        throw Exception(data['message'] ?? '獲取資料失敗');
      }
    } catch (e) {
      throw Exception('獲取用戶資料失敗: $e');
    }
  }

  Future<User> updateProfile({
    String? name,
    String? account,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
        body: json.encode({
          if (name != null) 'name': name,
          if (account != null) 'account': account,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return User.fromJson(data['user']);
      } else {
        throw Exception(data['message'] ?? '更新失敗');
      }
    } catch (e) {
      throw Exception('更新用戶資料失敗: $e');
    }
  }

  Future<void> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        await _removeToken();
      }
    } catch (e) {
      await _removeToken();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }

  // ==================== 我的最愛相關 ====================

  Future<Map<String, dynamic>> addFavorite(String recipeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/favorites'),
        headers: await _getHeaders(),
        body: json.encode({'recipe_id': recipeId}),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? '成功加入最愛',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '加入最愛失敗',
        };
      }
    } catch (e) {
      print('❌ 加入最愛錯誤: $e');
      return {'success': false, 'message': '發生錯誤: $e'};
    }
  }

  Future<Map<String, dynamic>> removeFavorite(String recipeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/favorites/$recipeId'),
        headers: await _getHeaders(),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? '成功移除最愛',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '移除最愛失敗',
        };
      }
    } catch (e) {
      print('❌ 移除最愛錯誤: $e');
      return {'success': false, 'message': '發生錯誤: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/favorites'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> favoritesJson = data['favorites'];
        return List<Map<String, dynamic>>.from(favoritesJson);
      }
      return [];
    } catch (e) {
      print('❌ 取得最愛清單錯誤: $e');
      return [];
    }
  }

  Future<bool> checkFavorite(String recipeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/favorites/check/$recipeId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_favorite'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ 檢查最愛狀態錯誤: $e');
      return false;
    }
  }

  // ==================== 歷史紀錄相關 ====================

  Future<bool> addHistory(String recipeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/history'),
        headers: await _getHeaders(),
        body: json.encode({'recipe_id': recipeId}),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ 新增歷史紀錄錯誤: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/history?limit=$limit'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> historyJson = data['history'];
        return List<Map<String, dynamic>>.from(historyJson);
      }
      return [];
    } catch (e) {
      print('❌ 取得歷史紀錄錯誤: $e');
      return [];
    }
  }

  Future<bool> deleteHistoryItem(int historyId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/history/$historyId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ 刪除歷史紀錄錯誤: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> clearHistory() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/history/clear'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'deleted_count': data['deleted_count'],
        };
      }
      return {'success': false, 'message': '清空失敗'};
    } catch (e) {
      print('❌ 清空歷史紀錄錯誤: $e');
      return {'success': false, 'message': '發生錯誤: $e'};
    }
  }
}






