import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/oss_dependency_credits.dart';
import '../models/oss_dependency_credit.dart';
import '../providers/settings_provider.dart';
import '../theme/lumen_tokens.dart';
import '../widgets/lumen/lumen.dart';

/// First-install notice covering OSS source, free policy, license and credits.
class OssNoticePage extends StatefulWidget {
  const OssNoticePage({super.key});

  @override
  State<OssNoticePage> createState() => _OssNoticePageState();
}

class _OssNoticePageState extends State<OssNoticePage> {
  bool _submitting = false;

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        SmartDialog.showToast('无法打开链接');
      }
    } catch (_) {
      SmartDialog.showToast('无法打开链接');
    }
  }

  Future<void> _acknowledge() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await context.read<SettingsProvider>().acknowledgeOssNotice();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final hPad = LumenTokens.horizontalPaddingForWidth(mq.size.width);

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/app_icon_runtime.png',
                                    width: 84,
                                    height: 84,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '欢迎使用 NexAI',
                                    style: tt.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '开源 · 永久免费 · 请从官方渠道获取',
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            _SectionHeader(
                              icon: Icons.code_rounded,
                              title: '官方开源地址',
                            ),
                            const SizedBox(height: 10),
                            _InfoPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NexAI 是开源项目。官方代码与发行版通过以下地址提供：',
                                    style: tt.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    kNexAIRepositoryUrl,
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _openUrl(kNexAIRepositoryUrl),
                                        icon: const Icon(Icons.open_in_new_rounded),
                                        label: const Text('打开 GitHub'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openUrl(kNexAIReleasesUrl),
                                        icon: const Icon(
                                          Icons.system_update_rounded,
                                        ),
                                        label: const Text('官方发行版'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _SectionHeader(
                              icon: Icons.verified_user_outlined,
                              title: '永久免费 · 谨防受骗',
                            ),
                            const SizedBox(height: 10),
                            _InfoPanel(
                              emphasize: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NexAI 客户端本身永久免费，不存在“官方收费版解锁全部功能”的销售话术。',
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const _Bullet(
                                    '请勿向任何声称“代下载 / 内部破解版 / 收费激活码”的第三方付款。',
                                  ),
                                  const _Bullet(
                                    '安装请优先从 GitHub Releases 或可核验的官方来源获取。',
                                  ),
                                  const _Bullet(
                                    '你自己的 API Key 或云服务费用，属于你使用的模型/后端服务，与本应用授权费无关。',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _SectionHeader(
                              icon: Icons.balance_rounded,
                              title: '本项目开源协议',
                            ),
                            const SizedBox(height: 10),
                            _InfoPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    kNexAIProjectLicense,
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'NexAI 以 GNU General Public License v3.0 发布。你可以自由使用、研究、分享与修改；分发修改版本时需保持同样的自由与源码可获得性。',
                                    style: tt.bodyMedium,
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: () => _openUrl(kNexAILicenseUrl),
                                    icon: const Icon(Icons.description_outlined),
                                    label: const Text('查看完整许可证'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _SectionHeader(
                              icon: Icons.favorite_outline_rounded,
                              title: '第三方依赖鸣谢',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '感谢以下直接运行时依赖与内置字体的作者与社区。下列信息为便于阅读的摘要，完整条款以其原项目许可证为准。',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                    sliver: SliverList.separated(
                      itemCount: kOssDependencyCredits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final credit = kOssDependencyCredits[index];
                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _DependencyTile(
                              credit: credit,
                              onOpen: credit.url == null
                                  ? null
                                  : () => _openUrl(credit.url!),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: lumenScaffoldBackground(cs),
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant.withAlpha(120)),
                  ),
                ),
                child: FilledButton(
                  onPressed: _submitting ? null : _acknowledge,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('我已了解，开始使用'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return LumenSectionHeader(icon: icon, title: title);
  }
}

class _InfoPanel extends StatelessWidget {
  final Widget child;
  final bool emphasize;

  const _InfoPanel({required this.child, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = emphasize
        ? cs.errorContainer.withAlpha(120)
        : cs.surfaceContainerLow;

    return LumenActionCard(
      color: bg,
      borderSide: emphasize
          ? BorderSide(color: cs.error.withAlpha(90))
          : BorderSide(color: cs.outlineVariant.withAlpha(90)),
      child: child,
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}

class _DependencyTile extends StatelessWidget {
  final OssDependencyCredit credit;
  final VoidCallback? onOpen;

  const _DependencyTile({required this.credit, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withAlpha(110)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            credit.name,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${credit.author} · ${credit.license}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(credit.description, style: tt.bodyMedium),
            ),
            const SizedBox(height: 10),
            _MetaRow(label: '作者', value: credit.author),
            const SizedBox(height: 6),
            _MetaRow(label: '协议', value: credit.license),
            if (onOpen != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('查看项目'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Text(value, style: tt.bodySmall)),
      ],
    );
  }
}
