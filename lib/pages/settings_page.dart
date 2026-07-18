import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/nexai_api_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/password_provider.dart';
import '../providers/translation_provider.dart';
import '../providers/short_url_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/update_checker.dart';
import '../utils/build_config.dart';
import '../utils/google_font_paint.dart';
import '../services/pinned_http_client.dart';
import '../widgets/passkey_debug_dialog.dart';
import '../widgets/sync_recovery_key_dialogs.dart';
import '../widgets/user_avatar.dart';
import 'about_page.dart';
import 'developer_debug_page.dart';
import 'login_page.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsProvider _settingsProvider;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelsController;
  late TextEditingController _systemPromptController;
  late TextEditingController _webdavServerController;
  late TextEditingController _webdavUserController;
  late TextEditingController _webdavPasswordController;
  late TextEditingController _upstashUrlController;
  late TextEditingController _upstashTokenController;
  late TextEditingController _vertexApiKeyController;

  // New API Mode Controllers
  late String _currentApiMode;
  late TextEditingController _vertexProjectIdController;
  late TextEditingController _vertexLocationController;

  bool _showApiKey = false;
  bool _isDirty = false;
  bool _isSyncingControllers = false;
  String _version = '';

  String _formatSyncTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final settings = _settingsProvider = context.read<SettingsProvider>();
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelsController = TextEditingController(text: settings.models.join(', '));
    _systemPromptController = TextEditingController(
      text: settings.systemPrompt,
    );
    _webdavServerController = TextEditingController(
      text: settings.webdavServer,
    );
    _webdavUserController = TextEditingController(text: settings.webdavUser);
    _webdavPasswordController = TextEditingController(
      text: settings.webdavPassword,
    );
    _upstashUrlController = TextEditingController(text: settings.upstashUrl);
    _upstashTokenController = TextEditingController(
      text: settings.upstashToken,
    );
    _vertexApiKeyController = TextEditingController(
      text: settings.vertexApiKey,
    );

    _currentApiMode = settings.apiMode;
    _vertexProjectIdController = TextEditingController(
      text: settings.vertexProjectId,
    );
    _vertexLocationController = TextEditingController(
      text: settings.vertexLocation,
    );

    for (final c in [
      _baseUrlController,
      _apiKeyController,
      _modelsController,
      _systemPromptController,
      _vertexProjectIdController,
      _vertexLocationController,
    ]) {
      c.addListener(_markDirty);
    }
    _settingsProvider.addListener(_handleSettingsChanged);
    _loadVersion();
  }

  void _markDirty() {
    if (_isSyncingControllers || _isDirty || !mounted) return;
    setState(() => _isDirty = true);
  }

  void _handleSettingsChanged() {
    if (!mounted || !_settingsProvider.loaded || _isDirty) return;
    _syncControllersFromSettings(_settingsProvider);
  }

  void _syncControllersFromSettings(
    SettingsProvider settings, {
    bool resetDirty = false,
  }) {
    _isSyncingControllers = true;
    try {
      _baseUrlController.text = settings.baseUrl;
      _apiKeyController.text = settings.apiKey;
      _modelsController.text = settings.models.join(', ');
      _systemPromptController.text = settings.systemPrompt;
      _webdavServerController.text = settings.webdavServer;
      _webdavUserController.text = settings.webdavUser;
      _webdavPasswordController.text = settings.webdavPassword;
      _upstashUrlController.text = settings.upstashUrl;
      _upstashTokenController.text = settings.upstashToken;
      _vertexApiKeyController.text = settings.vertexApiKey;
      _vertexProjectIdController.text = settings.vertexProjectId;
      _vertexLocationController.text = settings.vertexLocation;
    } finally {
      _isSyncingControllers = false;
    }

    if (!mounted) return;
    setState(() {
      _currentApiMode = settings.apiMode;
      if (resetDirty) {
        _isDirty = false;
      }
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_handleSettingsChanged);
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelsController.dispose();
    _systemPromptController.dispose();
    _webdavServerController.dispose();
    _webdavUserController.dispose();
    _webdavPasswordController.dispose();
    _upstashUrlController.dispose();
    _upstashTokenController.dispose();
    _vertexApiKeyController.dispose();
    _vertexProjectIdController.dispose();
    _vertexLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildM3Settings(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3Settings(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!settings.loaded) {
      return Scaffold(
        backgroundColor: lumenScaffoldBackground(cs),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载设置...',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> saveAll() async {
      try {
        await settings.setApiMode(_currentApiMode);
        await settings.setBaseUrl(_baseUrlController.text);
        await settings.setApiKey(_apiKeyController.text);
        await settings.setModels(_modelsController.text);
        await settings.setSystemPrompt(_systemPromptController.text);
        await settings.setVertexProjectId(_vertexProjectIdController.text);
        await settings.setVertexLocation(_vertexLocationController.text);
        _syncControllersFromSettings(settings, resetDirty: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text('设置已保存'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      // FAB-style save button that appears when dirty
      floatingActionButton: IgnorePointer(
        ignoring: !_isDirty,
        child: AnimatedOpacity(
          opacity: _isDirty ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: AnimatedScale(
            scale: _isDirty ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.selectionClick();
                await saveAll();
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('保存'),
              elevation: 0,
              highlightElevation: 0,
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              LumenTokens.pagePaddingStart,
              LumenTokens.pagePaddingTop + 8,
              LumenTokens.pagePaddingEnd,
              100,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account ──
                _SectionHeader(
                  icon: Icons.account_circle_outlined,
                  label: '账号',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: LumenTokens.sectionGap),
                _buildAccountCard(context, cs, tt),
                const SizedBox(height: LumenTokens.sectionGap),
                _buildPasskeyCard(context, cs, tt),
                const SizedBox(height: 20),

                // ── API Configuration ──
                _SectionHeader(
                  icon: Icons.cloud_outlined,
                  label: 'API 配置',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: LumenTokens.sectionGap),
                _SettingsCard(
                  cs: cs,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _currentApiMode,
                      decoration: const InputDecoration(
                        labelText: 'API 模式',
                        prefixIcon: Icon(Icons.hub_outlined, size: 20),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      items: const [
                        DropdownMenuItem(
                          value: 'OpenAI',
                          child: Text('OpenAI 兼容'),
                        ),
                        DropdownMenuItem(
                          value: 'Vertex',
                          child: Text('Google Vertex AI'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _currentApiMode = v;
                            _isDirty = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_currentApiMode == 'OpenAI') ...[
                      TextField(
                        controller: _baseUrlController,
                        decoration: InputDecoration(
                          labelText: '基础 URL',
                          hintText: SettingsProvider.defaultOpenaiBaseUrl,
                          prefixIcon: const Icon(Icons.link_rounded, size: 20),
                          helperText: 'OpenAI 兼容端点',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      TextField(
                        controller: _vertexProjectIdController,
                        decoration: const InputDecoration(
                          labelText: 'Project ID',
                          hintText: 'your-google-cloud-project-id',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          helperText: '标准模式必填。若留空则使用 Express 模式',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _vertexLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'us-central1',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          helperText: '标准模式必填。若使用 Express 模式，请输入 global',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _apiKeyController,
                      obscureText: !_showApiKey,
                      decoration: InputDecoration(
                        labelText: _currentApiMode == 'OpenAI'
                            ? 'API 密钥'
                            : 'Access Token / API Key',
                        hintText: _currentApiMode == 'OpenAI'
                            ? 'sk-...'
                            : 'ya29...或AIza...',
                        prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        helperText: _currentApiMode == 'Vertex'
                            ? '标准模式(Project ID不为空): 输入 gcloud print-access-token\nExpress模式(Project ID为空): 输入 AI Studio/Google Cloud API Key'
                            : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showApiKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                          ),
                          tooltip: _showApiKey ? '隐藏密钥' : '显示密钥',
                          onPressed: () =>
                              setState(() => _showApiKey = !_showApiKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _modelsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '可用模型',
                        hintText: 'gpt-4o, gpt-4o-mini',
                        prefixIcon: Icon(
                          Icons.model_training_rounded,
                          size: 20,
                        ),
                        helperText: '逗号分隔列表',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          settings.models.isNotEmpty &&
                              settings.models.contains(settings.selectedModel)
                          ? settings.selectedModel
                          : (settings.models.isNotEmpty
                                ? settings.models.first
                                : null),
                      decoration: const InputDecoration(
                        labelText: '当前模型',
                        prefixIcon: Icon(Icons.smart_toy_outlined, size: 20),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      items: settings.models
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) settings.setSelectedModel(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Generation ──
                _SectionHeader(
                  icon: Icons.tune_rounded,
                  label: '生成设置',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    _SliderRow(
                      cs: cs,
                      tt: tt,
                      icon: Icons.thermostat_rounded,
                      label: '温度',
                      value: settings.temperature,
                      displayValue: settings.temperature.toStringAsFixed(2),
                      min: 0,
                      max: 2,
                      divisions: 40,
                      onChanged: (v) => settings.setTemperature(v),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        settings.temperature < 0.5
                            ? '更专注和确定'
                            : settings.temperature < 1.2
                            ? '平衡创造力'
                            : '更有创意和随机',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    _SliderRow(
                      cs: cs,
                      tt: tt,
                      icon: Icons.token_rounded,
                      label: '最大令牌数',
                      value: settings.maxTokens.toDouble(),
                      displayValue: settings.maxTokens >= 1000
                          ? '${(settings.maxTokens / 1000).toStringAsFixed(1)}k'
                          : '${settings.maxTokens}',
                      min: 256,
                      max: 32768,
                      divisions: 64,
                      onChanged: (v) => settings.setMaxTokens(v.toInt()),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '系统提示词',
                        hintText: '你是一个有帮助的助手...',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description_outlined, size: 20),
                        ),
                        helperText: '设置 AI 的行为和角色',
                      ),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.chatToolsEnabled,
                      onChanged: settings.apiMode == 'OpenAI'
                          ? (v) => settings.setChatToolsEnabled(v)
                          : null,
                      title: Text('启用对话工具', style: tt.bodyMedium),
                      subtitle: Text(
                        settings.apiMode == 'OpenAI'
                            ? '允许模型在 OpenAI 兼容模式下调用内置工具'
                            : 'Vertex 模式暂不支持 tool-calling',
                        style: tt.bodySmall,
                      ),
                    ),
                    if (settings.chatToolsEnabled && settings.apiMode == 'OpenAI') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolWebSearchEnabled,
                        onChanged: settings.setToolWebSearchEnabled,
                        title: Text('web_search', style: tt.bodyMedium),
                        subtitle: Text('联网搜索', style: tt.bodySmall),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolNotesEnabled,
                        onChanged: settings.setToolNotesEnabled,
                        title: Text('notes_search / notes_read', style: tt.bodyMedium),
                        subtitle: Text('检索与读取本地笔记', style: tt.bodySmall),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolImageEnabled,
                        onChanged: settings.setToolImageEnabled,
                        title: Text('generate_image', style: tt.bodyMedium),
                        subtitle: Text('对话内绘图（需审批）', style: tt.bodySmall),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolArtifactsEnabled,
                        onChanged: settings.setToolArtifactsEnabled,
                        title: Text('report_artifacts', style: tt.bodyMedium),
                        subtitle: Text('发布分享链接（需登录与审批）', style: tt.bodySmall),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolFetchUrlEnabled,
                        onChanged: settings.setToolFetchUrlEnabled,
                        title: Text('fetch_url', style: tt.bodyMedium),
                        subtitle: Text('抓取网页正文（需审批）', style: tt.bodySmall),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.toolCreateNoteEnabled,
                        onChanged: settings.setToolCreateNoteEnabled,
                        title: Text('create_note', style: tt.bodyMedium),
                        subtitle: Text('创建本地笔记（需审批）', style: tt.bodySmall),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('最大工具轮次', style: tt.bodyMedium),
                        subtitle: Text('${settings.maxToolRounds}', style: tt.bodySmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: settings.maxToolRounds > 1
                                  ? () => settings.setMaxToolRounds(settings.maxToolRounds - 1)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            IconButton(
                              onPressed: settings.maxToolRounds < 12
                                  ? () => settings.setMaxToolRounds(settings.maxToolRounds + 1)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // ── Appearance ──
                _SectionHeader(
                  icon: Icons.palette_outlined,
                  label: '外观',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    // Theme segmented button
                    Row(
                      children: [
                        Icon(
                          Icons.brightness_6_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '主题',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 18),
                          label: Text('浅色'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 18),
                          label: Text('自动'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 18),
                          label: Text('深色'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        settings.setThemeMode(s.first);
                      },
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Icon(
                          Icons.color_lens_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '强调色',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _m3ColorChip(cs, settings, null, '动态'),
                        _m3ColorChip(cs, settings, 0xFF6750A4, '紫色'),
                        _m3ColorChip(cs, settings, 0xFF0078D4, '蓝色'),
                        _m3ColorChip(cs, settings, 0xFFE74856, '红色'),
                        _m3ColorChip(cs, settings, 0xFFFF8C00, '橙色'),
                        _m3ColorChip(cs, settings, 0xFF10893E, '绿色'),
                        _m3ColorChip(cs, settings, 0xFF00B7C3, '青色'),
                        _m3ColorChip(cs, settings, 0xFFE3008C, '粉色'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        border: Border.all(color: cs.primary.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            settings.accentColorValue == null
                                ? Icons.auto_awesome_rounded
                                : Icons.color_lens_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              settings.accentColorValue == null
                                  ? '使用 Material You 壁纸颜色'
                                  : '已应用自定义强调色',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Chat Display ──
                _SectionHeader(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '聊天显示',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    _SliderRow(
                      cs: cs,
                      tt: tt,
                      icon: Icons.format_size_rounded,
                      label: '字体大小',
                      value: settings.fontSize,
                      displayValue: '${settings.fontSize.toInt()}px',
                      min: 10,
                      max: 24,
                      divisions: 14,
                      onChanged: (v) => settings.setFontSize(v),
                    ),
                    const Divider(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: settings.fontFamily,
                      decoration: const InputDecoration(
                        labelText: '字体系列',
                        prefixIcon: Icon(
                          Icons.font_download_outlined,
                          size: 20,
                        ),
                      ),
                      items: SettingsProvider.availableFonts
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) settings.setFontFamily(v);
                      },
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      value: settings.borderlessMode,
                      onChanged: (v) => settings.setBorderlessMode(v),
                      title: const Text('无边框模式'),
                      subtitle: const Text('隐藏对话气泡边框，更加简洁'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: settings.fullScreenMode,
                      onChanged: (v) => settings.setFullScreenMode(v),
                      title: const Text('全屏显示'),
                      subtitle: const Text('沉浸式聊天体验'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: settings.smartAutoScroll,
                      onChanged: (v) => settings.setSmartAutoScroll(v),
                      title: const Text('智能滚动'),
                      subtitle: const Text('输入时自动滚动到底部'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Cloud Sync ──
                _SectionHeader(
                  icon: Icons.cloud_sync_rounded,
                  label: '云同步',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    SwitchListTile(
                      value: settings.syncEnabled,
                      onChanged: (v) => settings.setSyncEnabled(v),
                      title: const Text('启用云同步'),
                      subtitle: const Text('同步聊天记录和笔记'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (settings.syncEnabled) ...[
                      const Divider(height: 24),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'WebDAV',
                            label: Text('WebDAV'),
                            icon: Icon(Icons.storage_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'UpStash',
                            label: Text('UpStash'),
                            icon: Icon(Icons.bolt_rounded, size: 16),
                          ),
                        ],
                        selected: {settings.syncMethod},
                        onSelectionChanged: (s) =>
                            settings.setSyncMethod(s.first),
                      ),
                      const SizedBox(height: 16),
                      if (settings.syncMethod == 'WebDAV') ...[
                        TextField(
                          controller: _webdavServerController,
                          decoration: const InputDecoration(
                            labelText: '服务器地址',
                            hintText: 'https://dav.example.com',
                          ),
                          onChanged: (v) => settings.setWebdavServer(v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _webdavUserController,
                          decoration: const InputDecoration(labelText: '用户名'),
                          onChanged: (v) => settings.setWebdavUser(v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _webdavPasswordController,
                          decoration: const InputDecoration(
                            labelText: '密码 / 令牌',
                          ),
                          obscureText: true,
                          onChanged: (v) => settings.setWebdavPassword(v),
                        ),
                      ] else ...[
                        TextField(
                          controller: _upstashUrlController,
                          decoration: const InputDecoration(
                            labelText: 'REST URL',
                          ),
                          onChanged: (v) => settings.setUpstashUrl(v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _upstashTokenController,
                          decoration: const InputDecoration(
                            labelText: 'REST Token',
                          ),
                          obscureText: true,
                          onChanged: (v) => settings.setUpstashToken(v),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // ── NexAI Cloud Sync ──
                _SectionHeader(
                  icon: Icons.cloud_upload_rounded,
                  label: 'NexAI 云同步',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    final auth = ctx.watch<AuthProvider>();
                    final sync = ctx.watch<SyncProvider>();
                    final isLoggedIn = auth.accessToken != null;

                    return _SettingsCard(
                      cs: cs,
                      children: [
                        if (!isLoggedIn)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.errorContainer.withAlpha(80),
                              borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 18,
                                  color: cs.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '请先登录 NexAI 账号以使用云同步功能',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          if (sync.lastSyncedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 16,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '上次同步: ${_formatSyncTime(sync.lastSyncedAt!)}',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (sync.status == SyncStatus.error &&
                              sync.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer.withAlpha(80),
                                  borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                                ),
                                child: Text(
                                  sync.errorMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.error,
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: sync.isSyncing
                                      ? null
                                      : () async {
                                          final chatProv = ctx
                                              .read<ChatProvider>();
                                          final notesProv = ctx
                                              .read<NotesProvider>();
                                          final passProv = ctx
                                              .read<PasswordProvider>();
                                          final transProv = ctx
                                              .read<TranslationProvider>();
                                          final urlProv = ctx
                                              .read<ShortUrlProvider>();
                                          final ok = await sync.uploadAll(
                                            authProvider: auth,
                                            settingsProvider: settings,
                                            chatProvider: chatProv,
                                            notesProvider: notesProv,
                                            passwordProvider: passProv,
                                            translationProvider: transProv,
                                            shortUrlProvider: urlProv,
                                          );
                                          if (ctx.mounted) {
                                            if (ok) {
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: const [
                                                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                                      SizedBox(width: 8),
                                                      Text('数据已上传到云端'),
                                                    ],
                                                  ),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                ),
                                              );
                                            } else {
                                              await showNexaiErrorDialog(
                                                ctx,
                                                NexaiApiError(
                                                  stage: 'http_status',
                                                  code: 'SYNC_UPLOAD_FAILED',
                                                  message: sync.errorMessage ?? '操作失败',
                                                ),
                                                title: '云端同步失败',
                                              );
                                            }
                                          }
                                        },
                                  icon: sync.status == SyncStatus.uploading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.onPrimary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cloud_upload_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    sync.status == SyncStatus.uploading
                                        ? '上传中...'
                                        : '上传到云端',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: sync.isSyncing
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                context: ctx,
                                                builder: (c) => AlertDialog(
                                                  title: const Text('从云端恢复'),
                                                  content: const Text(
                                                    '这将用云端数据覆盖本地数据，确定继续吗？',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            c,
                                                            false,
                                                          ),
                                                      child: const Text('取消'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            c,
                                                            true,
                                                          ),
                                                      child: const Text('确定'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirmed != true ||
                                              !ctx.mounted) {
                                            return;
                                          }
                                          final chatProv = ctx
                                              .read<ChatProvider>();
                                          final notesProv = ctx
                                              .read<NotesProvider>();
                                          final passProv = ctx
                                              .read<PasswordProvider>();
                                          final transProv = ctx
                                              .read<TranslationProvider>();
                                          final urlProv = ctx
                                              .read<ShortUrlProvider>();
                                          final ok = await sync.downloadAll(
                                            authProvider: auth,
                                            settingsProvider: settings,
                                            chatProvider: chatProv,
                                            notesProvider: notesProv,
                                            passwordProvider: passProv,
                                            translationProvider: transProv,
                                            shortUrlProvider: urlProv,
                                          );
                                          if (ctx.mounted) {
                                            if (ok) {
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: const [
                                                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                                      SizedBox(width: 8),
                                                      Text('数据已从云端恢复'),
                                                    ],
                                                  ),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                ),
                                              );
                                            } else {
                                              await showNexaiErrorDialog(
                                                ctx,
                                                NexaiApiError(
                                                  stage: 'http_status',
                                                  code: 'SYNC_DOWNLOAD_FAILED',
                                                  message: sync.errorMessage ?? '操作失败',
                                                ),
                                                title: '云端恢复失败',
                                              );
                                            }
                                          }
                                        },
                                  icon: sync.status == SyncStatus.downloading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cloud_download_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    sync.status == SyncStatus.downloading
                                        ? '恢复中...'
                                        : '从云端恢复',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: sync.isSyncing
                                  ? null
                                  : () async {
                                      final chatProv = ctx.read<ChatProvider>();
                                      final notesProv = ctx
                                          .read<NotesProvider>();
                                      final passProv = ctx
                                          .read<PasswordProvider>();
                                      final transProv = ctx
                                          .read<TranslationProvider>();
                                      final urlProv = ctx
                                          .read<ShortUrlProvider>();
                                      final ok = await sync.incrementalSync(
                                        authProvider: auth,
                                        settingsProvider: settings,
                                        chatProvider: chatProv,
                                        notesProvider: notesProv,
                                        passwordProvider: passProv,
                                        translationProvider: transProv,
                                        shortUrlProvider: urlProv,
                                      );
                                      if (ctx.mounted) {
                                      if (ok) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: const [
                                                Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('增量同步完成'),
                                              ],
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } else {
                                        await showNexaiErrorDialog(
                                          ctx,
                                          NexaiApiError(
                                            stage: 'http_status',
                                            code: 'SYNC_INCREMENTAL_FAILED',
                                            message: sync.errorMessage ?? '操作失败',
                                          ),
                                          title: '增量同步失败',
                                        );
                                      }
                                    }
                                    },
                              icon: sync.isSyncing
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 18),
                              label: Text(
                                sync.isSyncing ? '同步中...' : '增量同步（仅传输变更）',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: sync.isSyncing
                                      ? null
                                      : () => showSyncRecoveryKeyDialog(ctx),
                                  icon: const Icon(Icons.key_rounded, size: 18),
                                  label: const Text('导出恢复密钥'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: sync.isSyncing
                                      ? null
                                      : () => showImportSyncRecoveryKeyDialog(
                                          ctx,
                                        ),
                                  icon: const Icon(
                                    Icons.input_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('导入恢复密钥'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: sync.isSyncing
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: ctx,
                                      builder: (c) => AlertDialog(
                                        title: const Text('清除云端数据'),
                                        content: const Text(
                                          '这将永久删除云端所有同步数据，本操作不可撤销。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: cs.error,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !ctx.mounted) {
                                      return;
                                    }
                                    final ok = await sync.clearCloudData(
                                      authProvider: auth,
                                    );
                                    if (ctx.mounted) {
                                      if (ok) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: const [
                                                Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('云端数据已清除'),
                                              ],
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } else {
                                        await showNexaiErrorDialog(
                                          ctx,
                                          NexaiApiError(
                                            stage: 'http_status',
                                            code: 'SYNC_CLEAR_FAILED',
                                            message: sync.errorMessage ?? '操作失败',
                                          ),
                                          title: '清除云端失败',
                                        );
                                      }
                                    }
                                  },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: cs.error,
                            ),
                            label: Text(
                              '清除云端数据',
                              style: TextStyle(color: cs.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              side: BorderSide(color: cs.error.withAlpha(100)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Notes ──
                _SectionHeader(
                  icon: Icons.note_alt_rounded,
                  label: '笔记',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    SwitchListTile(
                      value: settings.notesAutoSave,
                      onChanged: (value) => settings.setNotesAutoSave(value),
                      title: Text('自动保存笔记', style: tt.bodyMedium),
                      subtitle: Text(
                        '离开编辑器时自动保存笔记',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: settings.aiTitleGeneration,
                      onChanged: (value) =>
                          settings.setAiTitleGeneration(value),
                      title: Text('AI 标题生成', style: tt.bodyMedium),
                      subtitle: Text(
                        '自动为无标题笔记生成标题',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withAlpha(100),
                        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        border: Border.all(
                          color: cs.outlineVariant.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              settings.notesAutoSave
                                  ? '离开编辑器时笔记将自动保存'
                                  : '需要使用保存按钮手动保存笔记',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Updates ──
                _SectionHeader(
                  icon: Icons.system_update_rounded,
                  label: '更新',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '版本',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withAlpha(120),
                            borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
                          ),
                          child: Text(
                            _version.isNotEmpty ? _version : '...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (BuildConfig.buildTime > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.tag_rounded, size: 18, color: cs.primary),
                          const SizedBox(width: 10),
                          Text(
                            '构建号',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withAlpha(120),
                              borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
                            ),
                            child: Text(
                              '${BuildConfig.versionCode}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cs.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    FutureBuilder<bool>(
                      future: UpdateChecker.getAutoUpdate(),
                      builder: (context, snapshot) {
                        final autoUpdate = snapshot.data ?? true;
                        return SwitchListTile(
                          value: autoUpdate,
                          onChanged: (value) async {
                            await UpdateChecker.setAutoUpdate(value);
                            setState(() {});
                          },
                          title: Text('自动检查更新', style: tt.bodyMedium),
                          subtitle: Text(
                            '应用启动时检查更新',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '更新判断会优先参考发布时间，避免最新 Release 版本号较低时无法提示升级。',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          UpdateChecker.checkUpdate(context, isAuto: false),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('检查更新'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Gemini AI Translation ──
                _SectionHeader(
                  icon: Icons.translate_rounded,
                  label: 'Gemini / Vertex（聊天用）',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    TextField(
                      controller: _vertexApiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key',
                        hintText: 'your-gemini-api-key',
                        prefixIcon: Icon(Icons.key_rounded, color: cs.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                        ),
                        helperText: '在 https://aistudio.google.com/apikey 获取',
                        helperMaxLines: 2,
                      ),
                      obscureText: true,
                      onChanged: (v) =>
                          context.read<SettingsProvider>().setVertexApiKey(v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Security ──
                _SectionHeader(
                  icon: Icons.security_rounded,
                  label: '安全',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.verified_user_rounded,
                        color: cs.primary,
                      ),
                      title: Text(
                        '证书固定',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '使用 TOFU 模式保护 API 连接安全',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('清除证书缓存'),
                            content: const Text(
                              '这将清除已存储的证书指纹，下次连接时将重新固定证书。\n\n'
                              '仅在以下情况使用：\n'
                              '• 服务器证书已更新\n'
                              '• 遇到证书验证错误\n'
                              '• 需要重新建立信任',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('清除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;

                        try {
                          await clearCertPin();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text('证书缓存已清除，请重启应用'),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                                ),
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('清除失败: $e')),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                                ),
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                      label: Text(
                        '清除证书缓存',
                        style: TextStyle(color: cs.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: BorderSide(color: cs.primary.withAlpha(100)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (settings.developerDebugModeUnlocked) ...[
                  // ── Developer ──
                  _SectionHeader(
                    icon: Icons.terminal_rounded,
                    label: '开发者',
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cs: cs,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.data_object_rounded,
                          color: cs.primary,
                        ),
                        title: Text(
                          '开发者高级调试模式',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '运行状态、日志流与调试快照',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: cs.outline,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DeveloperDebugPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── About ──
                _SectionHeader(
                  icon: Icons.info_outline_rounded,
                  label: '关于',
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  cs: cs,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.asset(
                        'assets/app_icon_runtime.png',
                        width: 40,
                        height: 40,
                      ),
                      title: Text(
                        '关于 NexAI',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '应用信息、功能和致谢',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: cs.outline,
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutPage()),
                        );
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, ColorScheme cs, TextTheme tt) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading && !auth.initialized) {
      return _SettingsCard(
        cs: cs,
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (auth.isLoggedIn && auth.currentUser != null) {
      final user = auth.currentUser!;
      return _SettingsCard(
        cs: cs,
        children: [
          Row(
            children: [
              UserAvatar(
                radius: 24,
                imageUrl: user.avatarUrl,
                displayName: user.displayName,
                username: user.username,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Provider badges
              if (user.hasGoogle)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: CustomPaint(
                    painter: GoogleLogoPainter(),
                    size: const Size.square(20),
                  ),
                ),
              if (user.hasGithub)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.code_rounded, size: 18, color: cs.primary),
                ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: Icon(Icons.logout_rounded, color: cs.error),
                        title: const Text('退出登录'),
                        content: const Text('确定要退出登录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                            ),
                            child: const Text('退出'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await auth.logout();
                    }
                  },
                  icon: Icon(Icons.logout_rounded, size: 18, color: cs.error),
                  label: Text('退出登录', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error.withAlpha(120)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Not logged in — show login prompt
    return _SettingsCard(
      cs: cs,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
              ),
              child: Icon(
                Icons.person_rounded,
                color: cs.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '登录 NexAI',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '同步数据，解锁更多功能',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
          },
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('登录 / 注册'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LumenTokens.radiusMd),
            ),
          ),
        ),
        if (_buildGoogleQuickLoginWidget(auth, cs)
            case final googleQuickLogin?) ...[
          const SizedBox(height: 10),
          googleQuickLogin,
        ],
        if (auth.error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.errorContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.error!,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildGoogleQuickLoginWidget(AuthProvider auth, ColorScheme cs) {
    if (!auth.googleSignInSupportedPlatform) {
      return _buildInfoBanner(
        cs: cs,
        icon: Icons.devices_rounded,
        message: 'Google 快速登录仅支持 Android、iOS 和 Web。',
      );
    }

    if (!auth.oauthConfigLoaded) {
      return _buildInfoBanner(
        cs: cs,
        icon: Icons.sync_rounded,
        message: '正在检查 Google 快速登录可用性...',
      );
    }

    if (!auth.googleEnabled) {
      return _buildInfoBanner(
        cs: cs,
        icon: Icons.info_outline_rounded,
        message: '当前服务器未启用 Google 快速登录。',
        details: _formatOAuthConfigDebugInfo(auth.lastOAuthConfigDebugContext),
      );
    }

    return OutlinedButton.icon(
      onPressed: auth.isLoading
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final success = await auth.signInWithGoogle();
              if (!context.mounted) return;
              if (success) {
                messenger.showSnackBar(const SnackBar(content: Text('登录成功')));
              } else if (auth.error != null) {
                messenger.showSnackBar(SnackBar(content: Text(auth.error!)));
              }
            },
      icon: CustomPaint(
        painter: GoogleLogoPainter(),
        size: const Size.square(22),
      ),
      label: const Text('使用 Google 快速登录'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumenTokens.radiusMd)),
        side: BorderSide(color: cs.outlineVariant),
      ),
    );
  }

  Widget _buildInfoBanner({
    required ColorScheme cs,
    required IconData icon,
    required String message,
    String? details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      details,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontFamily: SettingsProvider.monospaceFontFamily,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formatOAuthConfigDebugInfo(Map<String, dynamic>? debugContext) {
    if (debugContext == null || debugContext.isEmpty) return null;
    try {
      return '开发信息:\n${const JsonEncoder.withIndent('  ').convert(debugContext)}';
    } catch (_) {
      return '开发信息:\n$debugContext';
    }
  }

  Widget _buildPasskeyCard(BuildContext context, ColorScheme cs, TextTheme tt) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    if (!auth.isLoggedIn || auth.currentUser == null) {
      return const SizedBox.shrink();
    }

    return _SettingsCard(
      cs: cs,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withAlpha(200),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: cs.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '通行密钥 (Passkeys)',
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.currentUser?.hasPasskey == true
                        ? '已绑定通行密钥（每账号限 1 个）'
                        : '安全便捷地登录，无需密码',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '仅使用 Google 密码管理器',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              settings.passkeyGoogleOnly
                  ? '不回退系统/厂商 Passkey 管理器'
                  : 'Google 不可用时允许回退系统管理器',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: settings.passkeyGoogleOnly,
            onChanged: auth.isLoading
                ? null
                : (value) => settings.setPasskeyGoogleOnly(value),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: auth.isLoading || auth.currentUser?.hasPasskey == true
              ? null
              : () async {
                  final success = await auth.bindPasskey();
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('通行密钥绑定成功'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (auth.wasLastPasskeyCancelled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(auth.error ?? '已取消绑定通行密钥'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      // Show detailed debug dialog on real failures only.
                      if (auth.lastPasskeyDebugContext != null) {
                        showDialog(
                          context: context,
                          builder: (context) => PasskeyDebugDialog(
                            debugContext: auth.lastPasskeyDebugContext!,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(auth.error ?? '绑定失败'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
          icon: auth.isLoading && auth.error == null
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSecondaryContainer,
                  ),
                )
              : Icon(
                  auth.currentUser?.hasPasskey == true
                      ? Icons.verified_user_rounded
                      : Icons.add_moderator_rounded,
                  size: 18,
                ),
          label: Text(
            auth.currentUser?.hasPasskey == true ? '已绑定通行密钥' : '添加通行密钥',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _m3ColorChip(
    ColorScheme cs,
    SettingsProvider settings,
    int? colorValue,
    String label,
  ) {
    final isSelected = settings.accentColorValue == colorValue;
    final displayColor = colorValue != null ? Color(colorValue) : cs.primary;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            settings.setAccentColor(colorValue);
          },
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: cs.onSurface, width: 3)
                  : Border.all(color: displayColor.withAlpha(60), width: 1.5),
              // Selected accent uses border weight only (Lumen elevation 0).
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: _contrastColor(displayColor),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

// ── Shared M3 helpers ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return LumenSectionHeader(icon: icon, title: label);
  }
}

class _SettingsCard extends StatelessWidget {
  final ColorScheme cs;
  final List<Widget> children;
  const _SettingsCard({required this.cs, required this.children});

  @override
  Widget build(BuildContext context) {
    return LumenActionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  final IconData icon;
  final String label;
  final double value;
  final String displayValue;
  final double min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.cs,
    required this.tt,
    required this.icon,
    required this.label,
    required this.value,
    required this.displayValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
