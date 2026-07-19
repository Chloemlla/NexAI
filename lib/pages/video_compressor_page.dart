import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/file_access_helper.dart';
import '../widgets/tool_page_style.dart';
import '../widgets/lumen/lumen.dart';
import '../theme/lumen_tokens.dart';

class VideoCompressorPage extends StatefulWidget {
  const VideoCompressorPage({super.key});

  @override
  State<VideoCompressorPage> createState() => _VideoCompressorPageState();
}

class _VideoCompressorPageState extends State<VideoCompressorPage> {
  final VVideoCompressor _compressor = VVideoCompressor();

  String? _videoPath;
  VVideoInfo? _videoInfo;
  VVideoCompressionResult? _compressionResult;
  VVideoCompressQuality _selectedQuality = VVideoCompressQuality.medium;
  double _progress = 0.0;
  bool _isCompressing = false;
  bool _isLoadingInfo = false;
  bool _showAdvancedSettings = false;

  // Advanced Settings
  bool _useCustomResolution = false;
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _videoBitrateController = TextEditingController(
    text: '2000',
  );
  final TextEditingController _audioBitrateController = TextEditingController(
    text: '128',
  );
  double _frameRate = 30.0;

  VVideoCodec _videoCodec = VVideoCodec.h264;
  VAudioCodec _audioCodec = VAudioCodec.aac;
  VEncodingSpeed _encodingSpeed = VEncodingSpeed.medium;
  int _crf = 23;
  bool _twoPassEncoding = false;
  bool _hardwareAcceleration = true;

  int _audioSampleRate = 44100;
  int _audioChannels = 2;
  bool _removeAudio = false;

  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

  bool _enableTrim = false;
  final TextEditingController _trimStartController = TextEditingController(
    text: '0',
  );
  final TextEditingController _trimEndController = TextEditingController();
  int _rotation = 0;

  bool _autoCorrectOrientation = true;

  // FFmpeg-backed video preview
  Timer? _previewTimer;
  String? _previewVideoPath;
  String? _previewFramePath;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  bool _isPreviewFrameLoading = false;
  bool _isPlaying = false;
  int _previewRequestId = 0;
  bool _showPreviewControls = true;
  Timer? _controlsHideTimer;

  @override
  void dispose() {
    _compressor.cleanup();
    _widthController.dispose();
    _heightController.dispose();
    _videoBitrateController.dispose();
    _audioBitrateController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    _previewTimer?.cancel();
    _controlsHideTimer?.cancel();
    _previewRequestId++;
    _deletePreviewFrame();
    super.dispose();
  }

  Future<void> _initializePreview(String videoPath) async {
    _stopPreviewPlayback(updateState: false);
    _previewRequestId++;
    _deletePreviewFrame();

    if (!mounted) return;
    setState(() {
      _previewVideoPath = videoPath;
      _previewFramePath = null;
      _previewPosition = Duration.zero;
      _previewDuration = Duration.zero;
      _isPreviewFrameLoading = true;
      _isPlaying = false;
      _showPreviewControls = true;
    });

    final duration = await _probeVideoDuration(videoPath);
    if (!mounted || _previewVideoPath != videoPath) return;

    setState(() => _previewDuration = duration);
    await _renderPreviewFrame(Duration.zero);
  }

  void _togglePlayPause() {
    if (_previewVideoPath == null) return;
    if (_isPlaying) {
      _stopPreviewPlayback();
      _revealPreviewControls(autoHide: false);
      return;
    }
    if (_previewDuration == Duration.zero) {
      // Probe failed: still allow single-frame refresh feedback.
      _revealPreviewControls(autoHide: false);
      _renderPreviewFrame(_previewPosition);
      return;
    }
    _startPreviewPlayback();
  }

  void _startPreviewPlayback() {
    if (_previewVideoPath == null) return;
    _previewTimer?.cancel();

    if (_previewDuration > Duration.zero &&
        _previewPosition >= _previewDuration) {
      _previewPosition = Duration.zero;
    }

    setState(() {
      _isPlaying = true;
      _showPreviewControls = true;
    });
    _scheduleControlsHide();

    _previewTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _previewVideoPath == null) return;

      final nextPosition = _previewPosition + const Duration(seconds: 1);
      final endReached =
          _previewDuration > Duration.zero && nextPosition >= _previewDuration;
      final target = endReached ? _previewDuration : nextPosition;

