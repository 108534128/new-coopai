import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/recipe.dart';

class ApiService {
  // Allow overriding the API host at build/run time with --dart-define=API_HOST
  // Examples:
  // flutter run -d chrome --dart-define=API_HOST=http://localhost:5000
  // flutter run -d emulator-5554 --dart-define=API_HOST=http://192.168.1.5:5000
  static const String _envApiHost = String.fromEnvironment('API_HOST', defaultValue: '');

  static String get baseUrl {
    if (_envApiHost.isNotEmpty) {
      // ensure no trailing slash
      return _envApiHost.replaceAll(RegExp(r'\/+\$'), '') + '/api';
    }

    // Default behavior: on web use localhost, on Android emulator use 10.0.2.2
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    // Android emulator maps host machine's localhost to 10.0.2.2
    return 'http://10.0.2.2:5000/api';
  }
  
  // 獲取儲存的token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // 儲存token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  // 刪除token
  Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // 獲取請求頭
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 獲取食譜列表
  Future<List<Recipe>> getRecipes({int page = 1, int perPage = 10}) async {
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

  // 獲取單個食譜詳情
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

  // 健康檢查
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

  // 用戶註冊
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

  // 用戶登入
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
        // 儲存token
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

  // 獲取用戶資料
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

  // 更新用戶資料
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

  // 用戶登出
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
      // 即使登出失敗也要清除本地token
      await _removeToken();
    }
  }

  // 檢查是否已登入
  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }
}
