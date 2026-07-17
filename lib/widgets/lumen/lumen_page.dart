import 'package:flutter/material.dart';

import '../../theme/lumen_tokens.dart';
import 'lumen_scaffold_background.dart';

/// Project-Lumen page shell: background, max width, padding, section gap.
class LumenPage extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final bool scrollable;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final double? bottomPadding;
  final EdgeInsetsGeometry? padding;

  const LumenPage({
    super.key,
    required this.children,
    this.controller,
    this.scrollable = true,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.bottomPadding,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = LumenTokens.horizontalPaddingForWidth(width);
    final contentPadding = padding ??
        EdgeInsets.fromLTRB(
          hPad,
          LumenTokens.pagePaddingTop,
          hPad,
          bottomPadding ?? LumenTokens.pagePaddingBottom,
        );

    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LumenTokens.maxContentWidth),
      child: Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: _withSectionGaps(children),
        ),
      ),
    );

    final body = Align(
      alignment: Alignment.topCenter,
      child: scrollable
          ? SingleChildScrollView(
              controller: controller,
              child: column,
            )
          : column,
    );

    return ColoredBox(
      color: lumenScaffoldBackground(cs),
      child: body,
    );
  }

  List<Widget> _withSectionGaps(List<Widget> items) {
    if (items.isEmpty) return const <Widget>[];
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(const SizedBox(height: LumenTokens.sectionGap));
      }
    }
    return out;
  }
}
