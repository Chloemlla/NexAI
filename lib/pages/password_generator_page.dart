import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/password_provider.dart';
import '../models/saved_password.dart';

enum PasswordType { random, memorable, pin }

class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  State<PasswordGeneratorPage> createState() => _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState extends State<PasswordGeneratorPage> with SingleTickerProviderStateMixin {
  PasswordType _selectedType = PasswordType.random;
  String _generatedPassword = '';
  late TabController _tabController;
  
  // Batch generation
  int _batchCount = 10;
  List<String> _batchPasswords = [];
  
  // Random password settings
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  
  // Memorable password settings
  int _wordCount = 4;
  String _separator = '-';
  bool _capitalizeWords = true;
  bool _addNumbers = true;
  
  // PIN settings
  int _pinLength = 6;
  
  final _random = Random.secure();
  
  final List<String> _words = [
    'apple', 'banana', 'cherry', 'dragon', 'eagle', 'forest', 'garden', 'happy',
    'island', 'jungle', 'kitten', 'lemon', 'mountain', 'nature', 'ocean', 'panda',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generatePassword();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    setState(() {
      switch (_selectedType) {
        case PasswordType.random:
          _generatedPassword = _generateRandomPassword();
          break;
        case PasswordType.memorable:
          _generatedPassword = _generateMemorablePassword();
          break;
        case PasswordType.pin:
          _generatedPassword = _generatePIN();
          break;
      }
    });
  }

