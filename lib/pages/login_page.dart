/// NexAI Login / Register Page
/// Material Design 3 styled authentication page
library;

import 'package:flutter/material.dart';
import '../utils/nexai_api_error.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/nexai_auth_service.dart';
import '../utils/google_font_paint.dart';
import '../utils/app_security.dart';
import '../widgets/passkey_debug_dialog.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

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
    // Prevent screenshots / screen recording on the login page
    AppSecurity.instance.setSecureScreen(enable: true);
  }

  @override
  void dispose() {
    // Restore normal screen capture when leaving login
    AppSecurity.instance.setSecureScreen(enable: false);
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
    final googleSection = _buildGoogleSection(auth, colorScheme);

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(colorScheme),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: LumenTokens.horizontalPaddingForWidth(
                MediaQuery.sizeOf(context).width,
              ),
              vertical: LumenTokens.pagePaddingTop,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Logo & Title
                  Image.asset(
                    'assets/app_icon_runtime.png',
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NexAI',
                    style: TextStyle(
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
                        borderRadius: LumenTokens.cardBorderRadius,
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
                              auth.error!.contains('google ID token not found')
                                  ? '无法获取 Google ID Token，请检查配置或网络'
                                  : auth.error!,
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
                      borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(3),
                      labelColor: colorScheme.onPrimaryContainer,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
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

                  // Tab content — avoid fixed height which clips on small screens.
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return _tabController.index == 0
                          ? _buildLoginForm(auth, colorScheme)
                          : _buildRegisterForm(auth, colorScheme);
                    },
                  ),

                  const SizedBox(height: 16),

                  if (googleSection != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: colorScheme.outlineVariant),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Google 快速登录',
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
                    googleSection,
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildGoogleSection(AuthProvider auth, ColorScheme colorScheme) {
    if (!auth.googleSignInSupportedPlatform) {
      return _buildInfoCard(
        colorScheme: colorScheme,
        icon: Icons.devices_rounded,
        message: 'Google 快速登录仅支持 Android、iOS 和 Web。',
      );
    }

    if (!auth.oauthConfigLoaded) {
      return _buildInfoCard(
        colorScheme: colorScheme,
        icon: Icons.sync_rounded,
        message: '正在检查 Google 快速登录可用性...',
      );
    }

    if (!auth.googleEnabled) {
      return _buildInfoCard(
        colorScheme: colorScheme,
        icon: Icons.info_outline_rounded,
        message: '当前服务器未启用 Google 快速登录。',
      );
    }

    return _buildOAuthButton(
      label: '使用 Google 快速登录',
      iconWidget: CustomPaint(
        painter: GoogleLogoPainter(),
        size: const Size.square(24),
      ),
      onPressed: auth.isLoading ? null : () => _handleGoogleSignIn(auth),
      colorScheme: colorScheme,
    );
  }

  Widget _buildInfoCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: LumenTokens.cardBorderRadius,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
            children: [
              TextButton.icon(
                onPressed: () => _handlePasskeyLogin(auth),
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text('Passkey 登录'),
              ),
              TextButton.icon(
                onPressed: () => _handleDiscoverablePasskeyLogin(auth),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('免输账号'),
              ),
              const Spacer(),
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
    final displayIcon =
        iconWidget ??
        Icon(
          icon ?? Icons.login_rounded,
          color: iconColor,
          size: 28,
        );
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: displayIcon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  // ========== Handlers ==========

  Future<void> _handleLogin(AuthProvider auth) async {
    final loginState = _loginFormKey.currentState;
    if (loginState == null || !loginState.validate()) return;

    final success = await auth.login(
      identifier: _loginIdentifierController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleRegister(AuthProvider auth) async {
    final registerState = _registerFormKey.currentState;
    if (registerState == null || !registerState.validate()) return;

    final success = await auth.register(
      username: _registerUsernameController.text.trim(),
      email: _registerEmailController.text.trim(),
      password: _registerPasswordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _showAuthError(String? message, {String title = '请求失败'}) async {
    if (!mounted) return;
    final text = (message ?? '未知错误').trim();
    await showNexaiErrorDialog(
      context,
      NexaiApiError(
        stage: text.contains('签名')
            ? 'request_sign'
            : (text.contains('【环节】') ? 'http_status' : 'server_auth'),
        code: 'AUTH_FLOW',
        message: text.isEmpty ? '未知错误' : text,
      ),
      title: title,
    );
  }

  Future<void> _handleGoogleSignIn(AuthProvider auth) async {
    final success = await auth.signInWithGoogle();
    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        // Show detailed debug dialog on failure
        if (auth.lastGoogleDebugContext != null) {
          showDialog(
            context: context,
            builder: (context) => AuthDebugDialog(
              debugContext: auth.lastGoogleDebugContext!,
              title: 'Google 快速登录调试信息',
            ),
          );
        } else {
          await _showAuthError(auth.error, title: 'Google 登录失败');
        }
      }
    }
  }

  Future<void> _handlePasskeyLogin(AuthProvider auth) async {
    final identifier = _loginIdentifierController.text.trim();
    if (identifier.isEmpty) {
      // Empty identifier falls through to discoverable (usernameless) login.
      await _handleDiscoverablePasskeyLogin(auth);
      return;
    }

    final success = await auth.loginWithPasskey(identifier: identifier);
    if (!mounted) return;
    await _showPasskeyLoginResult(auth, success);
  }

  Future<void> _handleDiscoverablePasskeyLogin(AuthProvider auth) async {
    final success = await auth.loginWithPasskey();
    if (!mounted) return;
    await _showPasskeyLoginResult(auth, success);
  }

  Future<void> _showPasskeyLoginResult(AuthProvider auth, bool success) async {
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    if (auth.wasLastPasskeyCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? '已取消 Passkey 登录')),
      );
      return;
    }

    if (auth.lastPasskeyDebugContext != null) {
      showDialog(
        context: context,
        builder: (context) =>
            PasskeyDebugDialog(debugContext: auth.lastPasskeyDebugContext!),
      );
      return;
    }

    await _showAuthError(auth.error, title: 'Passkey 登录失败');
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
              try {
                await NexaiAuthApi.forgotPassword(
                  email: emailController.text.trim(),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('如果邮箱已注册，您将收到密码重置指引')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('发送失败：$e')),
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
