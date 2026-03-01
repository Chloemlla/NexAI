import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;

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
  double progress;
  String? errorMessage;
  int? sessionId;
  String? durationStr;
  int durationMs;

  VideoToAudioTask({
    required this.inputPath,
    required this.fileName,
    required this.outputPath,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.sessionId,
    this.durationStr,
    this.durationMs = 0,
  });
}

class VideoToAudioPage extends StatefulWidget {
  const VideoToAudioPage({super.key});

  @override
  State<VideoToAudioPage> createState() => _VideoToAudioPageState();
}

class _VideoToAudioPageState extends State<VideoToAudioPage> {
  final List<VideoToAudioTask> _tasks = [];
  AudioFormat _selectedFormat = AudioFormat.mp3;
  bool _isProcessing = false;
  int _completedCount = 0;
  int _failedCount = 0;

  @override
  void dispose() {
    // Cancel any running sessions
    for (final task in _tasks) {
      if (task.status == TaskStatus.running && task.sessionId != null) {
        FFmpegKit.cancel(task.sessionId!);
      }
    }
    super.dispose();
  }

  Future<void> _pickVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final outputDir = await _getOutputDirectory();

      final newTasks = <VideoToAudioTask>[];
      for (final file in result.files) {
        if (file.path == null) continue;
        final baseName = p.basenameWithoutExtension(file.name);
        final outputPath = p.join(
          outputDir,
          '$baseName.${_selectedFormat.extension}',
        );
        newTasks.add(
          VideoToAudioTask(
            inputPath: file.path!,
            fileName: file.name,
            outputPath: outputPath,
          ),
        );
      }

      // Probe duration for each file
      for (final task in newTasks) {
        try {
          final session = await FFprobeKit.getMediaInformation(task.inputPath);
          final info = session.getMediaInformation();
          if (info != null) {
            final durationStr = info.getDuration();
            if (durationStr != null) {
              task.durationMs = (double.parse(durationStr) * 1000).toInt();
              task.durationStr = _formatDuration(
                Duration(milliseconds: task.durationMs),
              );
            }
          }
        } catch (_) {}
      }

      setState(() => _tasks.addAll(newTasks));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
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
          task.progress = 0.0;
          task.errorMessage = null;
        }
      }
    });

    for (final task in _tasks) {
      if (!mounted || !_isProcessing) break;
      if (task.status == TaskStatus.success) continue;

      await _convertSingle(task);
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      if (_completedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 完成 $_completedCount 个，失败 $_failedCount 个'),
            backgroundColor: _failedCount == 0 ? Colors.green : Colors.orange,
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
        '-i "${task.inputPath}" -vn ${_selectedFormat.codecArgs} -y "${task.outputPath}"';

    try {
      final session = await FFmpegKit.executeAsync(
        command,
        (Session session) async {
          // Completion callback
          final returnCode = await session.getReturnCode();
          if (!mounted) return;
          setState(() {
            if (ReturnCode.isSuccess(returnCode)) {
              task.status = TaskStatus.success;
              task.progress = 1.0;
              _completedCount++;
            } else if (ReturnCode.isCancel(returnCode)) {
              task.status = TaskStatus.cancelled;
            } else {
              task.status = TaskStatus.failed;
              task.errorMessage = '转换失败 (code: ${returnCode?.getValue()})';
              _failedCount++;
            }
          });
        },
        (Log log) {
          // Log callback - can be used for debugging
        },
        (Statistics statistics) {
          // Statistics callback for progress
          if (task.durationMs > 0) {
            final time = statistics.getTime();
            final progress = (time / task.durationMs).clamp(0.0, 1.0);
            if (mounted) {
              setState(() => task.progress = progress);
            }
          }
        },
      );

      task.sessionId = session.getSessionId();

      // Wait for session to complete
      await _waitForSession(task);
    } catch (e) {
      if (mounted) {
        setState(() {
          task.status = TaskStatus.failed;
          task.errorMessage = e.toString();
          _failedCount++;
        });
      }
    }
  }

  Future<void> _waitForSession(VideoToAudioTask task) async {
    // Poll until the task is no longer running
    while (mounted && task.status == TaskStatus.running) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
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
  }

  void _clearCompleted() {
    setState(() {
      _tasks.removeWhere(
        (t) =>
            t.status == TaskStatus.success ||
            t.status == TaskStatus.failed ||
            t.status == TaskStatus.cancelled,
      );
    });
  }

  Future<void> _saveToDownloads(VideoToAudioTask task) async {
    try {
      if (Platform.isAndroid) {
        final hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('需要存储权限才能保存文件'),
                action: SnackBarAction(
                  label: '去设置',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // Copy to Downloads or Music directory
      final saveDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Music/NexAI')
          : await getApplicationDocumentsDirectory();

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final savePath = p.join(saveDir.path, p.basename(task.outputPath));
      await File(task.outputPath).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已保存到 ${p.dirname(savePath)}'),
            backgroundColor: Colors.green,
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  double get _overallProgress {
    if (_tasks.isEmpty) return 0;
    final total = _tasks.fold<double>(0, (sum, t) => sum + t.progress);
    return total / _tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频转音频'),
        actions: [
          if (_tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded),
              tooltip: '清除已完成',
              onPressed: _clearCompleted,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pick videos button
          FilledButton.icon(
            onPressed: _isProcessing ? null : _pickVideos,
            icon: const Icon(Icons.video_library_rounded),
            label: const Text('选择视频（可多选）'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 16),

          // Format selector
          _buildFormatSelector(cs),

          // Overall progress
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            _buildOverallProgress(cs),
          ],

          // Action buttons
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _startBatchConversion,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      '开始转换 (${_tasks.where((t) => t.status != TaskStatus.success).length})',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: cs.primary,
                    ),
                  ),
                ),
                if (_isProcessing) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _cancelAll,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('取消'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Task list
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '任务列表 (${_tasks.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ..._tasks.asMap().entries.map(
              (entry) => _buildTaskCard(cs, entry.key, entry.value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatSelector(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.audio_file_rounded,
                    color: cs.onPrimaryContainer,
                    size: 20,
                  ),
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
                          if (v) setState(() => _selectedFormat = fmt);
                        },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '批量转换中...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
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
            LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
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
      TaskStatus.success => const Icon(
        Icons.check_circle_rounded,
        color: Colors.green,
        size: 20,
      ),
      TaskStatus.failed => const Icon(
        Icons.error_rounded,
        color: Colors.red,
        size: 20,
      ),
      TaskStatus.cancelled => Icon(
        Icons.cancel_rounded,
        color: cs.outline,
        size: 20,
      ),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Padding(
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
              LinearProgressIndicator(
                value: task.progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Text(
                '${(task.progress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
            ],
            if (task.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  task.errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
