import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = '用户名和密码不能为空');
      return;
    }

    if (_isRegister) {
      final confirm = _confirmPasswordCtrl.text.trim();
      if (confirm != password) {
        setState(() => _errorMsg = '两次输入的密码不一致');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      if (_isRegister) {
        await _authService.register(username, password);
        widget.onLoginSuccess();
      } else {
        final user = await _authService.login(username, password);
        if (user != null) {
          widget.onLoginSuccess();
        } else {
          setState(() => _errorMsg = '用户名或密码错误');
        }
      }
    } catch (e) {
      setState(() => _errorMsg = '操作失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _errorMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.photo_library_rounded, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                'PhotoSync',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                _isRegister ? '注册新账号' : '欢迎回来',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
              ),
              if (_isRegister) ...[
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: _confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline)),
                ),
              ],
              if (_errorMsg != null) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? '注册' : '登录'),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextButton(
                onPressed: _toggleMode,
                child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
