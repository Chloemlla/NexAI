import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/password_provider.dart';
import '../models/saved_password.dart';

enum PasswordType { random, memorable, pin }

class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  State<PasswordGeneratorPage> createState() => _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState extends State<PasswordGeneratorPage>
    with SingleTickerProviderStateMixin {
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
    'apple',
    'banana',
    'cherry',
    'dragon',
    'eagle',
    'forest',
    'garden',
    'happy',
    'island',
    'jungle',
    'kitten',
    'lemon',
    'mountain',
    'nature',
    'ocean',
    'panda',
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

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      if (sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<String> _getSafeSavePath(String fileName) async {
    if (Platform.isAndroid) {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw '需要存储权限才能保存文件';
      }
      final dir = Directory('/storage/emulated/0/Download/NexAI');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return p.join(dir.path, fileName);
    } else {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: fileName,
      );
      if (path == null) throw '取消保存';
      return path;
    }
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
    return List.generate(_length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  String _generateMemorablePassword() {
    final selectedWords = <String>[];
    final availableWords = List<String>.from(_words);
    for (int i = 0; i < _wordCount; i++) {
      final word = availableWords[_random.nextInt(availableWords.length)];
      availableWords.remove(word);
      String processedWord = word;
      if (_capitalizeWords) {
        processedWord =
            processedWord[0].toUpperCase() + processedWord.substring(1);
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
    if (RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password))
      strength += 10;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.save_rounded, size: 24),
            SizedBox(width: 12),
            Text('保存密码'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: '用途/分类',
                hintText: '例如：微信、邮箱、淘宝',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.category_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: '备注（可选）',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note_rounded),
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
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
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
          const SnackBar(
              content: Text('密码已保存'), behavior: SnackBarBehavior.floating),
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
      final strengthLabel = strength < 40
          ? '弱'
          : strength < 70
              ? '中等'
              : '强';
      buffer.writeln('${i + 1},"${_batchPasswords[i]}","$strengthLabel"');
    }

    try {
      final fileName = 'passwords_${DateTime.now().millisecondsSinceEpoch}.csv';
      final path = await _getSafeSavePath(fileName);

      final file = File(path);
      await file.writeAsString(buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功: $path'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && e != '取消保存') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('导出失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _exportSavedPasswords() async {
    final provider = context.read<PasswordProvider>();
    final csv = provider.exportToCsv();

    try {
      final fileName =
          'saved_passwords_${DateTime.now().millisecondsSinceEpoch}.csv';
      final path = await _getSafeSavePath(fileName);

      final file = File(path);
      await file.writeAsString(csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功: $path'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && e != '取消保存') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('导出失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    final provider = context.read<PasswordProvider>();
    final backup = await provider.createBackup();

    try {
      final fileName =
          'password_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final path = await _getSafeSavePath(fileName);

      final file = File(path);
      await file.writeAsString(backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份创建成功: $path'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && e != '取消保存') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('备份失败: $e'), behavior: SnackBarBehavior.floating),
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
            SnackBar(content: Text(success ? '恢复成功' : '恢复失败：备份文件损坏'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复失败: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _clearAllPasswords() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('清空所有密码'),
          ],
        ),
        content: const Text('此操作不可恢复，确定要清空所有保存的密码吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await context.read<PasswordProvider>().clearAllPasswords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空所有密码'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildStrengthMeter(int strength, ColorScheme cs) {
    Color strengthColor;
    String strengthLabel;
    if (strength < 40) {
      strengthColor = Colors.redAccent;
      strengthLabel = '弱 (Weak)';
    } else if (strength < 70) {
      strengthColor = Colors.orangeAccent;
      strengthLabel = '中等 (Fair)';
    } else if (strength < 90) {
      strengthColor = Colors.lightGreen;
      strengthLabel = '强 (Strong)';
    } else {
      strengthColor = Colors.green;
      strengthLabel = '极强 (Excellent)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('密码强度', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Text(strengthLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: strengthColor)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: strength / 100,
            backgroundColor: cs.surfaceContainerHighest,
            color: strengthColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = _calculatePasswordStrength(_generatedPassword);

    return Scaffold(
      appBar: AppBar(
        title: const Text('密码生成器', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('创建备份'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('恢复备份'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('导出密码'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 20, color: Colors.red),
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
          labelPadding: const EdgeInsets.symmetric(vertical: 8),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '生成', icon: Icon(Icons.auto_awesome_rounded, size: 22)),
            Tab(text: '批量', icon: Icon(Icons.format_list_bulleted_rounded, size: 22)),
            Tab(text: '已保存', icon: Icon(Icons.bookmark_rounded, size: 22)),
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
      padding: const EdgeInsets.all(20),
      children: [
        // Top Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primaryContainer, cs.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, color: cs.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('生成的密码', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
                  },
                  child: SelectableText(
                    _generatedPassword,
                    key: ValueKey<String>(_generatedPassword),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.w700, 
                      fontFamily: 'monospace', 
                      color: cs.onPrimaryContainer, 
                      letterSpacing: 1.8
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _buildStrengthMeter(strength, cs),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _copyToClipboard(_generatedPassword),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: _generatePassword,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () => _savePassword(_generatedPassword),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.save_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        
        // Settings segment
        SegmentedButton<PasswordType>(
          segments: const [
            ButtonSegment(value: PasswordType.random, label: Text('随机'), icon: Icon(Icons.shuffle_rounded, size: 18)),
            ButtonSegment(value: PasswordType.memorable, label: Text('易记'), icon: Icon(Icons.psychology_rounded, size: 18)),
            ButtonSegment(value: PasswordType.pin, label: Text('PIN'), icon: Icon(Icons.pin_rounded, size: 18)),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<PasswordType> newSelection) {
            setState(() {
              _selectedType = newSelection.first;
              _generatePassword();
            });
          },
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 20),
        
        // Settings Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outlineVariant.withAlpha(100)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildSettingsContent(cs),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(ColorScheme cs) {
    if (_selectedType == PasswordType.random) return _buildRandomSettings(cs);
    if (_selectedType == PasswordType.memorable) return _buildMemorableSettings(cs);
    if (_selectedType == PasswordType.pin) return _buildPINSettings(cs);
    return const SizedBox.shrink();
  }

  Widget _buildRandomSettings(ColorScheme cs) {
    return Column(
      key: const ValueKey('random'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 12),
          child: Text('密码设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        ),
        _buildSliderSetting(
          title: '密码长度',
          value: _length.toDouble(),
          min: 4,
          max: 32,
          divisions: 28,
          label: '$_length',
          cs: cs,
          onChanged: (val) {
            setState(() {
              _length = val.toInt();
              _generatePassword();
            });
          },
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('大写字母 (A-Z)'),
          value: _includeUppercase,
          onChanged: (value) { setState(() { _includeUppercase = value; _generatePassword(); }); },
          secondary: Icon(Icons.font_download_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        SwitchListTile(
          title: const Text('小写字母 (a-z)'),
          value: _includeLowercase,
          onChanged: (value) { setState(() { _includeLowercase = value; _generatePassword(); }); },
          secondary: Icon(Icons.text_fields_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        SwitchListTile(
          title: const Text('数字 (0-9)'),
          value: _includeNumbers,
          onChanged: (value) { setState(() { _includeNumbers = value; _generatePassword(); }); },
          secondary: Icon(Icons.numbers_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        SwitchListTile(
          title: const Text('特殊符号 (!@#\$%)'),
          value: _includeSymbols,
          onChanged: (value) { setState(() { _includeSymbols = value; _generatePassword(); }); },
          secondary: Icon(Icons.emoji_symbols_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ],
    );
  }

  Widget _buildMemorableSettings(ColorScheme cs) {
    return Column(
      key: const ValueKey('memorable'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 12),
          child: Text('易记密码设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        ),
        _buildSliderSetting(
          title: '单词数量',
          value: _wordCount.toDouble(),
          min: 2,
          max: 6,
          divisions: 4,
          label: '$_wordCount',
          cs: cs,
          onChanged: (val) {
            setState(() {
              _wordCount = val.toInt();
              _generatePassword();
            });
          },
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('首字母大写'),
          value: _capitalizeWords,
          onChanged: (value) { setState(() { _capitalizeWords = value; _generatePassword(); }); },
          secondary: Icon(Icons.title_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        SwitchListTile(
          title: const Text('末尾添加数字'),
          value: _addNumbers,
          onChanged: (value) { setState(() { _addNumbers = value; _generatePassword(); }); },
          secondary: Icon(Icons.looks_one_rounded, color: cs.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ],
    );
  }

  Widget _buildPINSettings(ColorScheme cs) {
    return Column(
      key: const ValueKey('pin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 12),
          child: Text('PIN 码设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        ),
        _buildSliderSetting(
          title: 'PIN 长度',
          value: _pinLength.toDouble(),
          min: 4,
          max: 12,
          divisions: 8,
          label: '$_pinLength',
          cs: cs,
          onChanged: (val) {
            setState(() {
              _pinLength = val.toInt();
              _generatePassword();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ColorScheme cs,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(label, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: cs.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBatchTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outlineVariant.withAlpha(100)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderSetting(
                  title: '生成数量',
                  value: _batchCount.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$_batchCount',
                  cs: cs,
                  onChanged: (val) => setState(() => _batchCount = val.toInt()),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _generateBatchPasswords,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('批量生成'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (_batchPasswords.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: FilledButton.tonalIcon(
                          onPressed: _exportBatchToCsv,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('导出'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_batchPasswords.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('已生成 ${_batchPasswords.length} 个密码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          const SizedBox(height: 12),
          ...List.generate(_batchPasswords.length, (index) {
            final password = _batchPasswords[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant.withAlpha(50)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text('${index + 1}', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                title: Text(password, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: 20, color: cs.primary),
                      onPressed: () => _copyToClipboard(password),
                      tooltip: '复制',
                    ),
                    IconButton(
                      icon: Icon(Icons.save_rounded, size: 20, color: cs.secondary),
                      onPressed: () => _savePassword(password),
                      tooltip: '保存',
                    ),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_person_rounded, size: 80, color: cs.primary.withAlpha(150)),
                  ),
                  const SizedBox(height: 24),
                  Text('还没有保存的密码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Text('在生成或批量生成页面保存密码\n它们将安全地存储在这里', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.tertiary.withAlpha(50)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.privacy_tip_rounded, color: cs.tertiary, size: 36),
                        const SizedBox(height: 16),
                        Text('隐私保护承诺', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onTertiaryContainer)),
                        const SizedBox(height: 12),
                        Text('• 所有密码仅存储在本地设备\n• 不会上传或同步到任何服务器\n• 支持导出和加密备份\n• 您的数据完全由您掌控', style: TextStyle(fontSize: 13, color: cs.onTertiaryContainer, height: 1.6), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final categories = provider.getAllCategories();
        return CustomScrollView(
          slivers: [
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: categories.map((category) {
                        final count = provider.getPasswordsByCategory(category).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('$category ($count)'),
                            backgroundColor: cs.secondaryContainer,
                            labelStyle: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w500),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final password = provider.passwords[index];
                    final strength = password.strength < 40 ? '弱' : password.strength < 70 ? '中等' : '强';
                    final strengthColor = password.strength < 40 ? Colors.red : password.strength < 70 ? Colors.orange : Colors.green;
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Icon(Icons.lock_rounded, color: cs.primary, size: 20),
                          ),
                          title: Text(
                            password.category.isEmpty ? '未分类' : password.category,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              password.password,
                              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: strengthColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: strengthColor.withAlpha(50)),
                            ),
                            child: Text(strength, style: TextStyle(color: strengthColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withAlpha(50),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (password.note.isNotEmpty) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.notes_rounded, size: 18, color: cs.onSurfaceVariant),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(password.note, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4))),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 18, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Text('创建于: ${password.createdAt.toString().substring(0, 19)}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.tonalIcon(
                                          onPressed: () => _copyToClipboard(password.password),
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          label: const Text('复制密码'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton.icon(
                                        onPressed: () => provider.deletePassword(password.id),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        label: const Text('删除'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red.withAlpha(20),
                                          foregroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: provider.passwords.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
