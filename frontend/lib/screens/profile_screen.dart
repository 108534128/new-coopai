import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _fullNameController.text = authProvider.user!.name ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 淺灰色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFE8F4F8), // 淺藍色標題欄
        foregroundColor: const Color(0xFF2C3E50), // 深灰藍色文字
        title: const Text(
          '個人資料',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
                _loadUserData();
              },
              child: const Text(
                '編輯',
                style: TextStyle(color: Color(0xFF2C3E50)),
              ),
            )
          else
            TextButton(
              onPressed: _cancelEdit,
              child: const Text(
                '取消',
                style: TextStyle(color: Color(0xFF2C3E50)),
              ),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF64B5F6),
              ),
            );
          }

          if (authProvider.user == null) {
            return const Center(
              child: Text('無法載入用戶資料'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 用戶頭像
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFB0BEC5).withOpacity(0.3), // 比上一步按鈕更淺的底色
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFFB0BEC5), // 與上一步按鈕相同的顏色
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 用戶名（不可編輯）
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFAFA),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '用戶名',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authProvider.user!.account,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 姓名
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFAFA),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '姓名',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              CustomTextField(
                                controller: _fullNameController,
                              )
                            else
                              Text(
                                authProvider.user!.name ?? '未設定',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF424242),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 帳號
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFAFA),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '帳號',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authProvider.user!.account,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 註冊時間
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFFAFAFA),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '註冊時間',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authProvider.user!.createdAt != null
                                  ? DateTime.parse(authProvider.user!.createdAt!)
                                      .toLocal()
                                      .toString()
                                      .split('.')[0]
                                  : '未知',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 儲存按鈕
                  if (_isEditing)
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return LoadingButton(
                          onPressed: authProvider.isLoading ? null : _handleSave,
                          isLoading: authProvider.isLoading,
                          child: const Text(
                            '儲存變更',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 16),

                  // 錯誤訊息
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.error != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            authProvider.error!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 24),

                  // 登出按鈕
                  OutlinedButton(
                    onPressed: () => _showLogoutDialog(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('登出'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    _loadUserData();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.updateProfile(
      name: _fullNameController.text.trim().isEmpty 
          ? null 
          : _fullNameController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('資料更新成功'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('您確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              '登出',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}