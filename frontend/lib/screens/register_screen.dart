import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // 標題
                  const Text(
                    "註 冊",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4A373), // 咖啡色
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 暱稱輸入框
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "暱稱(選填)",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF32201C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E6C9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _nameController,
                            hintText: "",
                            validator: null, // 暱稱為選填，不需要驗證
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 帳號輸入框
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "帳號",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF32201C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEDCD),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _accountController,
                            hintText: "",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入帳號';
                              }
                              if (value.length < 3) {
                                return '帳號至少需要3個字符';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 密碼輸入框
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "密碼",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF32201C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEDCD),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            hintText: "",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入密碼';
                              }
                              if (value.length < 6) {
                                return '密碼至少需要6個字符';
                              }
                              return null;
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 22,
                            color: const Color(0xFF6B5E53),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 確認密碼輸入框
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "確認密碼",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF32201C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEDCD),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            hintText: "",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請確認密碼';
                              }
                              if (value != _passwordController.text) {
                                return '密碼不一致';
                              }
                              return null;
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                          child: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            size: 22,
                            color: const Color(0xFF6B5E53),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 註冊按鈕
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return LoadingButton(
                        onPressed: authProvider.isLoading ? null : _handleRegister,
                        isLoading: authProvider.isLoading,
                        backgroundColor: const Color(0xFFAEC7A5),
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 48,
                        borderRadius: 100,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 0),
                          child: Text(
                            '註 冊',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 60),

                  // 錯誤訊息
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.error != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFAEDCD)),
                          ),
                          child: Text(
                            authProvider.error!,
                            style: const TextStyle(color: Color(0xFFFAEDCD)),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 10),

                  // 登入連結
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "已有帳號？",
                        style: TextStyle(color: Color(0xFF32201C)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          '登 入',
                          style: TextStyle(
                            color: Color(0xFFB07A45), // 咖啡色
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.register(
      account: _accountController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim().isEmpty 
          ? null 
          : _nameController.text.trim(),
    );

    if (success && mounted) {
      // 顯示註冊成功彈窗
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  '註冊成功',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF32201C),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '帳號回傳成功\n請等待跳入',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // 2秒後跳轉到登入頁面
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // 關閉彈窗
        context.go('/login'); // 跳轉到登入頁面
      }
    });
  }
}