import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateTimeConverterPage extends StatefulWidget {
  const DateTimeConverterPage({super.key});

  @override
  State<DateTimeConverterPage> createState() => _DateTimeConverterPageState();
}

class _DateTimeConverterPageState extends State<DateTimeConverterPage> {
  final _inputController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedFormat = 'Timestamp';
  String? _errorMessage;

  final List<DateFormat> _formats = [
    DateFormat('Timestamp'),
    DateFormat('JS locale'),
    DateFormat('ISO 8601'),
    DateFormat('ISO 9075'),
    DateFormat('RFC 3339'),
    DateFormat('RFC 7231'),
    DateFormat('Unix timestamp'),
    DateFormat('UTC format'),
    DateFormat('Mongo ObjectID'),
    DateFormat('Excel date/time'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateInputFromDate();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _updateInputFromDate() {
    if (_selectedDate == null) return;
    _inputController.text = _formatDate(_selectedDate!, _selectedFormat);
  }

  String _formatDate(DateTime date, String format) {
    switch (format) {
      case 'Timestamp':
        return date.millisecondsSinceEpoch.toString();
      case 'JS locale':
        return date.toString();
      case 'ISO 8601':
        return date.toIso8601String();
      case 'ISO 9075':
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
      case 'RFC 3339':
        return date.toIso8601String();
      case 'RFC 7231':
        return DateFormat('EEE, dd MMM yyyy HH:mm:ss').format(date.toUtc()) + ' GMT';
      case 'Unix timestamp':
        return (date.millisecondsSinceEpoch ~/ 1000).toString();
      case 'UTC format':
        return date.toUtc().toString();
      case 'Mongo ObjectID':
        return (date.millisecondsSinceEpoch ~/ 1000).toRadixString(16).padLeft(8, '0') + '0000000000000000';
      case 'Excel date/time':
        final excelEpoch = DateTime(1899, 12, 30);
        final diff = date.difference(excelEpoch);
        return (diff.inMilliseconds / 86400000).toStringAsFixed(5);
      default:
        return date.toString();
    }
  }

  DateTime? _parseDate(String input, String format) {
    try {
      switch (format) {
        case 'Timestamp':
          final ms = int.tryParse(input);
          if (ms == null) return null;
          return DateTime.fromMillisecondsSinceEpoch(ms);
        case 'Unix timestamp':
          final sec = int.tryParse(input);
          if (sec == null) return null;
          return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
        case 'Mongo ObjectID':
          if (input.length < 8) return null;
          final timestamp = int.tryParse(input.substring(0, 8), radix: 16);
          if (timestamp == null) return null;
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        case 'Excel date/time':
          final days = double.tryParse(input);
          if (days == null) return null;
          final excelEpoch = DateTime(1899, 12, 30);
          return excelEpoch.add(Duration(milliseconds: (days * 86400000).round()));
        default:
          return DateTime.tryParse(input);
      }
    } catch (_) {
      return null;
    }
  }

  void _onInputChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _selectedDate = DateTime.now();
        _errorMessage = null;
      });
      return;
    }

    final parsed = _parseDate(value, _selectedFormat);
    setState(() {
      if (parsed != null) {
        _selectedDate = parsed;
        _errorMessage = null;
      } else {
        _errorMessage = 'Invalid date format';
      }
    });
  }

  void _onFormatChanged(String? format) {
    if (format == null) return;
    setState(() {
      _selectedFormat = format;
      _updateInputFromDate();
      _errorMessage = null;
    });
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日期时间转换器'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Input section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    labelText: '输入日期时间',
                    hintText: '输入日期时间字符串...',
                    errorText: _errorMessage,
                    prefixIcon: const Icon(Icons.edit_calendar),
                    suffixIcon: _inputController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _inputController.clear();
                              _onInputChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onInputChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedFormat,
                  decoration: InputDecoration(
                    labelText: '输入格式',
                    prefixIcon: const Icon(Icons.format_list_bulleted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    'Timestamp',
                    'JS locale',
                    'ISO 8601',
                    'ISO 9075',
                    'RFC 3339',
                    'RFC 7231',
                    'Unix timestamp',
                    'UTC format',
                    'Mongo ObjectID',
                    'Excel date/time',
                  ].map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(format),
                    );
                  }).toList(),
                  onChanged: _onFormatChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Divider(color: cs.outlineVariant),
          const SizedBox(height: 24),

          // Output section
          Text(
            '转换结果',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedDate != null) ...[
            _buildOutputField(
              context,
              'Timestamp',
              _formatDate(_selectedDate!, 'Timestamp'),
            ),
            _buildOutputField(
              context,
              'JS locale date string',
              _formatDate(_selectedDate!, 'JS locale'),
            ),
            _buildOutputField(
              context,
              'ISO 8601',
              _formatDate(_selectedDate!, 'ISO 8601'),
            ),
            _buildOutputField(
              context,
              'ISO 9075',
              _formatDate(_selectedDate!, 'ISO 9075'),
            ),
            _buildOutputField(
              context,
              'RFC 3339',
              _formatDate(_selectedDate!, 'RFC 3339'),
            ),
            _buildOutputField(
              context,
              'RFC 7231',
              _formatDate(_selectedDate!, 'RFC 7231'),
            ),
            _buildOutputField(
              context,
              'Unix timestamp',
              _formatDate(_selectedDate!, 'Unix timestamp'),
            ),
            _buildOutputField(
              context,
              'UTC format',
              _formatDate(_selectedDate!, 'UTC format'),
            ),
            _buildOutputField(
              context,
              'Mongo ObjectID',
              _formatDate(_selectedDate!, 'Mongo ObjectID'),
            ),
            _buildOutputField(
              context,
              'Excel date/time',
              _formatDate(_selectedDate!, 'Excel date/time'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutputField(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value),
              readOnly: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceContainerHighest.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToClipboard(value),
                  tooltip: '复制',
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
