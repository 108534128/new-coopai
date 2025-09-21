import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  // 設置載入狀態
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 設置錯誤訊息
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // 清除錯誤訊息
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 登入
  Future<bool> login(String account, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.login(
        account: account,
        password: password,
      );

      if (response['status'] == 'success') {
        _user = User.fromJson(response['user']);
        _setLoading(false);
        return true;
      } else {
        _setError(response['message'] ?? '登入失敗');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 註冊
  Future<bool> register({
    required String account,
    required String password,
    String? name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _apiService.register(
        account: account,
        password: password,
        name: name,
      );

      if (response['status'] == 'success') {
        _user = User.fromJson(response['user']);
        _setLoading(false);
        return true;
      } else {
        _setError(response['message'] ?? '註冊失敗');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 登出
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await _apiService.logout();
    } catch (e) {
      // 即使登出失敗也要清除本地狀態
    } finally {
      _user = null;
      _setError(null);
      _setLoading(false);
    }
  }

  // 獲取用戶資料
  Future<void> fetchUserProfile() async {
    if (!isLoggedIn) return;

    _setLoading(true);
    _setError(null);

    try {
      final user = await _apiService.getProfile();
      _user = user;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // 更新用戶資料
  Future<bool> updateProfile({
    String? name,
    String? account,
  }) async {
    if (!isLoggedIn) return false;

    _setLoading(true);
    _setError(null);

    try {
      final user = await _apiService.updateProfile(
        name: name,
        account: account,
      );
      
      _user = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 檢查登入狀態
  Future<void> checkLoginStatus() async {
    _setLoading(true);
    
    try {
      final isLoggedIn = await _apiService.isLoggedIn();
      if (isLoggedIn) {
        await fetchUserProfile();
      } else {
        _setLoading(false);
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
}