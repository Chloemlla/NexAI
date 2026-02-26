import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateTimeConverterPage extends StatefulWidget {
  const DateTimeConverterPage({super.key});

  @override
  State<DateTimeConverterPage> createState() => _DateTimeConverterPageState();
}

class _DateTimeConverterPageState extends State<DateTimeConverterPage>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedFormat = 'Timestamp';
  String? _errorMessage;
  String? _copiedLabel;

  static const _formatEntries = <_FormatEntry>[
    _FormatEntry('Timestamp', Icons.timer_outlined, '毫秒时间戳'),
    _FormatEntry('JS locale', Icons.javascript_rounded, 'JavaScript 本地格式'),
    _FormatEntry('ISO 8601', Icons.public_rounded, '国际标准格式'),
    _FormatEntry('ISO 9075', Icons.storage_rounded, 'SQL 日期格式'),
    _FormatEntry('RFC 3339', Icons.cloud_outlined, 'API 常用格式'),
    _FormatEntry('RFC 7231', Icons.http_rounded, 'HTTP 日期格式'),
    _FormatEntry('Unix timestamp', Icons.schedule_rounded, '秒级时间戳'),
    _FormatEntry('UTC format', Icons.language_rounded, 'UTC 时间'),
    _FormatEntry('Mongo ObjectID', Icons.dns_rounded, 'MongoDB ID 前缀'),
    _FormatEntry('Excel date/time', Icons.table_chart_rounded, 'Excel 序列号'),
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
        return '${DateFormat('EEE, dd MMM yyyy HH:mm:ss').format(date.toUtc())} GMT';
      case 'Unix timestamp':
        return (date.millisecondsSinceEpoch ~/ 1000).toString();
      case 'UTC format':
        return date.toUtc().toString();
      case 'Mongo ObjectID':
        return '${(date.millisecondsSinceEpoch ~/ 1000).toRadixString(16).padLeft(8, '0')}0000000000000000';
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
        _errorMessage = '无法解析该格式';
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

  void _setNow() {
    setState(() {
      _selectedDate = DateTime.now();
      _errorMessage = null;
      _updateInputFromDate();
    });
  }

  void _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate ?? now),
    );
    if (!mounted) return;
    setState(() {
      _selectedDate = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? 0, time?.minute ?? 0,
      );
      _errorMessage = null;
      _updateInputFromDate();
    });
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _copiedLabel = label);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copiedLabel = null);
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('已复制 $label'),
        ]),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 600;
    final hPad = isNarrow ? 16.0 : mq.size.width * 0.06;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ──
          SliverAppBar(
            pinned: true,
            expandedHeight: isNarrow ? 170 : 190,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Text(
                '日期时间转换器',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withAlpha(130),
                      cs.tertiaryContainer.withAlpha(60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(Icons.access_time_filled_rounded, size: 32, color: cs.onPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDate != null)
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate!),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Quick actions ──
                Row(children: [
                  Expanded(
                    child: _QuickAction(
                      cs: cs,
                      icon: Icons.today_rounded,
                      label: '当前时间',
                      color: cs.primaryContainer,
                      iconColor: cs.onPrimaryContainer,
                      onTap: _setNow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      cs: cs,
                      icon: Icons.calendar_month_rounded,
                      label: '选择日期',
                      color: cs.secondaryContainer,
                      iconColor: cs.onSecondaryContainer,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      cs: cs,
                      icon: Icons.content_paste_rounded,
                      label: '从剪贴板',
                      color: cs.tertiaryContainer,
                      iconColor: cs.onTertiaryContainer,
                      onTap: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          _inputController.text = data.text!;
                          _onInputChanged(data.text!);
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Input card ──
                _buildInputCard(cs, tt, isNarrow),
                const SizedBox(height: 20),

                // ── Results section ──
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withAlpha(150),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Icon(Icons.transform_rounded, size: 18, color: cs.primary)),
                  ),
                  const SizedBox(width: 12),
                  Text('转换结果', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                  const Spacer(),
                  Text(
                    '${_formatEntries.length} 种格式',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ]),
                const SizedBox(height: 12),

                if (_selectedDate != null)
                  ...List.generate(_formatEntries.length, (i) {
                    final entry = _formatEntries[i];
                    final value = _formatDate(_selectedDate!, entry.name);
                    final isCopied = _copiedLabel == entry.name;
                    return _buildResultTile(cs, entry, value, isNarrow, isCopied);
                  }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme cs, TextTheme tt, bool isNarrow) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withAlpha(150),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(Icons.edit_calendar_rounded, size: 18, color: cs.secondary)),
              ),
              const SizedBox(width: 12),
              Text('输入', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            ]),
            const SizedBox(height: 16),
            // Format selector
            DropdownButtonFormField<String>(
              value: _selectedFormat,
              decoration: InputDecoration(
                labelText: '输入格式',
                prefixIcon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _formatEntries.map((e) => DropdownMenuItem(
                value: e.name,
                child: Row(children: [
                  Icon(e.icon, size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(e.name),
                ]),
              )).toList(),
              onChanged: _onFormatChanged,
            ),
            const SizedBox(height: 12),
            // Input field
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                labelText: '日期时间值',
                hintText: '输入或粘贴日期时间...',
                errorText: _errorMessage,
                prefixIcon: const Icon(Icons.input_rounded, size: 20),
                suffixIcon: _inputController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _inputController.clear();
                          _onInputChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              onChanged: _onInputChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(
    ColorScheme cs,
    _FormatEntry entry,
    String value,
    bool isNarrow,
    bool isCopied,
  ) {
    if (isNarrow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: isCopied ? cs.primaryContainer.withAlpha(80) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _copyToClipboard(value, entry.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Icon(
                        isCopied ? Icons.check_rounded : entry.icon,
                        size: 16,
                        color: isCopied ? cs.primary : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            entry.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.desc,
                            style: TextStyle(fontSize: 10, color: cs.outline),
                          ),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      key: ValueKey(isCopied),
                      size: 18,
                      color: isCopied ? cs.primary : cs.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Wide layout ──
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCopied ? cs.primaryContainer.withAlpha(60) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _copyToClipboard(value, entry.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Icon(
                      isCopied ? Icons.check_rounded : entry.icon,
                      size: 16,
                      color: isCopied ? cs.primary : cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        entry.desc,
                        style: TextStyle(fontSize: 10, color: cs.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    key: ValueKey(isCopied),
                    size: 18,
                    color: isCopied ? cs.primary : cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatEntry {
  final String name;
  final IconData icon;
  final String desc;
  const _FormatEntry(this.name, this.icon, this.desc);
}

class _QuickAction extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.cs,
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(150),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(icon, size: 18, color: iconColor)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ),
    );
  }
}
