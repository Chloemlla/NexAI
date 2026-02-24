import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show isAndroid;
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
    if (isAndroid) return _buildM3Settings(context);
    return _buildFluentSettings(context);
  }

  // ─── Android: Material 3 ───
  Widget _buildM3Settings(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Future<void> saveAll() async {
      await settings.setBaseUrl(_baseUrlController.text);
      await settings.setApiKey(_apiKeyController.text);
      await settings.setModels(_modelsController.text);
      await settings.setSystemPrompt(_systemPromptController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Save button
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: saveAll,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.save_rounded, size: 18), SizedBox(width: 8), Text('Save All')]),
          ),
        ),
        const SizedBox(height: 12),

        // API Configuration
        _m3Section(cs, tt, Icons.cloud_outlined, 'API Configuration', [
          TextField(controller: _baseUrlController, decoration: const InputDecoration(labelText: 'Base URL', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _modelsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Models (comma separated)', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: settings.models.contains(settings.selectedModel) ? settings.selectedModel : (settings.models.isNotEmpty ? settings.models.first : null),
            decoration: const InputDecoration(labelText: 'Active Model', border: OutlineInputBorder()),
            items: settings.models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) { if (v != null) settings.setSelectedModel(v); },
          ),
        ]),
        const SizedBox(height: 12),

        // Generation
        _m3Section(cs, tt, Icons.tune_rounded, 'Generation', [
          Text('Temperature: ${settings.temperature.toStringAsFixed(2)}', style: tt.bodySmall),
          Slider(value: settings.temperature, min: 0, max: 2, divisions: 40, onChanged: (v) => settings.setTemperature(v)),
          const SizedBox(height: 8),
          Text('Max Tokens: ${settings.maxTokens}', style: tt.bodySmall),
          Slider(value: settings.maxTokens.toDouble(), min: 256, max: 32768, divisions: 64, onChanged: (v) => settings.setMaxTokens(v.toInt())),
          const SizedBox(height: 8),
          TextField(controller: _systemPromptController, maxLines: 4, decoration: const InputDecoration(labelText: 'System Prompt', border: OutlineInputBorder())),
        ]),
        const SizedBox(height: 12),

        // Appearance
        _m3Section(cs, tt, Icons.palette_outlined, 'Appearance', [
          DropdownButtonFormField<ThemeMode>(
            value: settings.themeMode,
            decoration: const InputDecoration(labelText: 'Theme', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (v) { if (v != null) settings.setThemeMode(v); },
          ),
          const SizedBox(height: 16),
          Text('Accent Color', style: tt.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _m3ColorChip(cs, settings, null, 'Dynamic'),
              _m3ColorChip(cs, settings, 0xFF6750A4, 'Purple'),
              _m3ColorChip(cs, settings, 0xFF0078D4, 'Blue'),
              _m3ColorChip(cs, settings, 0xFFE74856, 'Red'),
              _m3ColorChip(cs, settings, 0xFFFF8C00, 'Orange'),
              _m3ColorChip(cs, settings, 0xFF10893E, 'Green'),
              _m3ColorChip(cs, settings, 0xFF00B7C3, 'Teal'),
              _m3ColorChip(cs, settings, 0xFFE3008C, 'Pink'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            settings.accentColorValue == null ? 'Using Material You dynamic color' : 'Custom accent color',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ]),
      ],
    );
  }

  Widget _m3Section(ColorScheme cs, TextTheme tt, IconData icon, String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
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
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: displayColor,
            shape: BoxShape.circle,
            border: isSelected ? Border.all(color: cs.onSurface, width: 3) : Border.all(color: displayColor.withAlpha((0.4 * 255).round())),
          ),
          child: isSelected ? Icon(Icons.check_rounded, size: 16, color: _contrastColor(displayColor)) : null,
        ),
      ),
    );
  }

  Color _contrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

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
                await settings.setBaseUrl(_baseUrlController.text);
                await settings.setApiKey(_apiKeyController.text);
                await settings.setModels(_modelsController.text);
                await settings.setSystemPrompt(_systemPromptController.text);
                if (mounted) {
                  fluent.displayInfoBar(context, builder: (ctx, close) {
                    return fluent.InfoBar(title: const Text('Settings saved'), severity: fluent.InfoBarSeverity.success, action: fluent.IconButton(icon: const Icon(fluent.FluentIcons.clear), onPressed: close));
                  });
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