  String _generateRandomPassword() {
    String chars = '';
    if (_includeLowercase) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (_includeUppercase) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (_includeNumbers) chars += '0123456789';
    if (_includeSymbols) chars += '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    if (chars.isEmpty) chars = 'abcdefghijklmnopqrstuvwxyz';
    return List.generate(_length, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _generateMemorablePassword() {
    final selectedWords = <String>[];
    final availableWords = List<String>.from(_words);
    for (int i = 0; i < _wordCount; i++) {
      final word = availableWords[_random.nextInt(availableWords.length)];
      availableWords.remove(word);
      String processedWord = word;
      if (_capitalizeWords) {
        processedWord = processedWord[0].toUpperCase() + processedWord.substring(1);
      }
      selectedWords.add(processedWord);
    }
    String password = selectedWords.join(_separator);
    if (_addNumbers) password += _random.nextInt(100).toString();
    return password;
  }

  String _generatePIN() {
    return List.generate(_pinLength, (_) => _random.nextInt(10)).join();
  }

  void _generateBatchPasswords() {
    setState(() {
      _batchPasswords.clear();
      final generated = <String>{};
      while (generated.length < _batchCount) {
        String password;
        switch (_selectedType) {
          case PasswordType.random:
            password = _generateRandomPassword();
            break;
          case PasswordType.memorable:
            password = _generateMemorablePassword();
            break;
          case PasswordType.pin:
            password = _generatePIN();
            break;
        }
        generated.add(password);
      }
      _batchPasswords = generated.toList();
    });
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int strength = 0;
    if (password.length >= 8) strength += 20;
    if (password.length >= 12) strength += 20;
    if (password.length >= 16) strength += 10;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 10;
    if (RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password)) strength += 10;
    return strength.clamp(0, 100);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('已复制到剪贴板'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _savePassword(String password) async {
    final categoryController = TextEditingController();
    final noteController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: '用途/分类',
                hintText: '例如：微信、邮箱、淘宝',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final savedPassword = SavedPassword(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        password: password,
        category: categoryController.text.trim(),
        note: noteController.text.trim(),
        createdAt: DateTime.now(),
        strength: _calculatePasswordStrength(password),
      );
      
      await context.read<PasswordProvider>().addPassword(savedPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码已保存')),
        );
      }
    }
  }

  Future<void> _exportBatchToCsv() async {
    if (_batchPasswords.isEmpty) return;
    
    final buffer = StringBuffer();
    buffer.writeln('序号,密码,强度');
    for (int i = 0; i < _batchPasswords.length; i++) {
      final strength = _calculatePasswordStrength(_batchPasswords[i]);
      final strengthLabel = strength < 40 ? '弱' : strength < 70 ? '中等' : '强';
      buffer.writeln('${i + 1},"${_batchPasswords[i]}","$strengthLabel"');
    }
    
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出批量密码',
        fileName: 'passwords_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      
      if (path != null) {
        final file = File(path);
        await file.writeAsString(buffer.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportSavedPasswords() async {
    final provider = context.read<PasswordProvider>();
    final csv = provider.exportToCsv();
    
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出保存的密码',
        fileName: 'saved_passwords_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      
      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    final provider = context.read<PasswordProvider>();
    final backup = await provider.createBackup();
    
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '创建备份',
        fileName: 'password_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      
      if (path != null) {
        final file = File(path);
        await file.writeAsString(backup);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份创建成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final provider = context.read<PasswordProvider>();
        final success = await provider.restoreFromBackup(content);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? '恢复成功' : '恢复失败：备份文件损坏')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllPasswords() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有密码'),
        content: const Text('此操作不可恢复，确定要清空所有保存的密码吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await context.read<PasswordProvider>().clearAllPasswords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空所有密码')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = _calculatePasswordStrength(_generatedPassword);

    return Scaffold(
      appBar: AppBar(
        title: const Text('密码生成器'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, size: 20),
                    SizedBox(width: 12),
                    Text('创建备份'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 12),
                    Text('恢复备份'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('导出密码'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('清空所有', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'backup':
                  _createBackup();
                  break;
                case 'restore':
                  _restoreBackup();
                  break;
                case 'export':
                  _exportSavedPasswords();
                  break;
                case 'clear':
                  _clearAllPasswords();
                  break;
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '生成', icon: Icon(Icons.auto_awesome, size: 20)),
            Tab(text: '批量', icon: Icon(Icons.list, size: 20)),
            Tab(text: '已保存', icon: Icon(Icons.save, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenerateTab(cs, strength),
          _buildBatchTab(cs),
          _buildSavedTab(cs),
        ],
      ),
    );
  }

  Widget _buildGenerateTab(ColorScheme cs, int strength) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SegmentedButton<PasswordType>(
          segments: const [
            ButtonSegment(value: PasswordType.random, label: Text('随机'), icon: Icon(Icons.shuffle, size: 16)),
            ButtonSegment(value: PasswordType.memorable, label: Text('易记'), icon: Icon(Icons.psychology, size: 16)),
            ButtonSegment(value: PasswordType.pin, label: Text('PIN'), icon: Icon(Icons.pin, size: 16)),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<PasswordType> newSelection) {
            setState(() {
              _selectedType = newSelection.first;
              _generatePassword();
            });
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primaryContainer.withAlpha(150), cs.secondaryContainer.withAlpha(150)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('生成的密码', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(_generatedPassword, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: cs.onPrimaryContainer, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _copyToClipboard(_generatedPassword),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _generatePassword,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _savePassword(_generatedPassword),
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedType == PasswordType.random) _buildRandomSettings(cs),
        if (_selectedType == PasswordType.memorable) _buildMemorableSettings(cs),
        if (_selectedType == PasswordType.pin) _buildPINSettings(cs),
      ],
    );
  }

  Widget _buildRandomSettings(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('密码设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 16),
        Row(children: [Text('字符数: $_length', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))]),
        Slider(value: _length.toDouble(), min: 4, max: 32, divisions: 28, label: _length.toString(), onChanged: (value) { setState(() { _length = value.toInt(); _generatePassword(); }); }),
        CheckboxListTile(title: const Text('大写字母 (A-Z)'), value: _includeUppercase, onChanged: (value) { setState(() { _includeUppercase = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('小写字母 (a-z)'), value: _includeLowercase, onChanged: (value) { setState(() { _includeLowercase = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('数字 (0-9)'), value: _includeNumbers, onChanged: (value) { setState(() { _includeNumbers = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('符号 (!@#\$%^&*)'), value: _includeSymbols, onChanged: (value) { setState(() { _includeSymbols = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
      ],
    );
  }

  Widget _buildMemorableSettings(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('密码设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 16),
        Row(children: [Text('单词数量: $_wordCount', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))]),
        Slider(value: _wordCount.toDouble(), min: 2, max: 6, divisions: 4, label: _wordCount.toString(), onChanged: (value) { setState(() { _wordCount = value.toInt(); _generatePassword(); }); }),
        CheckboxListTile(title: const Text('首字母大写'), value: _capitalizeWords, onChanged: (value) { setState(() { _capitalizeWords = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('添加数字'), value: _addNumbers, onChanged: (value) { setState(() { _addNumbers = value ?? true; _generatePassword(); }); }, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
      ],
    );
  }

  Widget _buildPINSettings(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PIN 设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 16),
        Row(children: [Text('PIN 长度: $_pinLength', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))]),
        Slider(value: _pinLength.toDouble(), min: 4, max: 12, divisions: 8, label: _pinLength.toString(), onChanged: (value) { setState(() { _pinLength = value.toInt(); _generatePassword(); }); }),
      ],
    );
  }

  Widget _buildBatchTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('生成数量: $_batchCount', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  Slider(value: _batchCount.toDouble(), min: 5, max: 50, divisions: 9, label: _batchCount.toString(), onChanged: (value) { setState(() => _batchCount = value.toInt()); }),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _generateBatchPasswords,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('批量生成'),
              ),
            ),
            if (_batchPasswords.isNotEmpty) ...[
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _exportBatchToCsv,
                icon: const Icon(Icons.download),
                label: const Text('导出CSV'),
              ),
            ],
          ],
        ),
        if (_batchPasswords.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('已生成 ${_batchPasswords.length} 个密码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 12),
          ...List.generate(_batchPasswords.length, (index) {
            final password = _batchPasswords[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(password, style: const TextStyle(fontFamily: 'monospace')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () => _copyToClipboard(password)),
                    IconButton(icon: const Icon(Icons.save, size: 20), onPressed: () => _savePassword(password)),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSavedTab(ColorScheme cs) {
    return Consumer<PasswordProvider>(
      builder: (context, provider, child) {
        if (provider.passwords.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open, size: 64, color: cs.outline),
                const SizedBox(height: 16),
                Text('还没有保存的密码', style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.privacy_tip, color: cs.tertiary, size: 32),
                      const SizedBox(height: 12),
                      Text('隐私保护说明', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onTertiaryContainer)),
                      const SizedBox(height: 8),
                      Text('• 所有密码仅存储在本地设备\n• 不会上传或同步到任何服务器\n• 支持加密备份和恢复\n• 可随时清空所有数据', style: TextStyle(fontSize: 13, color: cs.onTertiaryContainer, height: 1.5), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final categories = provider.getAllCategories();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (categories.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: categories.map((category) {
                  final count = provider.getPasswordsByCategory(category).length;
                  return Chip(label: Text('$category ($count)'));
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            ...provider.passwords.map((password) {
              final strength = password.strength < 40 ? '弱' : password.strength < 70 ? '中等' : '强';
              final strengthColor = password.strength < 40 ? Colors.red : password.strength < 70 ? Colors.orange : Colors.green;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Icon(Icons.lock, color: cs.primary),
                  title: Text(password.category.isEmpty ? '未分类' : password.category),
                  subtitle: Text(password.password, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  trailing: Chip(label: Text(strength, style: TextStyle(color: strengthColor, fontSize: 11)), backgroundColor: strengthColor.withAlpha(50)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (password.note.isNotEmpty) ...[
                            Text('备注: ${password.note}', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                          ],
                          Text('创建时间: ${password.createdAt.toString().substring(0, 19)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _copyToClipboard(password.password),
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('复制密码'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => provider.deletePassword(password.id),
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('删除'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
