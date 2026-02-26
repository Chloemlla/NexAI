import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/password_provider.dart';
import '../models/saved_password.dart';

enum PasswordType {
  random,
  memorable,
  pin,
  custom,
}

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
  
  // Word list for memorable passwords
  final List<String> _words = [
    'apple', 'banana', 'cherry', 'dragon', 'eagle', 'forest', 'garden', 'happy',
    'island', 'jungle', 'kitten', 'lemon', 'mountain', 'nature', 'ocean', 'panda',
    'queen', 'river', 'sunset', 'tiger', 'umbrella', 'valley', 'water', 'yellow',
    'zebra', 'cloud', 'dream', 'flower', 'guitar', 'heart', 'light', 'magic',
    'music', 'peace', 'rainbow', 'smile', 'star', 'thunder', 'wonder', 'crystal',
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
        case PasswordType.custom:
          _generatedPassword = _generateRandomPassword();
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
    
    if (_addNumbers) {
      password += _random.nextInt(100).toString();
    }
    
    return password;
  }

  String _generatePIN() {
    return List.generate(_pinLength, (_) => _random.nextInt(10)).join();
  }

  void _copyToClipboard() {
    if (_generatedPassword.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('密码已复制到剪贴板'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _calculatePasswordStrength() {
    if (_generatedPassword.isEmpty) return 0;
    
    int strength = 0;
    
    // Length
    if (_generatedPassword.length >= 8) strength += 20;
    if (_generatedPassword.length >= 12) strength += 20;
    if (_generatedPassword.length >= 16) strength += 10;
    
    // Character variety
    if (RegExp(r'[a-z]').hasMatch(_generatedPassword)) strength += 15;
    if (RegExp(r'[A-Z]').hasMatch(_generatedPassword)) strength += 15;
    if (RegExp(r'[0-9]').hasMatch(_generatedPassword)) strength += 10;
    if (RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(_generatedPassword)) strength += 10;
    
    return strength.clamp(0, 100);
  }

  Color _getStrengthColor(int strength) {
    if (strength < 40) return Colors.red;
    if (strength < 70) return Colors.orange;
    return Colors.green;
  }

  String _getStrengthLabel(int strength) {
    if (strength < 40) return '弱';
    if (strength < 70) return '中等';
    return '强';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = _calculatePasswordStrength();

    return Scaffold(
      appBar: AppBar(
        title: const Text('密码生成器'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Password type selector
          SegmentedButton<PasswordType>(
            segments: const [
              ButtonSegment(
                value: PasswordType.random,
                label: Text('随机'),
                icon: Icon(Icons.shuffle, size: 16),
              ),
              ButtonSegment(
                value: PasswordType.memorable,
                label: Text('易记'),
                icon: Icon(Icons.psychology, size: 16),
              ),
              ButtonSegment(
                value: PasswordType.pin,
                label: Text('PIN'),
                icon: Icon(Icons.pin, size: 16),
              ),
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

          // Generated password display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer.withAlpha(150),
                  cs.secondaryContainer.withAlpha(150),
                ],
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
                    Text(
                      '生成的密码',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                SelectableText(
                  _generatedPassword,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: cs.onPrimaryContainer,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Strength indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '密码强度',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer.withAlpha(200),
                          ),
                        ),
                        Text(
                          _getStrengthLabel(strength),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStrengthColor(strength),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength / 100,
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(_getStrengthColor(strength)),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('复制密码'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _generatePassword,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Settings based on type
          if (_selectedType == PasswordType.random) ..._buildRandomSettings(cs),
          if (_selectedType == PasswordType.memorable) ..._buildMemorableSettings(cs),
          if (_selectedType == PasswordType.pin) ..._buildPINSettings(cs),
        ],
      ),
    );
  }

  List<Widget> _buildRandomSettings(ColorScheme cs) {
    return [
      Text(
        '密码设置',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 16),
      
      // Length slider
      Row(
        children: [
          Text(
            '字符数: $_length',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      Slider(
        value: _length.toDouble(),
        min: 4,
        max: 32,
        divisions: 28,
        label: _length.toString(),
        onChanged: (value) {
          setState(() {
            _length = value.toInt();
            _generatePassword();
          });
        },
      ),
      const SizedBox(height: 8),
      
      // Character type checkboxes
      CheckboxListTile(
        title: const Text('大写字母 (A-Z)'),
        value: _includeUppercase,
        onChanged: (value) {
          setState(() {
            _includeUppercase = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
      CheckboxListTile(
        title: const Text('小写字母 (a-z)'),
        value: _includeLowercase,
        onChanged: (value) {
          setState(() {
            _includeLowercase = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
      CheckboxListTile(
        title: const Text('数字 (0-9)'),
        value: _includeNumbers,
        onChanged: (value) {
          setState(() {
            _includeNumbers = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
      CheckboxListTile(
        title: const Text('符号 (!@#\$%^&*)'),
        value: _includeSymbols,
        onChanged: (value) {
          setState(() {
            _includeSymbols = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ];
  }

  List<Widget> _buildMemorableSettings(ColorScheme cs) {
    return [
      Text(
        '密码设置',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 16),
      
      // Word count
      Row(
        children: [
          Text(
            '单词数量: $_wordCount',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      Slider(
        value: _wordCount.toDouble(),
        min: 2,
        max: 6,
        divisions: 4,
        label: _wordCount.toString(),
        onChanged: (value) {
          setState(() {
            _wordCount = value.toInt();
            _generatePassword();
          });
        },
      ),
      const SizedBox(height: 8),
      
      // Separator
      DropdownButtonFormField<String>(
        value: _separator,
        decoration: InputDecoration(
          labelText: '分隔符',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: const [
          DropdownMenuItem(value: '-', child: Text('连字符 (-)')),
          DropdownMenuItem(value: '_', child: Text('下划线 (_)')),
          DropdownMenuItem(value: '.', child: Text('点号 (.)')),
          DropdownMenuItem(value: '', child: Text('无分隔符')),
        ],
        onChanged: (value) {
          setState(() {
            _separator = value ?? '-';
            _generatePassword();
          });
        },
      ),
      const SizedBox(height: 16),
      
      CheckboxListTile(
        title: const Text('首字母大写'),
        value: _capitalizeWords,
        onChanged: (value) {
          setState(() {
            _capitalizeWords = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
      CheckboxListTile(
        title: const Text('添加数字'),
        value: _addNumbers,
        onChanged: (value) {
          setState(() {
            _addNumbers = value ?? true;
            _generatePassword();
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ];
  }

  List<Widget> _buildPINSettings(ColorScheme cs) {
    return [
      Text(
        'PIN 设置',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 16),
      
      Row(
        children: [
          Text(
            'PIN 长度: $_pinLength',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      Slider(
        value: _pinLength.toDouble(),
        min: 4,
        max: 12,
        divisions: 8,
        label: _pinLength.toString(),
        onChanged: (value) {
          setState(() {
            _pinLength = value.toInt();
            _generatePassword();
          });
        },
      ),
    ];
  }
}
