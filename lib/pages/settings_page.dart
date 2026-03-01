import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart' show isAndroid;
import '../providers/settings_provider.dart';
import '../utils/update_checker.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelsController;
  late TextEditingController _systemPromptController;
  late TextEditingController _webdavServerController;
  late TextEditingController _webdavUserController;
  late TextEditingController _webdavPasswordController;
  late TextEditingController _upstashUrlController;
  late TextEditingController _upstashTokenController;
  late TextEditingController _vertexProjectIdController;
  late TextEditingController _vertexLocationController;
  late TextEditingController _vertexApiKeyController;
  bool _showApiKey = false;
  bool _isDirty = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelsController = TextEditingController(text: settings.models.join(', '));
    _systemPromptController = TextEditingController(text: settings.systemPrompt);
    _webdavServerController = TextEditingController(text: settings.webdavServer);
    _webdavUserController = TextEditingController(text: settings.webdavUser);
    _webdavPasswordController = TextEditingController(text: settings.webdavPassword);
    _upstashUrlController = TextEditingController(text: settings.upstashUrl);
    _upstashTokenController = TextEditingController(text: settings.upstashToken);
    _vertexProjectIdController = TextEditingController(text: settings.vertexProjectId);
    _vertexLocationController = TextEditingController(text: settings.vertexLocation);
    _vertexApiKeyController = TextEditingController(text: settings.vertexApiKey);
    for (final c in [
      _baseUrlController, _apiKeyController, _modelsController, _systemPromptController,
    ]) {
      c.addListener(() => setState(() => _isDirty = true));
    }
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelsController.dispose();
    _systemPromptController.dispose();
    _webdavServerController.dispose();
    _webdavUserController.dispose();
    _webdavPasswordController.dispose();
    _upstashUrlController.dispose();
    _upstashTokenController.dispose();
    _vertexProjectIdController.dispose();
    _vertexLocationController.dispose();
    _vertexApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildM3Settings(context);
    return _buildFluentSettings(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3Settings(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Future<void> saveAll() async {
      try {
        await settings.setBaseUrl(_baseUrlController.text);
        await settings.setApiKey(_apiKeyController.text);
        await settings.setModels(_modelsController.text);
        await settings.setSystemPrompt(_systemPromptController.text);
        setState(() => _isDirty = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('设置已保存'),
              ]),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      // FAB-style save button that appears when dirty
      floatingActionButton: AnimatedScale(
        scale: _isDirty ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: FloatingActionButton.extended(
          onPressed: saveAll,
          icon: const Icon(Icons.save_rounded),
          label: const Text('保存'),
          elevation: 3,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Collapsing header
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            expandedHeight: 0,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            title: Text('设置', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            actions: [
              if (_isDirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: saveAll,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('保存'),
                  ),
                ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── API Configuration ──
                _SectionHeader(icon: Icons.cloud_outlined, label: 'API 配置', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  TextField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: '基础 URL',
                      hintText: 'https://api.openai.com/v1',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      helperText: 'OpenAI 兼容端点',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    decoration: InputDecoration(
                      labelText: 'API 密钥',
                      hintText: 'sk-...',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 20,
                        ),
                        tooltip: _showApiKey ? '隐藏密钥' : '显示密钥',
                        onPressed: () => setState(() => _showApiKey = !_showApiKey),
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
                      prefixIcon: Icon(Icons.model_training_rounded, size: 20),
                      helperText: '逗号分隔列表',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: settings.models.isNotEmpty && settings.models.contains(settings.selectedModel)
                        ? settings.selectedModel
                        : (settings.models.isNotEmpty ? settings.models.first : null),
                    decoration: const InputDecoration(
                      labelText: '当前模型',
                      prefixIcon: Icon(Icons.smart_toy_outlined, size: 20),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    items: settings.models
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) { if (v != null) settings.setSelectedModel(v); },
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Generation ──
                _SectionHeader(icon: Icons.tune_rounded, label: '生成设置', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  _SliderRow(
                    cs: cs, tt: tt,
                    icon: Icons.thermostat_rounded,
                    label: '温度',
                    value: settings.temperature,
                    displayValue: settings.temperature.toStringAsFixed(2),
                    min: 0, max: 2, divisions: 40,
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
                      style: tt.bodySmall?.copyWith(color: cs.primary, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const Divider(height: 24),
                  _SliderRow(
                    cs: cs, tt: tt,
                    icon: Icons.token_rounded,
                    label: '最大令牌数',
                    value: settings.maxTokens.toDouble(),
                    displayValue: settings.maxTokens >= 1000
                        ? '${(settings.maxTokens / 1000).toStringAsFixed(1)}k'
                        : '${settings.maxTokens}',
                    min: 256, max: 32768, divisions: 64,
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
                ]),
                const SizedBox(height: 20),

                // ── Appearance ──
                _SectionHeader(icon: Icons.palette_outlined, label: '外观', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  // Theme segmented button
                  Row(children: [
                    Icon(Icons.brightness_6_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('主题', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18), label: Text('浅色')),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 18), label: Text('自动')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18), label: Text('深色')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                    style: ButtonStyle(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  Row(children: [
                    Icon(Icons.color_lens_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('强调色', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10, runSpacing: 10,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withAlpha(80),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary.withAlpha(40)),
                    ),
                    child: Row(children: [
                      Icon(
                        settings.accentColorValue == null
                            ? Icons.auto_awesome_rounded
                            : Icons.color_lens_rounded,
                        size: 16, color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          settings.accentColorValue == null
                              ? '使用 Material You 壁纸颜色'
                              : '已应用自定义强调色',
                          style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                        ),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Chat Display ──
                _SectionHeader(icon: Icons.chat_bubble_outline_rounded, label: '聊天显示', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  _SliderRow(
                    cs: cs, tt: tt,
                    icon: Icons.format_size_rounded,
                    label: '字体大小',
                    value: settings.fontSize,
                    displayValue: '${settings.fontSize.toInt()}px',
                    min: 10, max: 24, divisions: 14,
                    onChanged: (v) => settings.setFontSize(v),
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    value: settings.fontFamily,
                    decoration: const InputDecoration(
                      labelText: '字体系列',
                      prefixIcon: Icon(Icons.font_download_outlined, size: 20),
                    ),
                    items: ['System', 'Roboto', 'Open Sans', 'Lato', 'Monospace']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) { if (v != null) settings.setFontFamily(v); },
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
                ]),
                const SizedBox(height: 20),

                // ── Cloud Sync ──
                _SectionHeader(icon: Icons.cloud_sync_rounded, label: '云同步', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
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
                        ButtonSegment(value: 'WebDAV', label: Text('WebDAV'), icon: Icon(Icons.storage_rounded, size: 16)),
                        ButtonSegment(value: 'UpStash', label: Text('UpStash'), icon: Icon(Icons.bolt_rounded, size: 16)),
                      ],
                      selected: {settings.syncMethod},
                      onSelectionChanged: (s) => settings.setSyncMethod(s.first),
                    ),
                    const SizedBox(height: 16),
                    if (settings.syncMethod == 'WebDAV') ...[
                      TextField(
                        controller: _webdavServerController,
                        decoration: const InputDecoration(labelText: '服务器地址', hintText: 'https://dav.example.com'),
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
                        decoration: const InputDecoration(labelText: '密码 / 令牌'),
                        obscureText: true,
                        onChanged: (v) => settings.setWebdavPassword(v),
                      ),
                    ] else ...[
                      TextField(
                        controller: _upstashUrlController,
                        decoration: const InputDecoration(labelText: 'REST URL'),
                        onChanged: (v) => settings.setUpstashUrl(v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upstashTokenController,
                        decoration: const InputDecoration(labelText: 'REST Token'),
                        obscureText: true,
                        onChanged: (v) => settings.setUpstashToken(v),
                      ),
                    ],
                  ],
                ]),
                const SizedBox(height: 20),

                // ── Notes ──
                _SectionHeader(icon: Icons.note_alt_rounded, label: '笔记', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  SwitchListTile(
                    value: settings.notesAutoSave,
                    onChanged: (value) => settings.setNotesAutoSave(value),
                    title: Text('自动保存笔记', style: tt.bodyMedium),
                    subtitle: Text(
                      '离开编辑器时自动保存笔记',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: settings.aiTitleGeneration,
                    onChanged: (value) => settings.setAiTitleGeneration(value),
                    title: Text('AI 标题生成', style: tt.bodyMedium),
                    subtitle: Text(
                      '自动为无标题笔记生成标题',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            settings.notesAutoSave
                                ? '离开编辑器时笔记将自动保存'
                                : '需要使用保存按钮手动保存笔记',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Updates ──
                _SectionHeader(icon: Icons.system_update_rounded, label: '更新', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  Row(children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('版本', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _version.isNotEmpty ? _version : '...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                      ),
                    ),
                  ]),
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
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => UpdateChecker.checkUpdate(context, isAuto: false),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('检查更新'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Vertex AI Translation ──
                _SectionHeader(icon: Icons.translate_rounded, label: 'Vertex AI 翻译', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  TextField(
                    controller: _vertexProjectIdController,
                    decoration: InputDecoration(
                      labelText: 'Project ID',
                      hintText: 'your-project-id',
                      prefixIcon: Icon(Icons.cloud_rounded, color: cs.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => context.read<SettingsProvider>().setVertexProjectId(v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vertexLocationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'us-central1',
                      prefixIcon: Icon(Icons.location_on_rounded, color: cs.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => context.read<SettingsProvider>().setVertexLocation(v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vertexApiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'your-api-key',
                      prefixIcon: Icon(Icons.key_rounded, color: cs.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    onChanged: (v) => context.read<SettingsProvider>().setVertexApiKey(v),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── About ──
                _SectionHeader(icon: Icons.info_outline_rounded, label: '关于', cs: cs, tt: tt),
                const SizedBox(height: 10),
                _SettingsCard(cs: cs, children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.smart_toy_rounded, size: 20, color: cs.onPrimary),
                      ),
                    ),
                    title: Text('关于 NexAI', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '应用信息、功能和致谢',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutPage()),
                      );
                    },
                  ),
                ]),

              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _m3ColorChip(ColorScheme cs, SettingsProvider settings, int? colorValue, String label) {
    final isSelected = settings.accentColorValue == colorValue;
    final displayColor = colorValue != null ? Color(colorValue) : cs.primary;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => settings.setAccentColor(colorValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: displayColor,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: cs.onSurface, width: 3)
                : Border.all(color: displayColor.withAlpha(60), width: 1.5),
            boxShadow: isSelected
                ? [BoxShadow(color: displayColor.withAlpha(100), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: isSelected
              ? Icon(Icons.check_rounded, size: 20, color: _contrastColor(displayColor))
              : null,
        ),
      ),
    );
  }

  Color _contrastColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  // ─── Desktop: Fluent UI ───
  Widget _buildFluentSettings(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = fluent.FluentTheme.of(context);

    return fluent.ScaffoldPage.scrollable(
      header: fluent.PageHeader(
        title: const Text('Settings'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            fluent.FilledButton(
              child: const Row(children: [Icon(fluent.FluentIcons.save, size: 14), SizedBox(width: 8), Text('Save All')]),
              onPressed: () async {
                try {
                  await settings.setBaseUrl(_baseUrlController.text);
                  await settings.setApiKey(_apiKeyController.text);
                  await settings.setModels(_modelsController.text);
                  await settings.setSystemPrompt(_systemPromptController.text);
                  if (mounted) {
                    fluent.displayInfoBar(context, builder: (ctx, close) {
                      return fluent.InfoBar(title: const Text('Settings saved'), severity: fluent.InfoBarSeverity.success, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    fluent.displayInfoBar(context, builder: (ctx, close) {
                      return fluent.InfoBar(title: Text('Failed to save: $e'), severity: fluent.InfoBarSeverity.error, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
      children: [
        _fluentCard(theme, 'API Configuration', fluent.FluentIcons.cloud, [
          fluent.InfoLabel(label: 'Base URL', child: fluent.TextBox(controller: _baseUrlController, placeholder: 'https://api.openai.com/v1')),
          const SizedBox(height: 16),
          fluent.InfoLabel(
            label: 'API Key',
            child: Row(children: [
              Expanded(child: fluent.TextBox(controller: _apiKeyController, placeholder: 'sk-...', obscureText: !_showApiKey)),
              const SizedBox(width: 8),
              fluent.IconButton(icon: Icon(_showApiKey ? fluent.FluentIcons.hide3 : fluent.FluentIcons.view, size: 16), onPressed: () => setState(() => _showApiKey = !_showApiKey)),
            ]),
          ),
          const SizedBox(height: 16),
          fluent.InfoLabel(label: 'Available Models', child: fluent.TextBox(controller: _modelsController, placeholder: 'gpt-4o, gpt-4o-mini', maxLines: 2)),
          const SizedBox(height: 16),
          fluent.InfoLabel(
            label: 'Active Model',
            child: fluent.ComboBox<String>(
              value: settings.selectedModel,
              items: settings.models.map((m) => fluent.ComboBoxItem(value: m, child: Text(m))).toList(),
              onChanged: (v) { if (v != null) settings.setSelectedModel(v); },
              isExpanded: true,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _fluentCard(theme, 'Generation', fluent.FluentIcons.processing, [
          fluent.InfoLabel(label: 'Temperature: ${settings.temperature.toStringAsFixed(2)}', child: fluent.Slider(value: settings.temperature, min: 0, max: 2, divisions: 40, onChanged: (v) => settings.setTemperature(v))),
          const SizedBox(height: 16),
          fluent.InfoLabel(label: 'Max Tokens: ${settings.maxTokens}', child: fluent.Slider(value: settings.maxTokens.toDouble(), min: 256, max: 32768, divisions: 64, onChanged: (v) => settings.setMaxTokens(v.toInt()))),
          const SizedBox(height: 16),
          fluent.InfoLabel(label: 'System Prompt', child: fluent.TextBox(controller: _systemPromptController, maxLines: 4, placeholder: 'You are a helpful assistant...')),
        ]),
        const SizedBox(height: 12),
        _fluentCard(theme, 'Appearance', fluent.FluentIcons.color, [
          fluent.InfoLabel(
            label: 'Theme',
            child: fluent.ComboBox<ThemeMode>(
              value: settings.themeMode,
              items: const [
                fluent.ComboBoxItem(value: ThemeMode.system, child: Text('System')),
                fluent.ComboBoxItem(value: ThemeMode.light, child: Text('Light')),
                fluent.ComboBoxItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (v) { if (v != null) settings.setThemeMode(v); },
              isExpanded: true,
            ),
          ),
          const SizedBox(height: 20),
          fluent.InfoLabel(
            label: 'Accent Color',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _fluentColorBtn(context, settings, null, 'System', theme),
              _fluentColorBtn(context, settings, 0xFF0078D4, 'Blue', theme),
              _fluentColorBtn(context, settings, 0xFF744DA9, 'Purple', theme),
              _fluentColorBtn(context, settings, 0xFFE74856, 'Red', theme),
              _fluentColorBtn(context, settings, 0xFFFF8C00, 'Orange', theme),
              _fluentColorBtn(context, settings, 0xFF10893E, 'Green', theme),
              _fluentColorBtn(context, settings, 0xFF00B7C3, 'Teal', theme),
              _fluentColorBtn(context, settings, 0xFFE3008C, 'Pink', theme),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _fluentCard(theme, 'Notes', fluent.FluentIcons.edit_note, [
          Row(
            children: [
              Expanded(
                child: Text('Auto-save notes', style: theme.typography.body),
              ),
              fluent.ToggleSwitch(
                checked: settings.notesAutoSave,
                onChanged: (value) => settings.setNotesAutoSave(value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('AI title generation', style: theme.typography.body),
              ),
              fluent.ToggleSwitch(
                checked: settings.aiTitleGeneration,
                onChanged: (value) => settings.setAiTitleGeneration(value),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _fluentCard(fluent.FluentThemeData theme, String title, IconData icon, List<Widget> children) {
    return fluent.Card(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }

  Widget _fluentColorBtn(BuildContext context, SettingsProvider settings, int? colorValue, String tooltip, fluent.FluentThemeData theme) {
    final isSelected = settings.accentColorValue == colorValue;
    final displayColor = colorValue != null ? Color(colorValue) : theme.accentColor;
    return fluent.Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => settings.setAccentColor(colorValue),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: displayColor, borderRadius: BorderRadius.circular(18),
            border: isSelected ? Border.all(color: theme.typography.body?.color ?? Colors.white, width: 2.5) : Border.all(color: displayColor.withAlpha((0.5 * 255).round())),
            boxShadow: isSelected ? [BoxShadow(color: displayColor.withAlpha((0.4 * 255).round()), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: isSelected ? Icon(fluent.FluentIcons.check_mark, size: 14, color: _contrastColor(displayColor)) : null,
        ),
      ),
    );
  }
}

// ── Shared M3 helpers ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  const _SectionHeader({required this.icon, required this.label, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withAlpha(160),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(child: Icon(icon, size: 16, color: cs.primary)),
      ),
      const SizedBox(width: 10),
      Text(label, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1, color: cs.onSurface)),
    ]);
  }
}

class _SettingsCard extends StatelessWidget {
  final ColorScheme cs;
  final List<Widget> children;
  const _SettingsCard({required this.cs, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
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
    required this.cs, required this.tt, required this.icon, required this.label,
    required this.value, required this.displayValue, required this.min, required this.max,
    required this.divisions, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(label, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(displayValue, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
        ),
      ]),
      Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ]);
  }
}
