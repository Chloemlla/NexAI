import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../theme/lumen_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/short_url_provider.dart';
import '../widgets/tool_page_style.dart';
import '../widgets/lumen/lumen.dart';

class ShortUrlPage extends StatefulWidget {
  const ShortUrlPage({super.key});

  @override
  State<ShortUrlPage> createState() => _ShortUrlPageState();
}

class _ShortUrlPageState extends State<ShortUrlPage> {
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
      SmartDialog.showToast('请输入有效的 http:// 或 https:// 链接');
      return;
    }

    setState(() => _isLoading = true);
    SmartDialog.showLoading(msg: '正在生成短链接...');

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
        final shortUrl = response.data['shorturl']?.toString();
        if (shortUrl == null || shortUrl.isEmpty) {
          SmartDialog.showToast('接口返回为空，请重试');
          return;
        }

        setState(() => _resultUrl = shortUrl);
        await context.read<ShortUrlProvider>().addRecord(
          ShortUrlRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            originalUrl: target,
            shortUrl: shortUrl,
            createdAt: DateTime.now(),
          ),
        );
        SmartDialog.showToast('短链接生成成功');
      } else {
        final message = response.data is Map<String, dynamic>
            ? response.data['msg']?.toString()
            : null;
        SmartDialog.showToast(message ?? '生成失败，请稍后重试');
      }
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? error.response?.data['msg']?.toString()
          : error.message;
      SmartDialog.showToast(message ?? '网络连接异常，请检查网络');
    } catch (error) {
      SmartDialog.showToast('程序发生未知错误：$error');
    } finally {
      SmartDialog.dismiss();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      SmartDialog.showToast('剪贴板为空');
      return;
    }
    setState(() => _targetController.text = text);
  }

  void _clearAll() {
    setState(() {
      _targetController.clear();
      _resultUrl = null;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('链接已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumenTokens.radiusSm)),
      ),
    );
  }

  Future<void> _launchResult() async {
    if (_resultUrl == null) return;

    try {
      final uri = Uri.parse(_resultUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SmartDialog.showToast('无法唤起浏览器打开链接');
      }
    } catch (_) {
      SmartDialog.showToast('链接格式不正确');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;
    final hPad = isNarrow ? 16.0 : mq.size.width * 0.06;

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      body: CustomScrollView(
        slivers: [
          ToolPageHeroSliver(
            title: '短链接生成',
            subtitle: '把输入、生成结果和后续操作收敛到一条流程里，避免用户生成后还要重新找复制或访问入口。',
            icon: Icons.link_rounded,
            chips: [
              const ToolHeroChipData(
                icon: Icons.flash_on_rounded,
                label: '快速生成',
              ),
              ToolHeroChipData(
                icon: _resultUrl == null
                    ? Icons.hourglass_empty_rounded
                    : Icons.check_circle_rounded,
                label: _resultUrl == null ? '等待生成' : '结果已就绪',
              ),
              const ToolHeroChipData(
                icon: Icons.history_toggle_off_rounded,
                label: '自动记录',
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
            sliver: SliverToBoxAdapter(
              child: ToolQuickActionsBar(
                actions: [
                  ToolQuickActionData(
                    icon: Icons.content_paste_rounded,
                    label: '粘贴链接',
                    backgroundColor: cs.primaryContainer,
                    iconColor: cs.onPrimaryContainer,
                    onTap: _pasteUrl,
                  ),
                  ToolQuickActionData(
                    icon: Icons.cleaning_services_rounded,
                    label: '清空输入',
                    backgroundColor: cs.secondaryContainer,
                    iconColor: cs.onSecondaryContainer,
                    onTap: _clearAll,
                  ),
                  ToolQuickActionData(
                    icon: Icons.open_in_browser_rounded,
                    label: '访问结果',
                    backgroundColor: cs.tertiaryContainer,
                    iconColor: cs.onTertiaryContainer,
                    onTap: _resultUrl == null ? null : _launchResult,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const ToolSectionTitle(
                  icon: Icons.dashboard_customize_rounded,
                  title: '链接配置',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _targetController,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: '目标链接',
                          hintText: 'https://example.com/very/long/path',
                          prefixIcon: const Icon(Icons.public_rounded),
                          suffixIcon: _targetController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: _clearAll,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _createShortUrl,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(_isLoading ? '生成中...' : '生成短链接'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const ToolSectionTitle(
                  icon: Icons.check_circle_outline_rounded,
                  title: '生成结果',
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _resultUrl == null
                      ? const ToolEmptyStateCard(
                          key: ValueKey('empty'),
                          icon: Icons.link_off_rounded,
                          title: '还没有短链接',
                          description: '输入目标地址并点击生成后，结果会直接显示在这里。',
                        )
                      : ToolPanel(
                          key: const ValueKey('result'),
                          color: cs.secondaryContainer.withAlpha(70),
                          borderSide: BorderSide(
                            color: cs.secondary.withAlpha(40),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                                  border: Border.all(
                                    color: cs.outlineVariant.withAlpha(50),
                                  ),
                                ),
                                child: SelectableText(
                                  _resultUrl!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'JetBrainsMonoNexAI',
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _copyToClipboard(_resultUrl!),
                                      icon: const Icon(Icons.copy_rounded),
                                      label: const Text('复制链接'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _launchResult,
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                      ),
                                      label: const Text('立即访问'),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const ToolSectionTitle(
                  icon: Icons.tips_and_updates_rounded,
                  title: 'UX 调整说明',
                ),
                const SizedBox(height: 12),
                ToolPanel(
                  color: cs.tertiaryContainer.withAlpha(80),
                  borderSide: BorderSide(color: cs.tertiary.withAlpha(40)),
                  child: Text(
                    '原页面虽然有单独的 hero，但输入卡与结果卡的关系不够紧。现在把粘贴、生成、复制、访问拆成固定动作入口，'
                    '并把结果展示成可直接复制的主输出区，减少生成后再找按钮的成本。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
