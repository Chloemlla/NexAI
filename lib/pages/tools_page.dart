import 'package:flutter/material.dart';
import 'video_compressor_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '工具箱',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '实用工具集合，提升效率',
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurfaceVariant,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              delegate: SliverChildListDelegate([
                _buildToolCard(
                  context,
                  icon: Icons.video_file_rounded,
                  title: '视频压缩',
                  description: '减小视频体积',
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer,
                      cs.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VideoCompressorPage(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: cs.outlineVariant.withAlpha(40),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withAlpha(40),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
