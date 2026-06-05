import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacing2XL),
                // Brand mark
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.largeRadius),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    size: 44,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                Text(
                  'PhotoSync',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  _isRegister ? '创建新账号' : '欢迎回来',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2XL),
                // Form
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_isRegister) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '确认密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
                if (_errorMsg != null) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMD,
                      vertical: AppTheme.spacingSM,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXL),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isRegister ? '注册账号' : '登录'),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Center(
                  child: TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isRegister
                          ? '已有账号？去登录'
                          : '没有账号？去注册',
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2XL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
