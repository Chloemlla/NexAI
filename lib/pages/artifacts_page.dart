import 'package:flutter/material.dart';
import '../utils/nexai_api_error.dart';
import '../theme/lumen_tokens.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/artifact.dart';
import '../providers/artifacts_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/tool_page_style.dart';
import '../widgets/lumen/lumen.dart';

class ArtifactsPage extends StatefulWidget {
  const ArtifactsPage({super.key});

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
  late final AuthProvider _authProvider;
  String? _lastLoadedAccessToken;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_handleAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleAuthChanged();
      }
    });
  }

  Future<void> _loadArtifacts() async {
    final authProvider = context.read<AuthProvider>();
    final artifactsProvider = context.read<ArtifactsProvider>();

    if (authProvider.isLoggedIn) {
      await artifactsProvider.loadArtifacts(
        accessToken: authProvider.accessToken!,
      );
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;

    final accessToken = _authProvider.accessToken;
    final artifactsProvider = context.read<ArtifactsProvider>();

    if (!_authProvider.isLoggedIn || accessToken == null) {
      _lastLoadedAccessToken = null;
      return;
    }

    if (artifactsProvider.isLoading || _lastLoadedAccessToken == accessToken) {
      return;
    }

    _lastLoadedAccessToken = accessToken;
    _loadArtifacts();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> _deleteArtifact(String shortId) async {
    final authProvider = context.read<AuthProvider>();
    final artifactsProvider = context.read<ArtifactsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final success = await artifactsProvider.deleteArtifact(
      shortId,
      accessToken: authProvider.accessToken!,
    );

    if (!mounted) return;

    if (success) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('删除成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      await showNexaiErrorDialog(
        context,
        NexaiApiError(
          stage: 'http_status',
          code: 'ARTIFACT_DELETE_FAILED',
          message: artifactsProvider.error ?? '删除失败',
        ),
        title: '删除分享失败',
      );
    }
  }

  void _copyLink(String shortId) {
    final url = 'https://tts.chloemlla.com/share/$shortId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('链接已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final artifactsProvider = context.watch<ArtifactsProvider>();
    final artifacts = artifactsProvider.artifacts;
    final isLoggedIn = authProvider.isLoggedIn;
    final cs = Theme.of(context).colorScheme;

    if (!isLoggedIn) {
      return LumenSecondaryScaffold(
        title: '我的分享',
        children: const [
          LumenPageIntro(
            icon: Icons.share_rounded,
            title: '我的分享',
            description: '查看并管理你已经发布的分享内容，包括复制链接、刷新列表和删除记录。',
            chips: ['需要登录', '集中管理'],
          ),
          ToolEmptyStateCard(
            icon: Icons.login_rounded,
            title: '请先登录',
            description: '登录后才能拉取你的分享记录并进行管理。',
          ),
        ],
      );
    }

    final intro = LumenPageIntro(
      icon: Icons.share_rounded,
      title: '我的分享',
      description: '把登录状态、空状态和列表管理统一进同一套信息层级，减少“页面空白但不知道原因”的困惑。',
      chips: [
        artifactsProvider.isLoading ? '同步中' : '${artifacts.length} 条记录',
        artifactsProvider.error == null ? '状态正常' : '加载异常',
      ],
    );

    final refreshAction = IconButton(
      icon: const Icon(Icons.refresh_rounded),
      tooltip: '刷新',
      onPressed: _loadArtifacts,
    );

    if (artifactsProvider.isLoading && artifacts.isEmpty) {
      return Scaffold(
        backgroundColor: lumenScaffoldBackground(cs),
        appBar: AppBar(
          title: const Text('我的分享'),
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [refreshAction],
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                LumenTokens.horizontalPaddingForWidth(MediaQuery.sizeOf(context).width),
                LumenTokens.pagePaddingTop,
                LumenTokens.horizontalPaddingForWidth(MediaQuery.sizeOf(context).width),
                0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LumenTokens.maxContentWidth),
                child: intro,
              ),
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    if (artifactsProvider.error != null && artifacts.isEmpty) {
      return LumenSecondaryScaffold(
        title: '我的分享',
        actions: [refreshAction],
        children: [
          intro,
          ToolEmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: '加载失败',
            description: artifactsProvider.error ?? '加载失败',
            action: FilledButton.icon(
              onPressed: _loadArtifacts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }

    if (artifacts.isEmpty) {
      return LumenSecondaryScaffold(
        title: '我的分享',
        actions: [refreshAction],
        children: [
          intro,
          ToolEmptyStateCard(
            icon: Icons.inbox_rounded,
            title: '暂无分享内容',
            description: '创建并分享内容后，这里会自动出现你的记录列表。',
            action: FilledButton.tonalIcon(
              onPressed: _loadArtifacts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          ),
        ],
      );
    }

    return LumenSecondaryScaffold(
      title: '我的分享',
      actions: [refreshAction],
      children: [
        intro,
        ToolQuickActionsBar(
          actions: [
            ToolQuickActionData(
              icon: Icons.refresh_rounded,
              label: '刷新列表',
              onTap: _loadArtifacts,
            ),
            ToolQuickActionData(
              icon: Icons.copy_rounded,
              label: '复制最新链接',
              backgroundColor: cs.secondaryContainer,
              iconColor: cs.onSecondaryContainer,
              onTap: () => _copyLink(artifacts.first.shortId),
            ),
          ],
        ),
        LumenSettingsSection(
          icon: Icons.inventory_2_rounded,
          title: '分享记录',
          subtitle: '${artifacts.length} 条',
          children: [
            for (final artifact in artifacts)
              _ArtifactListItem(
                artifact: artifact,
                onCopyLink: () => _copyLink(artifact.shortId),
                onDelete: () => _deleteArtifact(artifact.shortId),
              ),
          ],
        ),
      ],
    );
  }


}

class _ArtifactListItem extends StatelessWidget {
  final ArtifactSummary artifact;
  final VoidCallback onDelete;
  final VoidCallback onCopyLink;

  const _ArtifactListItem({
    required this.artifact,
    required this.onDelete,
    required this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ToolPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(LumenTokens.radiusSm),
                ),
                child: Icon(_getContentTypeIcon(), color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: _getContentTypeLabel()),
                        _MetaChip(label: _getVisibilityLabel()),
                        _MetaChip(label: '${artifact.viewCount} 次查看'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'copy':
                      onCopyLink();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded),
                        SizedBox(width: 8),
                        Text('复制链接'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: cs.outline),
              const SizedBox(width: 8),
              Text(
                '创建于 ${dateFormat.format(artifact.createdAt)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getContentTypeIcon() {
    switch (artifact.contentType) {
      case 'code':
        return Icons.code_rounded;
      case 'markdown':
        return Icons.article_rounded;
      case 'html':
        return Icons.web_rounded;
      case 'mermaid':
        return Icons.account_tree_rounded;
      case 'json':
        return Icons.data_object_rounded;
      case 'svg':
        return Icons.draw_rounded;
      case 'latex':
        return Icons.functions_rounded;
      case 'csv':
        return Icons.table_chart_rounded;
      case 'xml':
        return Icons.code_off_rounded;
      case 'text':
        return Icons.text_snippet_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  String _getContentTypeLabel() {
    switch (artifact.contentType) {
      case 'code':
        return '代码';
      case 'markdown':
        return 'Markdown';
      case 'html':
        return 'HTML';
      case 'mermaid':
        return 'Mermaid';
      case 'json':
        return 'JSON';
      case 'svg':
        return 'SVG';
      case 'latex':
        return 'LaTeX';
      case 'csv':
        return 'CSV';
      case 'xml':
        return 'XML';
      case 'text':
        return '纯文本';
      default:
        return artifact.contentType;
    }
  }

  String _getVisibilityLabel() {
    switch (artifact.visibility) {
      case 'public':
        return '公开';
      case 'private':
        return '私密';
      case 'password':
        return '密码保护';
      default:
        return artifact.visibility;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
