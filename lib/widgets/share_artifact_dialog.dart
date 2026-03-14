/// Share Artifact Dialog Widget
/// Allows users to share content as artifacts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/artifacts_provider.dart';
import '../providers/auth_provider.dart';

class ShareArtifactDialog extends StatefulWidget {
  final String content;
  final String contentType;
  final String? language;
  final String? defaultTitle;

  const ShareArtifactDialog({
    super.key,
    required this.content,
    required this.contentType,
    this.language,
    this.defaultTitle,
  });

  @override
  State<ShareArtifactDialog> createState() => _ShareArtifactDialogState();
}

class _ShareArtifactDialogState extends State<ShareArtifactDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _expiresController = TextEditingController(text: '30');

  String _visibility = 'public';
  bool _loading = false;
  String? _shareUrl;

  @override
  void initState() {
    super.initState();
    if (widget.defaultTitle != null) {
      _titleController.text = widget.defaultTitle!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('分享内容'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: '可见性',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('公开')),
                  DropdownMenuItem(value: 'private', child: Text('私密')),
                  DropdownMenuItem(value: 'password', child: Text('密码保护')),
                ],
                onChanged: (value) {
                  setState(() {
                    _visibility = value!;
                  });
                },
              ),
              if (_visibility == 'password') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _expiresController,
                decoration: const InputDecoration(
                  labelText: '过期天数（可选）',
                  border: OutlineInputBorder(),
                  hintText: '留空表示永不过期',
                ),
                keyboardType: TextInputType.number,
              ),
              if (_shareUrl != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  '分享链接已创建：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _shareUrl!,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('复制链接'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _shareUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_shareUrl != null ? '关闭' : '取消'),
        ),
        if (_shareUrl == null)
          ElevatedButton(
            onPressed: _loading ? null : _createArtifact,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建分享'),
          ),
      ],
    );
  }

  Future<void> _createArtifact() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    if (_visibility == 'password' && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入密码')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final artifactsProvider = context.read<ArtifactsProvider>();

      if (!authProvider.isLoggedIn) {
        throw Exception('请先登录');
      }

      final expiresInDays = _expiresController.text.isEmpty
          ? null
          : int.tryParse(_expiresController.text);

      final response = await artifactsProvider.createArtifact(
        accessToken: authProvider.accessToken!,
        title: _titleController.text,
        contentType: widget.contentType,
        content: widget.content,
        language: widget.language,
        visibility: _visibility,
        password: _visibility == 'password' ? _passwordController.text : null,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        expiresInDays: expiresInDays,
      );

      if (response != null) {
        setState(() {
          _shareUrl = response.shareUrl;
          _loading = false;
        });
      } else {
        throw Exception(artifactsProvider.error ?? '创建失败');
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    _expiresController.dispose();
    super.dispose();
  }
}

/// Share Artifact Button Widget
class ShareArtifactButton extends StatelessWidget {
  final String content;
  final String contentType;
  final String? language;
  final String? defaultTitle;

  const ShareArtifactButton({
    super.key,
    required this.content,
    required this.contentType,
    this.language,
    this.defaultTitle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      tooltip: '分享',
      onPressed: () => _showShareDialog(context),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ShareArtifactDialog(
        content: content,
        contentType: contentType,
        language: language,
        defaultTitle: defaultTitle,
      ),
    );
  }
}
