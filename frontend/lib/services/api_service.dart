// frontend/lib/services/api_service.dart


import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/recipe.dart';

class ApiService {
  static const String _envApiHost = String.fromEnvironment('API_HOST', defaultValue: '');
  static String? _cachedBaseUrl;
  
  // 取得可能的主機地址清單
  static List<String> _getPossibleHosts() {
    final hosts = <String>[
      'localhost:5000',
      '127.0.0.1:5000',
      '10.0.2.2:5000',  // Android 模擬器
    ];
    
    // 添加常見的私有網路 IP
    const commonIPs = [1, 100, 101, 150, 200];
    for (final ip in commonIPs) {
      hosts.addAll([
        '192.168.0.$ip:5000',
        '192.168.1.$ip:5000',
      ]);
    }
    
    return hosts;
  }

  static String get baseUrl {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    
    if (_envApiHost.isNotEmpty) {
      return _envApiHost.replaceAll(RegExp(r'\/+\$'), '') + '/api';
    }
    
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:5000/api';
      }
      return 'http://$host:5000/api';
    }
    
    return 'http://localhost:5000/api';
  }
  
  static void resetBaseUrl() => _cachedBaseUrl = null;
  
  static void setCustomBaseUrl(String host) {
    _cachedBaseUrl = 'http://$host/api';
  }
  
  // 測試連接並自動選擇最佳的 API 地址
  static Future<String?> findBestApiHost() async {
    debugPrint('🔍 開始尋找最佳 API 地址...');
    
    // 優先嘗試環境變數中指定的主機
    if (_envApiHost.isNotEmpty) {
      try {
        final envHost = _envApiHost.replaceAll(RegExp(r'https?://'), '').replaceAll('/api', '');
        final testUrl = 'http://$envHost/api/health';
        debugPrint('🌐 測試環境變數主機: $testUrl');
        
        final response = await http.get(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          debugPrint('✅ 環境變數主機連接成功: $envHost');
          setCustomBaseUrl(envHost);
          return envHost;
        }
      } catch (e) {
        debugPrint('❌ 環境變數主機連接失敗: $e');
      }
    }
    
    final possibleHosts = await _getPossibleHosts();
    
    for (String host in possibleHosts) {
      try {
        final testUrl = 'http://$host/api/health';
        debugPrint('🌐 測試連接: $testUrl');
        
        final response = await http.get(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          debugPrint('✅ 連接成功: $host');
          setCustomBaseUrl(host);
          setCustomBaseUrl(host);
          return host;
        }
      } catch (e) {
        debugPrint('❌ 連接失敗: $host - ${e.toString().split('\n').first}');
      }
    }
    
    debugPrint('⚠️ 所有地址都無法連接，使用默認地址');
    return null;
  }

  // 測試當前 API 連接
  static Future<bool> testConnection() async {
    try {
      final url = baseUrl;
      debugPrint('🔍 測試 API 連接: $url/health');
      
      // 確保使用 HTTP 協議並設置明確的 headers
      final uri = Uri.parse('$url/health');
      debugPrint('🌐 連接 URI: $uri (協議: ${uri.scheme})');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Connection': 'close', // 避免連接複用問題
        },
      ).timeout(const Duration(seconds: 3));
      
      final success = response.statusCode == 200;
      debugPrint(success ? '✅ API 連接測試成功' : '❌ API 連接測試失敗: ${response.statusCode}');
      return success;
    } catch (e) {
      debugPrint('❌ API 連接測試異常: $e');
      return false;
    }
  }

  // 智能掃描並自動設定最佳 API 地址
  static Future<String?> autoDetectApiHost() async {
    debugPrint('🔍 開始智能掃描 API 地址...');
    
    // 首先測試當前配置的地址
    if (await testConnection()) {
      debugPrint('✅ 當前配置的地址可用');
      return baseUrl;
    }
    
    // 掃描所有可能的地址
    final possibleHosts = await _getPossibleHosts();
    for (String host in possibleHosts) {
      try {
        final testUrl = 'http://$host/api/health';
        debugPrint('🌐 掃描: $testUrl');
        
        final response = await http.get(
          Uri.parse(testUrl),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 2)); // 縮短到 2 秒加快掃描
        
        if (response.statusCode == 200) {
          debugPrint('✅ 找到可用的 API 地址: $host');
          // 強制更新配置
          setCustomBaseUrl(host);
          return 'http://$host/api';
        }
      } catch (e) {
        debugPrint('❌ 掃描失敗: $host - ${e.toString().split('\n').first}');
      }
    }
    
    debugPrint('⚠️ 未找到可用的 API 地址，可能需要：');
    debugPrint('   1. 檢查後端服務是否運行');
    debugPrint('   2. 配置防火牆允許 5000 端口');
    debugPrint('   3. 確認手機和電腦在同一網路');
    
    return null;
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

  Future<List<Recipe>> getRecipes({int page = 1, int perPage = 50, int retryCount = 0}) async {
    try {
      // 如果沒有緩存的 URL，先進行智能掃描
      if (_cachedBaseUrl == null && !kIsWeb) {
        debugPrint('🔍 首次請求，執行智能 API 掃描...');
        await autoDetectApiHost(); // 自動掃描並設置最佳 URL
      }

      debugPrint('🔍 正在獲取食譜列表... (嘗試 ${retryCount + 1})');
      debugPrint('📍 URL: $baseUrl/recipes?page=$page&per_page=$perPage');
      
      final headers = await _getHeaders();
      debugPrint('🔑 Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/recipes?page=$page&per_page=$perPage'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30), // 增加超時時間到 30 秒
        onTimeout: () {
          debugPrint('⏰ 請求超時 (30秒)');
          throw Exception('請求超時，請檢查網絡連接');
        },
      );

      debugPrint('📤 Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!data.containsKey('recipes')) {
          debugPrint('❌ Response does not contain recipes key');
          debugPrint('🔍 Available keys: ${data.keys.toList()}');
          throw Exception('Invalid response format: missing recipes key');
        }
        
        final List<dynamic> recipesJson = data['recipes'];
        debugPrint('📊 Found ${recipesJson.length} recipes');
        
        final recipes = recipesJson.map((json) {
          try {
            return Recipe.fromJson(json);
          } catch (e) {
            debugPrint('❌ Error parsing recipe: $e');
            rethrow;
          }
        }).toList();
        
        debugPrint('✅ Successfully loaded ${recipes.length} recipes');
        return recipes;
      } else {
        final errorBody = response.body;
        debugPrint('❌ Server returned ${response.statusCode}');
        debugPrint('❌ Error body: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      debugPrint('❌ Error fetching recipes (attempt ${retryCount + 1}): $e');
      
      // 如果是連接關閉或網路問題，且未超過重試次數，則重試
      if (retryCount < 2 && (
          e.toString().contains('Connection closed') ||
          e.toString().contains('ClientException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('請求超時'))) {
        
        debugPrint('🔄 檢測到連接問題，等待 2 秒後重試...');
        await Future.delayed(const Duration(seconds: 2));
        
        // 如果是第一次重試，嘗試重新掃描 API 地址
        if (retryCount == 0 && !kIsWeb) {
          debugPrint('🔍 重新掃描 API 地址...');
          await autoDetectApiHost();
        }
        
        return await getRecipes(
          page: page,
          perPage: perPage,
          retryCount: retryCount + 1,
        );
      }
      
      // 超過重試次數或其他錯誤
      throw Exception('載入食譜失敗 (已重試 ${retryCount + 1} 次):\n$e\n\n建議：\n• 檢查網路連接\n• 確認後端服務正在運行\n• 嘗試重新啟動應用');
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
    int retryCount = 0,
  }) async {
    try {
      final url = '$baseUrl/login';
      debugPrint('🔐 嘗試登入: $url');
      debugPrint('👤 帳號: $account');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'account': account,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 5), // 縮短超時時間到 5 秒
        onTimeout: () {
          debugPrint('⏰ 登入請求超時 (5秒)');
          throw Exception('登入請求超時');
        },
      );

      debugPrint('📤 登入回應狀態碼: ${response.statusCode}');
      debugPrint('📥 登入回應內容: ${response.body}');

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
          debugPrint('✅ 登入成功，Token 已儲存');
        }
        return data;
      } else {
        final errorMsg = data['message'] ?? '登入失敗';
        debugPrint('❌ 登入失敗: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('💥 登入異常: $e');
      debugPrint('🔍 異常類型: ${e.runtimeType}');
      
      // 特別處理超時異常
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('Future not completed') ||
          e.toString().contains('登入請求超時') ||
          e.toString().contains('timeout')) {
        
        if (retryCount == 0) {
          debugPrint('⏰ 檢測到超時，嘗試自動重新掃描 API 地址...');
          final newHost = await autoDetectApiHost();
          if (newHost != null) {
            debugPrint('🎯 找到新的 API 地址，重試登入...');
            return await login(account: account, password: password, retryCount: retryCount + 1);
          }
        }
        throw Exception('連接超時 (${retryCount > 0 ? '重試後仍' : ''}10秒無回應)：\n\n可能原因：\n• 網路連接不穩定\n• 後端服務響應緩慢\n• 防火牆阻擋連接\n• IP 地址配置錯誤\n\n建議解決方案：\n• 檢查網路連接\n• 確認後端正在運行\n• 檢查防火牆設定\n• 嘗試重新啟動應用');
      }
      
      // 如果是其他連接問題且尚未重試，嘗試自動重新檢測 API 地址
      if (retryCount == 0 && (e.toString().contains('connection') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup'))) {
        
        debugPrint('🔄 檢測到連接問題，嘗試自動重新掃描 API 地址...');
        
        final newHost = await autoDetectApiHost();
        if (newHost != null) {
          debugPrint('🎯 找到新的 API 地址，重試登入...');
          return await login(account: account, password: password, retryCount: retryCount + 1);
        }
        
        throw Exception('連接失敗：\n• 無法連接到伺服器\n• 請檢查網路設定\n• 確認後端服務狀態\n• 檢查防火牆設定\n\n錯誤詳情：${e.toString()}');
      }
      
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

  // ==================== 推薦系統相關 ====================

  Future<Map<String, dynamic>> getRecommendations({int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations?limit=$limit'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'recommendations': List<Map<String, dynamic>>.from(data['recommendations']),
          'recommendation_type': data['recommendation_type'],
          'user_preferences': data['user_preferences'],
          'message': data['message'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? '獲取推薦失敗',
          'recommendations': [],
        };
      }
    } catch (e) {
      print('❌ 獲取推薦錯誤: $e');
      return {
        'success': false,
        'message': '發生錯誤: $e',
        'recommendations': [],
      };
    }
  }
}

