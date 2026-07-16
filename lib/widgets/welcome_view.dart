import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/navigation_helper.dart';
import '../theme/lumen_tokens.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildWelcome(context);
  }

  Widget _buildWelcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final cardWidth = isWide ? 180.0 : (screenWidth - 52) / 2;
    final settings = context.watch<SettingsProvider>();
    final chat = context.watch<ChatProvider>();
    final suggestions = const [
      _PromptSuggestion(
        icon: Icons.auto_awesome_rounded,
        title: '整理思路',
        prompt: '帮我把下面的想法整理成清晰的行动清单：',
      ),
      _PromptSuggestion(
        icon: Icons.code_rounded,
        title: '解释代码',
        prompt: '请用简洁步骤解释这段代码的作用，并指出潜在风险：',
      ),
      _PromptSuggestion(
        icon: Icons.school_rounded,
        title: '学习计划',
        prompt: '为我制定一个 7 天入门学习计划，主题是：',
      ),
      _PromptSuggestion(
        icon: Icons.edit_note_rounded,
        title: '润色文本',
        prompt: '请润色下面这段文字，使其更清晰、自然、专业：',
      ),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: LumenTokens.horizontalPaddingForWidth(screenWidth),
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/app_icon_runtime.png', width: 80, height: 80),
            const SizedBox(height: 28),
            Text(
              '开始与 NexAI 对话',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.isConfigured
                  ? '支持 Markdown、代码、公式与多模态内容。'
                  : '先完成 API 配置，再开始你的第一轮对话。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: chat.isLoading
                      ? null
                      : settings.isConfigured
                          ? () async {
                              await context
                                  .read<ChatProvider>()
                                  .newConversation();
                            }
                          : NavigationHelper.goToSettings,
                  icon: Icon(
                    settings.isConfigured
                        ? Icons.add_comment_rounded
                        : Icons.tune_rounded,
                  ),
                  label: Text(settings.isConfigured ? '开始新对话' : '前往设置'),
                ),
                if (settings.isConfigured)
                  OutlinedButton.icon(
                    onPressed: NavigationHelper.goToSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('调整模型'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            _buildStatusPanel(context, cs, settings, chat.isLoading),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: suggestions
                    .map(
                      (item) => _suggestionCard(
                        context,
                        cs,
                        item,
                        cardWidth,
                        settings,
                        chat.isLoading,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(
    BuildContext context,
    ColorScheme cs,
    SettingsProvider settings,
    bool isLoading,
  ) {
    final tt = Theme.of(context).textTheme;
    final statusTitle = settings.isConfigured
        ? settings.selectedModel
        : '需要完成 API 配置';
    final String statusDetail;
    if (isLoading) {
      statusDetail = 'NexAI 正在生成回复';
    } else if (settings.isConfigured) {
      statusDetail =
          '${settings.apiMode} · 温度 '
          '${settings.temperature.toStringAsFixed(1)} · '
          '${settings.maxTokens} tokens';
    } else {
      statusDetail = '配置完成后即可使用示例提示和多模态能力';
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LumenTokens.maxContentWidth),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: LumenTokens.cardBorderRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: settings.isConfigured
                    ? cs.primaryContainer
                    : cs.errorContainer.withAlpha(160),
                borderRadius: LumenTokens.chipBorderRadius,
              ),
              child: Icon(
                settings.isConfigured
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: settings.isConfigured
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: NavigationHelper.goToSettings,
              tooltip: '打开设置',
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(
    BuildContext context,
    ColorScheme cs,
    _PromptSuggestion item,
    double width,
    SettingsProvider settings,
    bool isLoading,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        color: cs.surfaceContainerHighest.withAlpha(160),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: LumenTokens.cardBorderRadius,
        ),
        child: InkWell(
          onTap: isLoading
              ? null
              : () => _sendPrompt(context, settings, item.prompt),
          borderRadius: LumenTokens.cardBorderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: LumenTokens.chipBorderRadius,
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.prompt,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendPrompt(
    BuildContext context,
    SettingsProvider settings,
    String prompt,
  ) async {
    if (!settings.isConfigured) {
      NavigationHelper.goToSettings();
      return;
    }

    await context.read<ChatProvider>().sendMessage(
          content: prompt,
          apiMode: settings.apiMode,
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          model: settings.selectedModel,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens,
          systemPrompt: settings.systemPrompt,
          vertexProjectId: settings.vertexProjectId,
          vertexLocation: settings.vertexLocation,
        );
  }
}

class _PromptSuggestion {
  final IconData icon;
  final String title;
  final String prompt;

  const _PromptSuggestion({
    required this.icon,
    required this.title,
    required this.prompt,
  });
}
