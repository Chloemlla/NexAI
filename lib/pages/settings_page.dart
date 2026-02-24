import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

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
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelsController = TextEditingController(text: settings.models.join(', '));
    _systemPromptController = TextEditingController(text: settings.systemPrompt);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelsController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Settings'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              child: const Row(
                children: [
                  Icon(FluentIcons.save, size: 14),
                  SizedBox(width: 8),
                  Text('Save All'),
                ],
              ),
              onPressed: () async {
                await settings.setBaseUrl(_baseUrlController.text);
                await settings.setApiKey(_apiKeyController.text);
                await settings.setModels(_modelsController.text);
                await settings.setSystemPrompt(_systemPromptController.text);
                if (mounted) {
                  displayInfoBar(context, builder: (ctx, close) {
                    return InfoBar(
                      title: const Text('Settings saved'),
                      severity: InfoBarSeverity.success,
                      action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
      children: [
        // API Configuration Card
        _buildCard(
          theme,
          title: 'API Configuration',
          icon: FluentIcons.cloud,
          children: [
            InfoLabel(
              label: 'Base URL',
              child: TextBox(
                controller: _baseUrlController,
                placeholder: 'https://api.openai.com/v1',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'API Key',
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _apiKeyController,
                      placeholder: 'sk-...',
                      obscureText: !_showApiKey,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_showApiKey ? FluentIcons.hide3 : FluentIcons.view, size: 16),
                    onPressed: () => setState(() => _showApiKey = !_showApiKey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Available Models (comma separated)',
              child: TextBox(
                controller: _modelsController,
                placeholder: 'gpt-4o, gpt-4o-mini, gpt-3.5-turbo',
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Active Model',
              child: ComboBox<String>(
                value: settings.selectedModel,
                items: settings.models
                    .map((m) => ComboBoxItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) settings.setSelectedModel(v);
                },
                isExpanded: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Generation Settings Card
        _buildCard(
          theme,
          title: 'Generation',
          icon: FluentIcons.processing,
          children: [
            InfoLabel(
              label: 'Temperature: ${settings.temperature.toStringAsFixed(2)}',
              child: Slider(
                value: settings.temperature,
                min: 0,
                max: 2,
                divisions: 40,
                onChanged: (v) => settings.setTemperature(v),
                label: settings.temperature.toStringAsFixed(2),
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Max Tokens: ${settings.maxTokens}',
              child: Slider(
                value: settings.maxTokens.toDouble(),
                min: 256,
                max: 32768,
                divisions: 64,
                onChanged: (v) => settings.setMaxTokens(v.toInt()),
                label: '${settings.maxTokens}',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'System Prompt',
              child: TextBox(
                controller: _systemPromptController,
                maxLines: 4,
                placeholder: 'You are a helpful assistant...',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Appearance Card
        _buildCard(
          theme,
          title: 'Appearance',
          icon: FluentIcons.color,
          children: [
            InfoLabel(
              label: 'Theme',
              child: ComboBox<ThemeMode>(
                value: settings.themeMode,
                items: const [
                  ComboBoxItem(value: ThemeMode.system, child: Text('System')),
                  ComboBoxItem(value: ThemeMode.light, child: Text('Light')),
                  ComboBoxItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (v) {
                  if (v != null) settings.setThemeMode(v);
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 20),
            InfoLabel(
              label: 'Accent Color',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _colorButton(context, settings, null, 'System / Dynamic', theme),
                      _colorButton(context, settings, 0xFF0078D4, 'Blue', theme),
                      _colorButton(context, settings, 0xFF744DA9, 'Purple', theme),
                      _colorButton(context, settings, 0xFFE74856, 'Red', theme),
                      _colorButton(context, settings, 0xFFFF8C00, 'Orange', theme),
                      _colorButton(context, settings, 0xFF10893E, 'Green', theme),
                      _colorButton(context, settings, 0xFF00B7C3, 'Teal', theme),
                      _colorButton(context, settings, 0xFFE3008C, 'Pink', theme),
                      _colorButton(context, settings, 0xFF8E562E, 'Brown', theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.accentColorValue == null
                        ? 'Using system / dynamic color (Material You on Android)'
                        : 'Custom accent color selected',
                    style: TextStyle(fontSize: 12, color: theme.inactiveColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _colorButton(BuildContext context, SettingsProvider settings, int? colorValue, String tooltip, FluentThemeData theme) {
    final isSelected = settings.accentColorValue == colorValue;
    final displayColor = colorValue != null ? Color(colorValue) : theme.accentColor;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => settings.setAccentColor(colorValue),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: displayColor,
            borderRadius: BorderRadius.circular(18),
            border: isSelected
                ? Border.all(color: theme.typography.body?.color ?? Colors.white, width: 2.5)
                : Border.all(color: displayColor.withOpacity(0.5), width: 1),
            boxShadow: isSelected
                ? [BoxShadow(color: displayColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: isSelected
              ? Icon(FluentIcons.check_mark, size: 14, color: _contrastColor(displayColor))
              : (colorValue == null ? Icon(FluentIcons.sync_icon, size: 12, color: _contrastColor(displayColor)) : null),
        ),
      ),
    );
  }

  Color _contrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  Widget _buildCard(FluentThemeData theme, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
