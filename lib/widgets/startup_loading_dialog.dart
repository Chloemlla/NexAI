import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Startup loading dialog that shows initialization progress with typewriter effect
class StartupLoadingDialog extends StatefulWidget {
  final Stream<String> logStream;

  const StartupLoadingDialog({
    super.key,
    required this.logStream,
  });

  @override
  State<StartupLoadingDialog> createState() => _StartupLoadingDialogState();
}

class _StartupLoadingDialogState extends State<StartupLoadingDialog> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
        });
        // Auto-scroll to bottom with animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Try to get settings, but use defaults if not available
    final settings = context.watch<SettingsProvider?>();
    final fontFamily = settings?.fontFamily ?? 'vivoSans';
    final fontSize = settings?.fontSize ?? 14.0;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NexAI 启动中',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontFamily: fontFamily,
                        ),
                      ),
                      Text(
                        '正在初始化应用组件...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Log area with typewriter effect
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return _TypewriterText(
                      text: _logs[index],
                      delay: Duration(milliseconds: index * 50),
                      fontFamily: fontFamily,
                      fontSize: fontSize,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Loading indicator
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_logs.length} 个任务已完成',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Typewriter effect text widget
class _TypewriterText extends StatefulWidget {
  final String text;
  final Duration delay;
  final String fontFamily;
  final double fontSize;

  const _TypewriterText({
    required this.text,
    required this.delay,
    required this.fontFamily,
    required this.fontSize,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.text.length * 20 + 200),
      vsync: this,
    );

    _characterCount = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final displayText = widget.text.substring(
          0,
          _characterCount.value.clamp(0, widget.text.length),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: _characterCount.value == widget.text.length
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontFamily: widget.fontFamily,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              if (_characterCount.value < widget.text.length)
                Container(
                  width: 2,
                  height: 16,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
