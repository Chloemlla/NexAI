import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/navigation_helper.dart';

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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', width: 80, height: 80),
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
                  onPressed: settings.isConfigured
                      ? () async {
                          await context.read<ChatProvider>().newConversation();
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
            const SizedBox(height: 40),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _welcomeCard(
                  cs,
                  Icons.chat_rounded,
                  '对话',
                  '任何问题都可以直接发问',
                  cardWidth,
                ),
                _welcomeCard(
                  cs,
                  Icons.functions_rounded,
                  '数学',
                  '自动渲染 LaTeX 公式',
                  cardWidth,
                ),
                _welcomeCard(
                  cs,
                  Icons.science_rounded,
                  '化学',
                  '方程式与结构式表达',
                  cardWidth,
                ),
                _welcomeCard(
                  cs,
                  Icons.code_rounded,
                  '代码',
                  '支持高亮与结构化展示',
                  cardWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard(
    ColorScheme cs,
    IconData icon,
    String title,
    String subtitle,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest.withAlpha(200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icon, size: 22, color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
