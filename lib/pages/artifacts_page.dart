/// Artifacts List Page
/// Displays user's shared artifacts with management options
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/artifacts_provider.dart';
import '../providers/auth_provider.dart';
import '../models/artifact.dart';

class ArtifactsPage extends StatefulWidget {
  const ArtifactsPage({super.key});

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
  @override
  void initState() {
    super.initState();
    _loadArtifacts();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final artifactsProvider = context.watch<ArtifactsProvider>();

    if (!authProvider.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的分享'),
        ),
        body: const Center(
          child: Text('请先登录以查看分享内容'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArtifacts,
          ),
        ],
      ),
      body: artifactsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : artifactsProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('加载失败: ${artifactsProvider.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArtifacts,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : artifactsProvider.artifacts.isEmpty
                  ? const Center(
                      child: Text('暂无分享内容'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadArtifacts,
                      child: ListView.builder(
                        itemCount: artifactsProvider.artifacts.length,
                        itemBuilder: (context, index) {
                          final artifact = artifactsProvider.artifacts[index];
                          return _ArtifactListItem(
                            artifact: artifact,
                            onDelete: () => _deleteArtifact(artifact.shortId),
                            onCopyLink: () => _copyLink(artifact.shortId),
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _deleteArtifact(String shortId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个分享吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authProvider = context.read<AuthProvider>();
      final artifactsProvider = context.read<ArtifactsProvider>();

      final success = await artifactsProvider.deleteArtifact(
        shortId,
        accessToken: authProvider.accessToken!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '删除成功' : '删除失败'),
          ),
        );
      }
    }
  }

  void _copyLink(String shortId) {
    final url = 'https://api.951100.xyz/share/$shortId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制到剪贴板')),
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
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getContentTypeIcon(),
        title: Text(
          artifact.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('类型: ${_getContentTypeLabel()}'),
            Text('可见性: ${_getVisibilityLabel()}'),
            Text('查看次数: ${artifact.viewCount}'),
            Text('创建时间: ${dateFormat.format(artifact.createdAt)}'),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
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
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('复制链接'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getContentTypeIcon() {
    switch (artifact.contentType) {
      case 'code':
        return const Icon(Icons.code, color: Colors.blue);
      case 'markdown':
        return const Icon(Icons.article, color: Colors.green);
      case 'html':
        return const Icon(Icons.web, color: Colors.orange);
      case 'mermaid':
        return const Icon(Icons.account_tree, color: Colors.purple);
      default:
        return const Icon(Icons.description);
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
        return 'Mermaid 图表';
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
