import 'dart:async';
import 'dart:io' show File, Directory;
import 'package:flutter/material.dart';
import '../theme/lumen_tokens.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path/path.dart' as p;
import '../utils/file_access_helper.dart';
import '../widgets/tool_page_style.dart';
import '../widgets/lumen/lumen.dart';

enum AudioFormat { mp3, aac, flac, wav, ogg }

extension AudioFormatExt on AudioFormat {
  String get extension {
    switch (this) {
      case AudioFormat.mp3:
        return 'mp3';
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.flac:
        return 'flac';
      case AudioFormat.wav:
        return 'wav';
      case AudioFormat.ogg:
        return 'ogg';
    }
  }

  String get label {
    switch (this) {
      case AudioFormat.mp3:
        return 'MP3';
      case AudioFormat.aac:
        return 'AAC';
      case AudioFormat.flac:
        return 'FLAC (无损)';
      case AudioFormat.wav:
        return 'WAV (无损)';
      case AudioFormat.ogg:
        return 'OGG';
    }
  }

  String get codecArgs {
    switch (this) {
      case AudioFormat.mp3:
        return '-c:a libmp3lame -q:a 2';
      case AudioFormat.aac:
        return '-c:a aac -b:a 192k';
      case AudioFormat.flac:
        return '-c:a flac';
      case AudioFormat.wav:
        return '-c:a pcm_s16le';
      case AudioFormat.ogg:
        return '-c:a libvorbis -q:a 5';
    }
  }
}

enum TaskStatus { pending, running, success, failed, cancelled }

class VideoToAudioTask {
  final String inputPath;
  final String fileName;
  String outputPath;
  TaskStatus status;

  /// 进度用 ValueNotifier 承载：FFmpeg 每秒推送多次统计，
  /// 只重建进度条而不是整页任务列表。
  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  String? errorMessage;
  int? sessionId;
  String? durationStr;
  int durationMs;

  VideoToAudioTask({
    required this.inputPath,
    required this.fileName,
    required this.outputPath,
    this.status = TaskStatus.pending,
    this.errorMessage,
    this.sessionId,
    this.durationStr,
    this.durationMs = 0,
  });

  void disposeProgress() => progress.dispose();
}

class VideoToAudioPage extends StatefulWidget {
  const VideoToAudioPage({super.key});

  @override
  State<VideoToAudioPage> createState() => _VideoToAudioPageState();
}

class _VideoToAudioPageState extends State<VideoToAudioPage> {
  final List<VideoToAudioTask> _tasks = [];
  final ValueNotifier<double> _overallProgress = ValueNotifier<double>(0);
  AudioFormat _selectedFormat = AudioFormat.mp3;
  bool _isProcessing = false;
  bool _probingDurations = false;
  int _completedCount = 0;
  int _failedCount = 0;

  @override
  void dispose() {
    // Cancel any running sessions
    for (final task in _tasks) {
      if (task.status == TaskStatus.running && task.sessionId != null) {
        FFmpegKit.cancel(task.sessionId!);
      }
      task.disposeProgress();
    }
    _overallProgress.dispose();
    super.dispose();
  }

