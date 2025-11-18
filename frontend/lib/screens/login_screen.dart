import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 頁面白底
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

                  //標題
                  const Text(
                    "登 入",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4A373), // 咖啡色
                    ),
                  ),

                  const SizedBox(height:100),

                  // 帳號
                  Align(
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

                  // ★ 奶油色輸入框背景
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
                            controller: _accountController,
                            hintText: "",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入帳號';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 密碼
                  Align(
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
                            color: const Color(0xFF6B5E53), // ← 看得見的深灰咖色
                          ),
                        ),
                      ],
                    ),
                  ),
              
                const SizedBox(height: 60),

                // 登入按鈕
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return LoadingButton(
                      onPressed: authProvider.isLoading ? null : _handleLogin,
                      isLoading: authProvider.isLoading,
                      backgroundColor: const Color(0xFFAEC7A5),
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: 48,
                      borderRadius: 100,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 0),
                        child: Text(
                          '登 入',
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

                  // 錯誤訊息（保留原功能）
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
                            style: TextStyle(color: const Color.fromARGB(255, 88, 36, 36)),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 10),

                  // ★ 註冊連結（改成與 UI 相符）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "還沒有帳號？",
                        style: TextStyle(color: Color(0xFF32201C)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text(
                          '註 冊',
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      _accountController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }
}
