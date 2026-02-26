import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  final TextEditingController _videoBitrateController = TextEditingController(text: '2000');
  final TextEditingController _audioBitrateController = TextEditingController(text: '128');
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
  final TextEditingController _trimStartController = TextEditingController(text: '0');
  final TextEditingController _trimEndController = TextEditingController();
  int _rotation = 0;
  
  bool _autoCorrectOrientation = true;

  // Video player
  Player? _player;
  VideoController? _videoController;
  bool _isPlaying = false;

  @override
  void dispose() {
    _compressor.cleanup();
    _widthController.dispose();
    _heightController.dispose();
    _videoBitrateController.dispose();
    _audioBitrateController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    _player?.dispose();
    super.dispose();
  }

  void _initializePlayer(String videoPath) {
    _player?.dispose();
    _player = Player();
    _videoController = VideoController(_player!);
    _player!.open(Media(videoPath));
    setState(() => _isPlaying = false);
  }

  void _togglePlayPause() {
    if (_player == null) return;
    _player!.playOrPause();
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result == null || result.files.single.path == null) return;

      if (!mounted) return;

      setState(() {
        _videoPath = result.files.single.path;
        _videoInfo = null;
        _compressionResult = null;
        _isLoadingInfo = true;
      });

      final info = await _compressor.getVideoInfo(_videoPath!);
      
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频失败: $e')),
        );
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
      final compressionId = 'compression_${DateTime.now().millisecondsSinceEpoch}';
      
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
        _initializePlayer(result.outputPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 压缩完成！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 压缩失败: $e')),
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
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('无法访问存储目录');
      }

      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${directory.path}/$fileName';

      await File(_compressionResult!.outputPath).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 已保存到: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
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
      if (trimStartMs != null && trimEndMs != null && trimEndMs <= trimStartMs) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频压缩'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 选择视频按钮
          FilledButton.icon(
            onPressed: _isCompressing ? null : _pickVideo,
            icon: const Icon(Icons.video_library_rounded),
            label: const Text('选择视频'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          if (_isLoadingInfo) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],

          // 视频信息卡片
          if (_videoInfo != null) ...[
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              title: '原视频信息',
              icon: Icons.info_outline_rounded,
              children: [
                _buildInfoRow('时长', _videoInfo!.durationFormatted),
                _buildInfoRow('分辨率', '${_videoInfo!.width}x${_videoInfo!.height}'),
                _buildInfoRow('文件大小', _videoInfo!.fileSizeFormatted),
              ],
            ),

            // 质量选择
            const SizedBox(height: 16),
            _buildQualitySelector(cs),

            // 高级设置开关
            const SizedBox(height: 16),
            _buildAdvancedSettingsToggle(cs),

            // 高级设置面板
            if (_showAdvancedSettings) ...[
              const SizedBox(height: 16),
              _buildAdvancedSettingsPanel(cs),
            ],

            // 压缩按钮
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isCompressing ? null : _compressVideo,
              icon: const Icon(Icons.compress_rounded),
              label: const Text('开始压缩'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: cs.primary,
              ),
            ),
          ],

          // 压缩进度
          if (_isCompressing) ...[
            const SizedBox(height: 24),
            _buildProgressCard(cs),
          ],

          // 压缩结果
          if (_compressionResult != null) ...[
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              title: '压缩结果',
              icon: Icons.check_circle_outline_rounded,
              children: [
                _buildInfoRow('原大小', _compressionResult!.originalSizeFormatted),
                _buildInfoRow('压缩后', _compressionResult!.compressedSizeFormatted),
                _buildInfoRow('节省空间', _compressionResult!.spaceSavedFormatted),
              ],
            ),

            // Video player
            if (_videoController != null) ...[
              const SizedBox(height: 16),
              _buildVideoPlayer(cs),
            ],

            // 保存按钮
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _saveVideo,
              icon: const Icon(Icons.save_rounded),
              label: const Text('保存到相册'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;

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
                  child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
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
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
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
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsToggle(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: cs.onTertiaryContainer,
                  size: 20,
                ),
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
        ),
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
                Text('帧率: ${_frameRate.toInt()} FPS', style: TextStyle(color: cs.onSurface)),
                const Spacer(),
                Text(_frameRate.toInt().toString(), style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
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
              value: _videoCodec,
              decoration: const InputDecoration(
                labelText: '视频编码器',
                helperText: 'H.265 压缩率更高但编码慢',
              ),
              items: const [
                DropdownMenuItem(value: VVideoCodec.h264, child: Text('H.264 (兼容性好)')),
                DropdownMenuItem(value: VVideoCodec.h265, child: Text('H.265 (更小体积)')),
              ],
              onChanged: (v) => setState(() => _videoCodec = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VEncodingSpeed>(
              value: _encodingSpeed,
              decoration: const InputDecoration(
                labelText: '编码速度',
                helperText: '慢速编码质量更好',
              ),
              items: const [
                DropdownMenuItem(value: VEncodingSpeed.ultrafast, child: Text('极快')),
                DropdownMenuItem(value: VEncodingSpeed.fast, child: Text('快速')),
                DropdownMenuItem(value: VEncodingSpeed.medium, child: Text('中等')),
                DropdownMenuItem(value: VEncodingSpeed.slow, child: Text('慢速')),
              ],
              onChanged: (v) => setState(() => _encodingSpeed = v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('CRF 质量: $_crf', style: TextStyle(color: cs.onSurface)),
                const Spacer(),
                Text('$_crf', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('数值越小质量越好 (18-28)', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
                value: _audioCodec,
                decoration: const InputDecoration(labelText: '音频编码器'),
                items: const [
                  DropdownMenuItem(value: VAudioCodec.aac, child: Text('AAC')),
                  DropdownMenuItem(value: VAudioCodec.mp3, child: Text('MP3')),
                ],
                onChanged: (v) => setState(() => _audioCodec = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _audioSampleRate,
                decoration: const InputDecoration(labelText: '采样率'),
                items: const [
                  DropdownMenuItem(value: 44100, child: Text('44.1 kHz (标准)')),
                  DropdownMenuItem(value: 48000, child: Text('48 kHz (高质量)')),
                ],
                onChanged: (v) => setState(() => _audioSampleRate = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _audioChannels,
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
            _buildEffectSlider(cs, '亮度', _brightness, (v) => setState(() => _brightness = v)),
            const SizedBox(height: 8),
            _buildEffectSlider(cs, '对比度', _contrast, (v) => setState(() => _contrast = v)),
            const SizedBox(height: 8),
            _buildEffectSlider(cs, '饱和度', _saturation, (v) => setState(() => _saturation = v)),
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
              value: _rotation,
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Padding(
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: cs.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '视频预览',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
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
                Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePlayPause,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(100),
                              Colors.transparent,
                              Colors.black.withAlpha(100),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  onPressed: () {
                    _player?.seek(Duration.zero);
                  },
                  icon: const Icon(Icons.replay_rounded),
                  tooltip: '重新播放',
                ),
                IconButton.filled(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  tooltip: _isPlaying ? '暂停' : '播放',
                ),
                StreamBuilder<Duration>(
                  stream: _player?.stream.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _player?.state.duration ?? Duration.zero;
                    return Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    );
                  },
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
