import 'package:flutter/material.dart';

import 'lumen_page.dart';
import 'lumen_scaffold_background.dart';

/// Lumen secondary-page chrome: soft scaffold + surface AppBar + [LumenPage] body.
///
/// Mirrors Project-Lumen secondary screens (e.g. DeveloperDebugScreen):
/// plain top bar, soft background, max-width centered content with section gap.
class LumenSecondaryScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool scrollable;
  final ScrollController? controller;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottom;
  final CrossAxisAlignment crossAxisAlignment;

  const LumenSecondaryScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.scrollable = true,
    this.controller,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottom,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: lumenScaffoldBackground(cs),
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        bottom: bottom,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: LumenPage(
        controller: controller,
        scrollable: scrollable,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }
}