      setState(() => _previewPosition = target);
      // Fire-and-forget frame render so slow FFmpeg cannot stall the clock.
      unawaited(_renderPreviewFrame(target));

      if (endReached) {
        _stopPreviewPlayback();
        _revealPreviewControls(autoHide: false);
      }
    });
  }

  void _stopPreviewPlayback({bool updateState = true}) {
    _previewTimer?.cancel();
    _previewTimer = null;
    _controlsHideTimer?.cancel();
    if (updateState && mounted) {
      setState(() {
        _isPlaying = false;
        _showPreviewControls = true;
      });
    } else {
      _isPlaying = false;
      _showPreviewControls = true;
    }
  }

  Future<void> _replayPreview() async {
    if (_previewVideoPath == null) return;
    _stopPreviewPlayback();
    setState(() => _previewPosition = Duration.zero);
    await _renderPreviewFrame(Duration.zero);
    if (!mounted) return;
    if (_previewDuration > Duration.zero) {
      _startPreviewPlayback();
    } else {
      _revealPreviewControls(autoHide: false);
    }
  }

  void _revealPreviewControls({bool autoHide = true}) {
    _controlsHideTimer?.cancel();
    if (!mounted) {
      _showPreviewControls = true;
      return;
    }
    setState(() => _showPreviewControls = true);
    if (autoHide && _isPlaying) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted || !_isPlaying) return;
      setState(() => _showPreviewControls = false);
    });
  }

  void _seekPreview(Duration position) {
    if (_previewVideoPath == null) return;
    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      _stopPreviewPlayback();
    }
    final clamped = _previewDuration > Duration.zero
        ? Duration(
            milliseconds: position.inMilliseconds.clamp(
              0,
              _previewDuration.inMilliseconds,
            ),
          )
        : Duration.zero;
    setState(() => _previewPosition = clamped);
    _revealPreviewControls(autoHide: wasPlaying);
    unawaited(_renderPreviewFrame(clamped).then((_) {
      if (!mounted) return;
      if (wasPlaying && _previewDuration > Duration.zero) {
        _startPreviewPlayback();
      }
    }));
  }

  Future<Duration> _probeVideoDuration(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final duration = session.getMediaInformation()?.getDuration();
      final seconds = duration == null ? null : double.tryParse(duration);
      if (seconds == null || seconds <= 0) return Duration.zero;
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<void> _renderPreviewFrame(Duration position) async {
    final videoPath = _previewVideoPath;
    if (videoPath == null) return;

    final requestId = ++_previewRequestId;
    if (mounted) {
      setState(() => _isPreviewFrameLoading = true);
    }

    final tempDir = await getTemporaryDirectory();
    final previewDir = Directory(p.join(tempDir.path, 'video_previews'));
    if (!await previewDir.exists()) {
      await previewDir.create(recursive: true);
    }

    final framePath = p.join(
      previewDir.path,
      'preview_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final command =
        '-hide_banner -loglevel error -y '
        '-ss ${_formatSeconds(_previewFramePosition(position))} '
        '-i ${_quotePath(videoPath)} -frames:v 1 -q:v 2 '
        '${_quotePath(framePath)}';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final frameFile = File(framePath);
      if (!mounted || requestId != _previewRequestId) {
        if (await frameFile.exists()) await frameFile.delete();
        return;
      }

      if (ReturnCode.isSuccess(returnCode) && await frameFile.exists()) {
        final previousFrame = _previewFramePath;
        setState(() {
          _previewFramePath = framePath;
          _isPreviewFrameLoading = false;
        });
        _deletePreviewFrame(previousFrame);
      } else {
        if (await frameFile.exists()) await frameFile.delete();
        setState(() => _isPreviewFrameLoading = false);
      }
    } catch (_) {
      if (mounted && requestId == _previewRequestId) {
        setState(() => _isPreviewFrameLoading = false);
      }
      final frameFile = File(framePath);
      if (await frameFile.exists()) await frameFile.delete();
    }
  }

  String _formatSeconds(Duration duration) {
    return (duration.inMilliseconds / 1000).toStringAsFixed(3);
  }

  Duration _previewFramePosition(Duration position) {
    if (_previewDuration == Duration.zero) return position;
    final lastSafeFrame = _previewDuration - const Duration(milliseconds: 200);
    if (lastSafeFrame <= Duration.zero) return Duration.zero;
    return position > lastSafeFrame ? lastSafeFrame : position;
  }

  String _quotePath(String path) {
    return '"${path.replaceAll('"', r'\"')}"';
  }

  void _deletePreviewFrame([String? framePath]) {
    final pathToDelete = framePath ?? _previewFramePath;
    if (pathToDelete == null) return;
    if (framePath == null) {
      _previewFramePath = null;
    }
    final file = File(pathToDelete);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<void> _pickVideo() async {
    try {
      final videoPath = await FileAccessHelper.pickVideo();

      if (videoPath == null) return;

      if (!mounted) return;

      _stopPreviewPlayback(updateState: false);
      _previewRequestId++;
      _deletePreviewFrame();

      setState(() {
        _videoPath = videoPath;
        _videoInfo = null;
        _compressionResult = null;
        _previewVideoPath = null;
        _previewFramePath = null;
        _previewPosition = Duration.zero;
        _previewDuration = Duration.zero;
        _isPlaying = false;
        _isLoadingInfo = true;
      });

      final info = await _compressor.getVideoInfo(videoPath);

      if (!mounted) return;

      setState(() {
        _videoInfo = info;
        _isLoadingInfo = false;
        // Auto-fill resolution fields
        if (info != null) {
          _widthController.text = info.width.toString();
          _heightController.text = info.height.toString();
          // Duration is no longer available in VVideoInfo
        }
      });
      if (info != null) {
        await _initializePreview(videoPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择视频失败: $e')));
      }
    }
  }

  Future<void> _compressVideo() async {
    if (_videoPath == null) return;

    setState(() {
      _isCompressing = true;
      _progress = 0.0;
      _compressionResult = null;
    });

    try {
      final compressionId =
          'compression_${DateTime.now().millisecondsSinceEpoch}';

      final advancedConfig = _buildAdvancedConfig();

      final result = await _compressor.compressVideo(
        _videoPath!,
        VVideoCompressionConfig(
          quality: _selectedQuality,
          advanced: advancedConfig,
        ),
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
        id: compressionId,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() => _compressionResult = result);
        final messenger = ScaffoldMessenger.of(context);
        await _initializePreview(result.compressedFilePath);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('压缩完成！'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('压缩未完成或已取消')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('压缩失败: $e')),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }
  }

  Future<void> _saveVideo() async {
    if (_compressionResult == null) return;

    try {
      // Request gallery/storage permission based on Android version
      final hasAccess = await _requestGalleryPermission();
      if (!hasAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('需要相册权限才能保存视频'),
              action: SnackBarAction(label: '去设置', onPressed: () => Gal.open()),
            ),
          );
        }
        return;
      }

      await Gal.putVideo(
        _compressionResult!.compressedFilePath,
        album: 'NexAI',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('已保存到相册'),
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

  Future<bool> _requestGalleryPermission() async {
    // Use Gal library which handles MediaStore API properly for all Android versions
    if (Platform.isAndroid) {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (hasAccess) return true;
      return await Gal.requestAccess(toAlbum: true);
    }
    // Non-Android platforms
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (hasAccess) return true;
    return await Gal.requestAccess(toAlbum: true);
  }

  VVideoAdvancedConfig _buildAdvancedConfig() {
    // Parse and validate custom resolution
    int? customWidth;
    int? customHeight;
    if (_useCustomResolution) {
      final width = int.tryParse(_widthController.text);
      final height = int.tryParse(_heightController.text);
      // Ensure dimensions are positive and reasonable
      if (width != null && width > 0 && width <= 7680) {
        customWidth = width;
      }
      if (height != null && height > 0 && height <= 4320) {
        customHeight = height;
      }
    }

    // Parse and validate bitrates
    final videoBitrate = int.tryParse(_videoBitrateController.text);
    final audioBitrate = int.tryParse(_audioBitrateController.text);

    // Parse and validate trim times
    int? trimStartMs;
    int? trimEndMs;
    if (_enableTrim) {
      final trimStart = int.tryParse(_trimStartController.text);
      final trimEnd = int.tryParse(_trimEndController.text);

      if (trimStart != null && trimStart >= 0) {
        trimStartMs = trimStart * 1000;
      }
      if (trimEnd != null && trimEnd > 0) {
        trimEndMs = trimEnd * 1000;
      }

      // Ensure trim end is after trim start
      if (trimStartMs != null &&
          trimEndMs != null &&
          trimEndMs <= trimStartMs) {
        trimEndMs = null; // Invalid range, ignore trim end
      }
    }

    return VVideoAdvancedConfig(
      // Resolution & Quality
      customWidth: customWidth,
      customHeight: customHeight,
      videoBitrate: videoBitrate != null && videoBitrate > 0
          ? videoBitrate * 1000
          : null,
      frameRate: _frameRate,

      // Codec & Encoding
      videoCodec: _videoCodec,
      audioCodec: _audioCodec,
      encodingSpeed: _encodingSpeed,
      crf: _crf,
      twoPassEncoding: _twoPassEncoding,
      hardwareAcceleration: _hardwareAcceleration,

      // Audio Settings
      audioBitrate: audioBitrate != null && audioBitrate > 0
          ? audioBitrate * 1000
          : null,
      audioSampleRate: _audioSampleRate,
      audioChannels: _audioChannels,
      removeAudio: _removeAudio,

      // Video Effects
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,

      // Editing
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      rotation: _rotation,

      // Orientation & Dimension
      autoCorrectOrientation: _autoCorrectOrientation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final videoInfo = _videoInfo;

    return LumenSecondaryScaffold(
      title: '视频压缩',
      children: [
        LumenPageIntro(
          icon: Icons.video_file_rounded,
          title: '视频压缩',
          description: '先选择视频并查看素材信息，再设置压缩质量与高级参数，完成后保存结果。',
          chips: [
            '质量 ${_selectedQuality.name}',
            _isCompressing
                ? '${(_progress * 100).toInt()}%'
                : (_compressionResult != null ? '压缩完成' : '等待素材'),
            _showAdvancedSettings ? '高级设置展开' : '支持高级设置',
          ],
        ),
        ToolQuickActionsBar(
          actions: [
            ToolQuickActionData(
              icon: Icons.video_library_rounded,
              label: '选择视频',
              backgroundColor: cs.primaryContainer,
              iconColor: cs.onPrimaryContainer,
              onTap: _isCompressing ? null : _pickVideo,
            ),
            ToolQuickActionData(
              icon: Icons.compress_rounded,
              label: '开始压缩',
              backgroundColor: cs.secondaryContainer,
              iconColor: cs.onSecondaryContainer,
              onTap: _videoInfo == null || _isCompressing ? null : _compressVideo,
            ),
            ToolQuickActionData(
              icon: Icons.save_alt_rounded,
              label: '保存结果',
              backgroundColor: cs.tertiaryContainer,
              iconColor: cs.onTertiaryContainer,
              onTap: _compressionResult == null ? null : _saveVideo,
            ),
          ],
        ),
        // Preserve original body composition and section order.
        ..._buildSecondaryBody(cs, videoInfo),
      ],
    );
  }

  List<Widget> _buildSecondaryBody(ColorScheme cs, dynamic videoInfo) {
    return [
if (_isLoadingInfo) ...[
                  const ToolSectionTitle(
                    icon: Icons.sync_rounded,
                    title: '读取素材信息',
                  ),
                  const SizedBox(height: 12),
                  const ToolPanel(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (videoInfo == null && !_isLoadingInfo)
                  const ToolEmptyStateCard(
                    icon: Icons.video_library_outlined,
                    title: '还没有选中视频',
                    description: '先选择一个视频文件，再配置压缩质量和高级参数。',
                  )
                else if (videoInfo != null) ...[
                  const ToolSectionTitle(
                    icon: Icons.info_outline_rounded,
                    title: '原视频信息',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    title: '原视频信息',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildInfoRow('时长', videoInfo.durationFormatted),
                      _buildInfoRow(
                        '分辨率',
                        '${videoInfo.width}x${videoInfo.height}',
                      ),
                      _buildInfoRow('文件大小', videoInfo.fileSizeFormatted),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const ToolSectionTitle(
                    icon: Icons.high_quality_rounded,
                    title: '压缩参数',
                  ),
                  const SizedBox(height: 12),
                  _buildQualitySelector(cs),
                  const SizedBox(height: 12),
                  _buildAdvancedSettingsToggle(cs),
                  if (_showAdvancedSettings) ...[
                    const SizedBox(height: 12),
                    _buildAdvancedSettingsPanel(cs),
                  ],
                ],
                if (_isCompressing) ...[
                  const SizedBox(height: 20),
                  const ToolSectionTitle(
                    icon: Icons.equalizer_rounded,
                    title: '压缩进度',
                  ),
                  const SizedBox(height: 12),
                  _buildProgressCard(cs),
                ],
                if (_compressionResult != null) ...[
                  const SizedBox(height: 20),
                  const ToolSectionTitle(
                    icon: Icons.check_circle_outline_rounded,
                    title: '压缩结果',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    title: '压缩结果',
                    icon: Icons.check_circle_outline_rounded,
                    children: [
                      _buildInfoRow(
                        '原大小',
                        _compressionResult!.originalSizeFormatted,
                      ),
                      _buildInfoRow(
                        '压缩后',
                        _compressionResult!.compressedSizeFormatted,
                      ),
                      _buildInfoRow(
                        '节省空间',
                        _compressionResult!.spaceSavedFormatted,
                      ),
                    ],
                  ),
                  if (_previewVideoPath != null) ...[
                    const SizedBox(height: 12),
                    _buildVideoPlayer(cs),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _saveVideo,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('保存到相册'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
    ];
  }


  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;

    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LumenIconChip(
                icon: icon,
                size: 40,
                iconSize: 20,
                shape: LumenIconChipShape.rounded,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector(ColorScheme cs) {
    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '压缩质量',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<VVideoCompressQuality>(
            segments: const [
              ButtonSegment(
                value: VVideoCompressQuality.low,
                label: Text('低'),
                icon: Icon(Icons.compress_rounded, size: 16),
              ),
              ButtonSegment(
                value: VVideoCompressQuality.medium,
                label: Text('中'),
                icon: Icon(Icons.compress_rounded, size: 16),
              ),
              ButtonSegment(
                value: VVideoCompressQuality.high,
                label: Text('高'),
                icon: Icon(Icons.compress_rounded, size: 16),
              ),
            ],
            selected: {_selectedQuality},
            onSelectionChanged: (Set<VVideoCompressQuality> newSelection) {
              setState(() => _selectedQuality = newSelection.first);
            },
          ),
          const SizedBox(height: 12),
          Text(
            _getQualityDescription(_selectedQuality),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _getQualityDescription(VVideoCompressQuality quality) {
    switch (quality) {
      case VVideoCompressQuality.low:
        return '480p - 最小文件体积，适合快速分享';
      case VVideoCompressQuality.medium:
        return '720p - 平衡质量与体积，适合社交媒体';
      case VVideoCompressQuality.high:
        return '1080p - 高质量，适合存档';
      default:
        return '';
    }
  }

  Widget _buildProgressCard(ColorScheme cs) {
    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '压缩中...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
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
            value: _progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(LumenTokens.radiusXs),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsToggle(ColorScheme cs) {
    return LumenActionCard(
      padding: const EdgeInsets.all(20),
      onTap: () =>
          setState(() => _showAdvancedSettings = !_showAdvancedSettings),
      child: Row(
        children: [
          LumenIconChip(
            icon: Icons.tune_rounded,
            size: 40,
            iconSize: 20,
            backgroundColor: cs.tertiaryContainer,
            foregroundColor: cs.onTertiaryContainer,
            shape: LumenIconChipShape.rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '高级设置',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '自定义分辨率、编码器、音频等',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _showAdvancedSettings
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            color: cs.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsPanel(ColorScheme cs) {
    return Column(
      children: [
        // Resolution & Quality
        _buildSectionCard(
          cs,
          title: '分辨率与质量',
          icon: Icons.aspect_ratio_rounded,
          children: [
            SwitchListTile(
              title: const Text('自定义分辨率'),
              subtitle: Text(_useCustomResolution ? '手动设置宽高' : '使用预设质量'),
              value: _useCustomResolution,
              onChanged: (v) => setState(() => _useCustomResolution = v),
            ),
            if (_useCustomResolution) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthController,
                      decoration: const InputDecoration(
                        labelText: '宽度',
                        suffixText: 'px',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: '高度',
                        suffixText: 'px',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _videoBitrateController,
              decoration: const InputDecoration(
                labelText: '视频比特率',
                suffixText: 'kbps',
                helperText: '推荐: 1000-3000',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '帧率: ${_frameRate.toInt()} FPS',
                  style: TextStyle(color: cs.onSurface),
                ),
                const Spacer(),
                Text(
                  _frameRate.toInt().toString(),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _frameRate,
              min: 15,
              max: 60,
              divisions: 9,
              label: '${_frameRate.toInt()} FPS',
              onChanged: (v) => setState(() => _frameRate = v),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Codec & Encoding
        _buildSectionCard(
          cs,
          title: '编码器设置',
          icon: Icons.settings_suggest_rounded,
          children: [
            DropdownButtonFormField<VVideoCodec>(
              initialValue: _videoCodec,
              decoration: const InputDecoration(
                labelText: '视频编码器',
                helperText: 'H.265 压缩率更高但编码慢',
              ),
              items: const [
                DropdownMenuItem(
                  value: VVideoCodec.h264,
                  child: Text('H.264 (兼容性好)'),
                ),
                DropdownMenuItem(
                  value: VVideoCodec.h265,
                  child: Text('H.265 (更小体积)'),
                ),
              ],
              onChanged: (v) => setState(() => _videoCodec = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VEncodingSpeed>(
              initialValue: _encodingSpeed,
              decoration: const InputDecoration(
                labelText: '编码速度',
                helperText: '慢速编码质量更好',
              ),
              items: const [
                DropdownMenuItem(
                  value: VEncodingSpeed.ultrafast,
                  child: Text('极快'),
                ),
                DropdownMenuItem(value: VEncodingSpeed.fast, child: Text('快速')),
                DropdownMenuItem(
                  value: VEncodingSpeed.medium,
                  child: Text('中等'),
                ),
                DropdownMenuItem(value: VEncodingSpeed.slow, child: Text('慢速')),
              ],
              onChanged: (v) => setState(() => _encodingSpeed = v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('CRF 质量: $_crf', style: TextStyle(color: cs.onSurface)),
                const Spacer(),
                Text(
                  '$_crf',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              '数值越小质量越好 (18-28)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Slider(
              value: _crf.toDouble(),
              min: 18,
              max: 28,
              divisions: 10,
              label: _crf.toString(),
              onChanged: (v) => setState(() => _crf = v.toInt()),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('双通道编码'),
              subtitle: const Text('更好的质量，但编码时间翻倍'),
              value: _twoPassEncoding,
              onChanged: (v) => setState(() => _twoPassEncoding = v),
            ),
            SwitchListTile(
              title: const Text('硬件加速'),
              subtitle: const Text('使用 GPU 加速编码'),
              value: _hardwareAcceleration,
              onChanged: (v) => setState(() => _hardwareAcceleration = v),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Audio Settings
        _buildSectionCard(
          cs,
          title: '音频设置',
          icon: Icons.audiotrack_rounded,
          children: [
            SwitchListTile(
              title: const Text('移除音频'),
              subtitle: const Text('生成无声视频'),
              value: _removeAudio,
              onChanged: (v) => setState(() => _removeAudio = v),
            ),
            if (!_removeAudio) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _audioBitrateController,
                decoration: const InputDecoration(
                  labelText: '音频比特率',
                  suffixText: 'kbps',
                  helperText: '推荐: 96-192',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<VAudioCodec>(
                initialValue: _audioCodec,
                decoration: const InputDecoration(labelText: '音频编码器'),
                items: const [
                  DropdownMenuItem(value: VAudioCodec.aac, child: Text('AAC')),
                  DropdownMenuItem(value: VAudioCodec.mp3, child: Text('MP3')),
                ],
                onChanged: (v) => setState(() => _audioCodec = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _audioSampleRate,
                decoration: const InputDecoration(labelText: '采样率'),
                items: const [
                  DropdownMenuItem(value: 44100, child: Text('44.1 kHz (标准)')),
                  DropdownMenuItem(value: 48000, child: Text('48 kHz (高质量)')),
                ],
                onChanged: (v) => setState(() => _audioSampleRate = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _audioChannels,
                decoration: const InputDecoration(labelText: '声道'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('单声道')),
                  DropdownMenuItem(value: 2, child: Text('立体声')),
                ],
                onChanged: (v) => setState(() => _audioChannels = v!),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Video Effects
        _buildSectionCard(
          cs,
          title: '视频效果',
          icon: Icons.auto_fix_high_rounded,
          children: [
            _buildEffectSlider(
              cs,
              '亮度',
              _brightness,
              (v) => setState(() => _brightness = v),
            ),
            const SizedBox(height: 8),
            _buildEffectSlider(
              cs,
              '对比度',
              _contrast,
              (v) => setState(() => _contrast = v),
            ),
            const SizedBox(height: 8),
            _buildEffectSlider(
              cs,
              '饱和度',
              _saturation,
              (v) => setState(() => _saturation = v),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Editing
        _buildSectionCard(
          cs,
          title: '视频编辑',
          icon: Icons.cut_rounded,
          children: [
            SwitchListTile(
              title: const Text('裁剪视频'),
              subtitle: const Text('设置开始和结束时间'),
              value: _enableTrim,
              onChanged: (v) => setState(() => _enableTrim = v),
            ),
            if (_enableTrim) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _trimStartController,
                      decoration: const InputDecoration(
                        labelText: '开始时间',
                        suffixText: '秒',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _trimEndController,
                      decoration: const InputDecoration(
                        labelText: '结束时间',
                        suffixText: '秒',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _rotation,
              decoration: const InputDecoration(
                labelText: '旋转',
                helperText: '顺时针旋转角度',
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('不旋转')),
                DropdownMenuItem(value: 90, child: Text('90° (向右)')),
                DropdownMenuItem(value: 180, child: Text('180° (倒置)')),
                DropdownMenuItem(value: 270, child: Text('270° (向左)')),
              ],
              onChanged: (v) => setState(() => _rotation = v!),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Orientation & Dimension
        _buildSectionCard(
          cs,
          title: '方向与尺寸处理',
          icon: Icons.screen_rotation_rounded,
          children: [
            SwitchListTile(
              title: const Text('自动修正方向'),
              subtitle: const Text('修复竖屏视频显示为横屏的问题'),
              value: _autoCorrectOrientation,
              onChanged: (v) => setState(() => _autoCorrectOrientation = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    ColorScheme cs, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return LumenActionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEffectSlider(
    ColorScheme cs,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: cs.onSurface)),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: -1.0,
          max: 1.0,
          divisions: 40,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildVideoPlayer(ColorScheme cs) {
    final durationText = _previewDuration == Duration.zero
        ? '--:--'
        : _formatDuration(_previewDuration);
    final progress = _previewDuration.inMilliseconds <= 0
        ? 0.0
        : (_previewPosition.inMilliseconds / _previewDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return LumenActionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                LumenIconChip(
                  icon: Icons.play_circle_outline_rounded,
                  size: 40,
                  iconSize: 20,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  shape: LumenIconChipShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '视频预览',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _previewDuration == Duration.zero
                            ? (_isPreviewFrameLoading
                                  ? '正在提取预览帧…'
                                  : '仅支持关键帧预览（未读取到时长）')
                            : (_isPlaying ? '播放中' : '已暂停'),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: _previewFramePath == null
                        ? const Center(child: CircularProgressIndicator())
                        : Image.file(
                            File(_previewFramePath!),
                            key: ValueKey(_previewFramePath),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
                if (_isPreviewFrameLoading && _previewFramePath != null)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_isPlaying && _showPreviewControls) {
                        _togglePlayPause();
                      } else if (_isPlaying && !_showPreviewControls) {
                        _revealPreviewControls();
                      } else {
                        _togglePlayPause();
                      }
                    },
                    child: AnimatedOpacity(
                      opacity: (!_isPlaying || _showPreviewControls) ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: ColoredBox(
                        color: (!_isPlaying || _showPreviewControls)
                            ? Colors.black.withAlpha(55)
                            : Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: _previewDuration == Duration.zero
                        ? null
                        : (value) {
                            final target = Duration(
                              milliseconds:
                                  (_previewDuration.inMilliseconds * value)
                                      .round(),
                            );
                            setState(() => _previewPosition = target);
                            _revealPreviewControls(autoHide: _isPlaying);
                          },
                    onChangeEnd: _previewDuration == Duration.zero
                        ? null
                        : (value) {
                            final target = Duration(
                              milliseconds:
                                  (_previewDuration.inMilliseconds * value)
                                      .round(),
                            );
                            _seekPreview(target);
                          },
                  ),
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _replayPreview,
                      icon: const Icon(Icons.replay_rounded),
                      tooltip: '重新播放',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      tooltip: _isPlaying ? '暂停' : '播放',
                    ),
                    const Spacer(),
                    Text(
                      '${_formatDuration(_previewPosition)} / $durationText',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
