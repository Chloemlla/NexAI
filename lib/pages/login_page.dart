/// NexAI Login / Register Page
/// Material Design 3 styled authentication page
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/nexai_auth_service.dart';
import '../utils/google_font_paint.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login fields
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordVisible = false;

  // Register fields
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // Logo & Title
                  Image.asset(
                    'assets/icon.png',
                    width: 64,
                    height: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NexAI',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '登录以同步您的数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (auth.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colorScheme.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: auth.clearError,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(3),
                      labelColor: colorScheme.onPrimaryContainer,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      dividerHeight: 0,
                      tabs: const [
                        Tab(text: '登录'),
                        Tab(text: '注册'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab content
                  SizedBox(
                    height: 360,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(auth, colorScheme),
                        _buildRegisterForm(auth, colorScheme),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '或',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // OAuth buttons — Google Sign-In 始终可用（Android SDK）
                  _buildOAuthButton(
                    label: '使用 Google 登录',
                    iconWidget: CustomPaint(
                      painter: GoogleLogoPainter(),
                      size: const Size.square(24),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () => _handleGoogleSignIn(auth),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider auth, ColorScheme colorScheme) {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _loginIdentifierController,
            decoration: const InputDecoration(
              labelText: '用户名或邮箱',
              prefixIcon: Icon(Icons.person_outline),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? '请输入用户名或邮箱' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                  () => _loginPasswordVisible = !_loginPasswordVisible,
                ),
              ),
            ),
            obscureText: !_loginPasswordVisible,
            textInputAction: TextInputAction.done,
            validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
            onFieldSubmitted: (_) => _handleLogin(auth),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _handlePasskeyLogin(auth),
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text('Passkey 登录'),
              ),
              TextButton(
                onPressed: () => _showForgotPasswordDialog(),
                child: const Text('忘记密码？'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: auth.isLoading ? null : () => _handleLogin(auth),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登 录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthProvider auth, ColorScheme colorScheme) {
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextFormField(
              controller: _registerUsernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person_outline),
                hintText: '3-30位，字母数字下划线',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入用户名';
                if (v.length < 3) return '用户名至少3个字符';
                if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(v)) {
                  return '只能包含字母、数字、下划线';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerEmailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入邮箱';
                if (!v.contains('@')) return '邮箱格式不正确';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerPasswordController,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: '至少6位',
                suffixIcon: IconButton(
                  icon: Icon(
                    _registerPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _registerPasswordVisible = !_registerPasswordVisible,
                  ),
                ),
              ),
              obscureText: !_registerPasswordVisible,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入密码';
                if (v.length < 6) return '密码至少6个字符';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerConfirmPasswordController,
              decoration: const InputDecoration(
                labelText: '确认密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v != _registerPasswordController.text) return '两次密码不一致';
                return null;
              },
              onFieldSubmitted: (_) => _handleRegister(auth),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: auth.isLoading ? null : () => _handleRegister(auth),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('注 册'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthButton({
    required String label,
    Widget? iconWidget,
    IconData? icon,
    Color? iconColor,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
  }) {
    final displayIcon = iconWidget ?? Icon(icon!, color: iconColor, size: 28);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: displayIcon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  // ========== Handlers ==========

  Future<void> _handleLogin(AuthProvider auth) async {
    if (!_loginFormKey.currentState!.validate()) return;

    final success = await auth.login(
      identifier: _loginIdentifierController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleRegister(AuthProvider auth) async {
    if (!_registerFormKey.currentState!.validate()) return;

    final success = await auth.register(
      username: _registerUsernameController.text.trim(),
      email: _registerEmailController.text.trim(),
      password: _registerPasswordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleGoogleSignIn(AuthProvider auth) async {
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handlePasskeyLogin(AuthProvider auth) async {
    final identifier = _loginIdentifierController.text.trim();
    if (identifier.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先输入用户名或邮箱')));
      }
      return;
    }

    final success = await auth.loginWithPasskey(identifier: identifier);
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('忘记密码'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: '注册邮箱',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              await NexaiAuthApi.forgotPassword(
                email: emailController.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('如果邮箱已注册，您将收到密码重置指引')),
                );
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }
}
