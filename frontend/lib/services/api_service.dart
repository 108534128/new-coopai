import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';
  
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
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
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
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
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
    String? fullName,
    String? email,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
        body: json.encode({
          if (fullName != null) 'full_name': fullName,
          if (email != null) 'email': email,
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