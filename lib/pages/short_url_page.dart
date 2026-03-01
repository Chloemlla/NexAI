import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ShortUrlPage extends StatefulWidget {
  const ShortUrlPage({super.key});

  @override
  State<ShortUrlPage> createState() => _ShortUrlPageState();
}

class _ShortUrlPageState extends State<ShortUrlPage>
    with SingleTickerProviderStateMixin {
  final _targetController = TextEditingController();
  String? _resultUrl;
  bool _isLoading = false;

  final String _apiUrl = 'https://api.mmp.cc/api/dwz';

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _createShortUrl() async {
    final target = _targetController.text.trim();

    if (target.isEmpty) {
      SmartDialog.showToast('请输入目标地址');
      return;
    }

    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      SmartDialog.showToast('请输入有效的包含 http:// 或 https:// 的网址');
      return;
    }

    setState(() => _isLoading = true);
    SmartDialog.showLoading(msg: '正在生成专属链接...');

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final response = await dio.get(
        _apiUrl,
        queryParameters: {'longurl': target},
      );

      if (!mounted) return;

      if (response.data is Map<String, dynamic> &&
          response.data['status'] == 200) {
        setState(() {
          _resultUrl = response.data['shorturl'];
        });
        SmartDialog.showToast('🎉 短链接生成成功！');
      } else {
        final msg = response.data is Map<String, dynamic>
            ? response.data['msg']
            : '生成失败，请重试';
        SmartDialog.showToast(msg?.toString() ?? '生成失败，请重试');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errorMsg = '网络连接异常，请检查网络';
      if (e.response?.data is Map<String, dynamic>) {
        errorMsg = e.response?.data['msg']?.toString() ?? e.message ?? errorMsg;
      } else {
        errorMsg = e.message ?? errorMsg;
      }
      SmartDialog.showToast(errorMsg);
    } catch (e) {
      if (!mounted) return;
      SmartDialog.showToast('程序发生未知错误: $e');
    } finally {
      SmartDialog.dismiss();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SmartDialog.showToast('✅ 链接已复制到剪贴板');
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SmartDialog.showToast('无法唤起浏览器打开链接');
      }
    } catch (e) {
      SmartDialog.showToast('链接格式不正确');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '短链接生成',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Banner ──
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                mq.padding.top + kToolbarHeight + 20,
                24,
                40,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer,
                    cs.secondaryContainer.withAlpha(150),
                    cs.surface,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 36,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '极简 · 高效',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将冗长的网址转化为精简的短链接',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content ──
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 20 : 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  // Translate the form up slightly to overlap the banner
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: _buildInputCard(cs),
                  ),

                  // Animated Result Card
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                    child: _resultUrl != null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: _buildResultCard(cs),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withAlpha(50), width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard_customize_rounded,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 10),
              Text(
                '参数配置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _targetController,
            label: '目标链接',
            hint: 'https://...',
            icon: Icons.public_rounded,
            cs: cs,
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _createShortUrl,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '一键生成',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.secondary.withAlpha(50), width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '生成结果',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SelectableText(
              _resultUrl ?? '',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: cs.primary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _copyToClipboard(_resultUrl!),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    '复制链接',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _launchUrl(_resultUrl!),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text(
                    '立即访问',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ColorScheme cs,
    bool isPassword = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 15,
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(150)),
        prefixIcon: Icon(icon, color: cs.primary.withAlpha(200)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withAlpha(100),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }
}