  Future<void> _pickVideos() async {
    try {
      final videoPaths = await FileAccessHelper.pickVideos();
      if (videoPaths.isEmpty) return;

      final outputDir = await _getOutputDirectory();

      final newTasks = <VideoToAudioTask>[];
      for (final videoPath in videoPaths) {
        final fileName = p.basename(videoPath);
        final baseName = p.basenameWithoutExtension(fileName);
        final outputPath = p.join(
          outputDir,
          '$baseName.${_selectedFormat.extension}',
        );
        newTasks.add(
          VideoToAudioTask(
            inputPath: videoPath,
            fileName: fileName,
            outputPath: outputPath,
          ),
        );
      }

      if (!mounted) return;
      // 先让任务出现在列表里，再并行探测时长：选完文件不再长时间无反馈。
      setState(() {
        _tasks.addAll(newTasks);
        _probingDurations = true;
      });
      _syncOverallProgress();

      await Future.wait(newTasks.map(_probeDuration));

      if (!mounted) return;
      setState(() => _probingDurations = false);
    } catch (e) {
      if (mounted) {
        setState(() => _probingDurations = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  Future<void> _probeDuration(VideoToAudioTask task) async {
    try {
      final session = await FFprobeKit.getMediaInformation(task.inputPath);
      final durationStr = session.getMediaInformation()?.getDuration();
      if (durationStr == null) return;
      final parsed = double.tryParse(durationStr);
      if (parsed == null || parsed <= 0) return;
      task.durationMs = (parsed * 1000).toInt();
      task.durationStr = _formatDuration(
        Duration(milliseconds: task.durationMs),
      );
    } catch (_) {}
  }

  Future<String> _getOutputDirectory() async {
    final dir = await getTemporaryDirectory();
    final outputDir = Directory(p.join(dir.path, 'video_to_audio'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir.path;
  }

  Future<void> _startBatchConversion() async {
    if (_tasks.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _completedCount = 0;
      _failedCount = 0;
      for (final task in _tasks) {
        if (task.status != TaskStatus.success) {
          task.status = TaskStatus.pending;
          task.progress.value = 0.0;
          task.errorMessage = null;
        }
      }
    });
    _syncOverallProgress();

    for (final task in List.of(_tasks)) {
      if (!mounted || !_isProcessing) break;
      if (task.status == TaskStatus.success) continue;

      await _convertSingle(task);
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      if (_completedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _failedCount == 0
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text('完成 $_completedCount 个，失败 $_failedCount 个'),
              ],
            ),
            backgroundColor: _failedCount == 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }

  Future<void> _convertSingle(VideoToAudioTask task) async {
    setState(() => task.status = TaskStatus.running);

    // Ensure output file doesn't conflict
    final outputFile = File(task.outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final command =
        '-i ${_quotePath(task.inputPath)} -vn ${_selectedFormat.codecArgs} -y ${_quotePath(task.outputPath)}';

    // 完成信号必须在启动会话前创建：回调可能在 executeAsync 返回前就到达。
    final completion = Completer<void>();

    try {
      final session = await FFmpegKit.executeAsync(
        command,
        (Session session) async {
          // Completion callback
          final returnCode = await session.getReturnCode();
          if (!completion.isCompleted) completion.complete();
          if (!mounted) return;
          setState(() {
            if (ReturnCode.isSuccess(returnCode)) {
              task.status = TaskStatus.success;
              task.progress.value = 1.0;
              _completedCount++;
            } else if (ReturnCode.isCancel(returnCode)) {
              task.status = TaskStatus.cancelled;
            } else {
              task.status = TaskStatus.failed;
              task.errorMessage = '转换失败 (code: ${returnCode?.getValue()})';
              _failedCount++;
            }
          });
          _syncOverallProgress();
        },
        (Log log) {
          // Log callback - can be used for debugging
        },
        (Statistics statistics) {
          // Statistics callback for progress
          if (!mounted || task.durationMs <= 0) return;
          final progress = (statistics.getTime() / task.durationMs).clamp(
            0.0,
            1.0,
          );
          // 按整数百分比合流，避免每条统计都触发重绘。
          if ((progress * 100).floor() == (task.progress.value * 100).floor()) {
            return;
          }
          task.progress.value = progress;
          _syncOverallProgress();
        },
      );

      task.sessionId = session.getSessionId();

      // 等待完成信号，替代 300ms 轮询：批量任务之间不再有空转间隔。
      await completion.future;
    } catch (e) {
      if (!completion.isCompleted) completion.complete();
      if (mounted) {
        setState(() {
          task.status = TaskStatus.failed;
          task.errorMessage = e.toString();
          _failedCount++;
        });
      }
    }
  }

  void _syncOverallProgress() {
    if (!mounted) return;
    if (_tasks.isEmpty) {
      _overallProgress.value = 0;
      return;
    }
    var total = 0.0;
    for (final task in _tasks) {
      total += task.progress.value;
    }
    _overallProgress.value = total / _tasks.length;
  }

  void _cancelAll() {
    for (final task in _tasks) {
      if (task.status == TaskStatus.running && task.sessionId != null) {
        FFmpegKit.cancel(task.sessionId!);
      }
      if (task.status == TaskStatus.pending) {
        task.status = TaskStatus.cancelled;
      }
    }
    setState(() => _isProcessing = false);
  }

  void _removeTask(int index) {
    final task = _tasks[index];
    if (task.status == TaskStatus.running && task.sessionId != null) {
      FFmpegKit.cancel(task.sessionId!);
    }
    setState(() => _tasks.removeAt(index));
    if (task.status != TaskStatus.running) task.disposeProgress();
    _syncOverallProgress();
  }

  void _clearCompleted() {
    final removed = _tasks
        .where(
          (t) =>
              t.status == TaskStatus.success ||
              t.status == TaskStatus.failed ||
              t.status == TaskStatus.cancelled,
        )
        .toList();
    if (removed.isEmpty) return;
    setState(() {
      for (final task in removed) {
        _tasks.remove(task);
      }
    });
    for (final task in removed) {
      task.disposeProgress();
    }
    _syncOverallProgress();
  }

  Future<void> _saveToDownloads(VideoToAudioTask task) async {
    try {
      // Use SAF to let user choose save location
      final fileName = p.basename(task.outputPath);
      final savePath = await FileAccessHelper.saveFile(
        fileName: fileName,
        dialogTitle: '保存音频文件',
      );

      if (savePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('取消保存')));
        }
        return;
      }

      // Copy file to selected location
      await File(task.outputPath).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('已保存'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _quotePath(String path) {
    return '"${path.replaceAll('"', r'\"')}"';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LumenSecondaryScaffold(
      title: '视频转音频',
      children: [
        LumenPageIntro(
          icon: Icons.audiotrack_rounded,
          title: '视频转音频',
          description: '批量选择视频、设置输出格式，查看转换进度并保存提取的音频。',
          chips: [
            '输出 ${_selectedFormat.label}',
            _probingDurations
                ? '正在读取时长…'
                : (_tasks.isEmpty ? '暂无任务' : '${_tasks.length} 个任务'),
            '完成 $_completedCount / 失败 $_failedCount',
          ],
        ),
        ToolQuickActionsBar(
          actions: [
            ToolQuickActionData(
              icon: Icons.video_library_rounded,
              label: '选择视频',
              backgroundColor: cs.primaryContainer,
              iconColor: cs.onPrimaryContainer,
              onTap: _isProcessing || _probingDurations ? null : _pickVideos,
            ),
            ToolQuickActionData(
              icon: _isProcessing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              label: _isProcessing ? '取消转换' : '开始批量转换',
              backgroundColor: cs.secondaryContainer,
              iconColor: cs.onSecondaryContainer,
              onTap: _isProcessing
                  ? _cancelAll
                  : (_tasks.isEmpty || _probingDurations
                        ? null
                        : _startBatchConversion),
            ),
            ToolQuickActionData(
              icon: Icons.cleaning_services_rounded,
              label: '清理已完成',
              backgroundColor: cs.tertiaryContainer,
              iconColor: cs.onTertiaryContainer,
              onTap: _tasks.isEmpty ? null : _clearCompleted,
            ),
          ],
        ),
        LumenSettingsSection(
          icon: Icons.library_music_rounded,
          title: '输出格式',
          children: [_buildFormatSelector(cs)],
        ),
        if (_isProcessing)
          LumenSettingsSection(
            icon: Icons.equalizer_rounded,
            title: '批量进度',
            children: [_buildOverallProgress(cs)],
          ),
        LumenSettingsSection(
          icon: Icons.queue_play_next_rounded,
          title: '任务列表',
          subtitle: '${_tasks.length} 项',
          children: [
            if (_tasks.isEmpty)
              const ToolEmptyStateCard(
                icon: Icons.video_library_outlined,
                title: '还没有待处理视频',
                description: '先选择一个或多个视频文件，再开始批量提取音频。',
              )
            else
              ..._tasks.asMap().entries.map(
                (entry) => _buildTaskCard(cs, entry.key, entry.value),
              ),
          ],
        ),
      ],
    );
  }


  Widget _buildFormatSelector(ColorScheme cs) {
    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LumenIconChip(
                icon: Icons.audio_file_rounded,
                size: 40,
                iconSize: 20,
                shape: LumenIconChipShape.rounded,
              ),
              const SizedBox(width: 12),
              Text(
                '输出格式',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioFormat.values.map((fmt) {
              final selected = fmt == _selectedFormat;
              return ChoiceChip(
                label: Text(fmt.label),
                selected: selected,
                onSelected: _isProcessing
                    ? null
                    : (v) {
                        if (!v) return;
                        setState(() {
                          _selectedFormat = fmt;
                          // Keep pending task extensions in sync with format.
                          for (final task in _tasks) {
                            if (task.status == TaskStatus.pending ||
                                task.status == TaskStatus.failed) {
                              final baseName = p.basenameWithoutExtension(
                                task.fileName,
                              );
                              final dir = p.dirname(task.outputPath);
                              task.outputPath = p.join(
                                dir,
                                '$baseName.${fmt.extension}',
                              );
                            }
                          }
                        });
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress(ColorScheme cs) {
    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '批量转换中...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$_completedCount / ${_tasks.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: _overallProgress,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(ColorScheme cs, int index, VideoToAudioTask task) {
    final statusIcon = switch (task.status) {
      TaskStatus.pending => Icon(
        Icons.hourglass_empty_rounded,
        color: cs.outline,
        size: 20,
      ),
      TaskStatus.running => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
      ),
      TaskStatus.success => Icon(
        Icons.check_circle_rounded,
        color: cs.tertiary,
        size: 20,
      ),
      TaskStatus.failed => Icon(
        Icons.error_rounded,
        color: cs.error,
        size: 20,
      ),
      TaskStatus.cancelled => Icon(
        Icons.cancel_rounded,
        color: cs.outline,
        size: 20,
      ),
    };

    return Padding(
      key: ObjectKey(task),
      padding: const EdgeInsets.only(bottom: 8),
      child: LumenActionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statusIcon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.durationStr != null)
                        Text(
                          '时长: ${task.durationStr}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (task.status == TaskStatus.success)
                  IconButton(
                    icon: const Icon(Icons.save_alt_rounded, size: 20),
                    tooltip: '保存',
                    onPressed: () => _saveToDownloads(task),
                  ),
                if (!_isProcessing || task.status != TaskStatus.running)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: cs.outline,
                    ),
                    tooltip: '移除',
                    onPressed: () => _removeTask(index),
                  ),
              ],
            ),
            if (task.status == TaskStatus.running) ...[
              const SizedBox(height: 10),
              ValueListenableBuilder<double>(
                valueListenable: task.progress,
                builder: (context, value, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
            if (task.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  task.errorMessage!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
