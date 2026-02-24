import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show isDesktop, isAndroid;
import '../providers/chat_provider.dart';
import 'chat_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  int _androidNavIndex = 0;
  String _currentPage = 'chat';

  @override
  void initState() {
    super.initState();
    if (isDesktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroidLayout(context);
    return _buildDesktopLayout(context);
  }

  // ─── Android: Material 3 layout ───
  Widget _buildAndroidLayout(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    final pages = <Widget>[
      const ChatPage(),
      const SettingsPage(),
      const AboutPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: cs.surfaceTint,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.smart_toy_outlined, size: 18, color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            Text('NexAI', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: cs.onSurface)),
          ],
        ),
        actions: [
          if (_androidNavIndex == 0) ...[
            IconButton(
              icon: Icon(Icons.add_rounded, color: cs.onSurfaceVariant),
              onPressed: () => chat.newConversation(),
              tooltip: 'New chat',
            ),
            IconButton(
              icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
              onPressed: () => _showConversationSheet(context),
              tooltip: 'Conversations',
            ),
          ],
        ],
      ),
      body: pages[_androidNavIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _androidNavIndex,
        onDestinationSelected: (i) => setState(() => _androidNavIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat_rounded), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.info_outline_rounded), selectedIcon: Icon(Icons.info_rounded), label: 'About'),
        ],
      ),
    );
  }

  void _showConversationSheet(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.chat_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text('Conversations', style: Theme.of(ctx).textTheme.titleMedium),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: chat.conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: cs.outlineVariant),
                              const SizedBox(height: 12),
                              Text('No conversations yet', style: TextStyle(color: cs.outline)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: chat.conversations.length,
                          itemBuilder: (_, idx) {
                            final conv = chat.conversations[idx];
                            final isActive = idx == chat.currentIndex;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              selected: isActive,
                              selectedTileColor: cs.secondaryContainer,
                              leading: Icon(
                                isActive ? Icons.chat_rounded : Icons.chat_outlined,
                                color: isActive ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                                size: 20,
                              ),
                              title: Text(
                                conv.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  color: isActive ? cs.onSecondaryContainer : cs.onSurface,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: cs.outline),
                                onPressed: () {
                                  chat.deleteConversation(idx);
                                  if (chat.conversations.isEmpty) Navigator.of(ctx).pop();
                                },
                              ),
                              onTap: () {
                                chat.selectConversation(idx);
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Desktop: Fluent UI layout ───
  int _resolveSelectedIndex(int convCount, int chatIndex) {
    switch (_currentPage) {
      case 'settings':
        return convCount;
      case 'about':
        return convCount + 1;
      default:
        if (convCount == 0) return 0; // fallback to first footer item
        return chatIndex.clamp(0, convCount - 1);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final theme = fluent.FluentTheme.of(context);

    final conversationItems = chat.conversations.asMap().entries.map((entry) {
      final idx = entry.key;
      final conv = entry.value;
      return fluent.PaneItem(
        icon: const Icon(fluent.FluentIcons.chat),
        title: Text(conv.title, overflow: TextOverflow.ellipsis),
        body: const ChatPage(),
        trailing: fluent.IconButton(
          icon: Icon(fluent.FluentIcons.delete, size: 12, color: theme.inactiveColor),
          onPressed: () {
            chat.deleteConversation(idx);
            setState(() {});
          },
        ),
      );
    }).toList();

    final convCount = conversationItems.length;

    // When no conversations exist and page is 'chat', show settings as fallback
    int selected;
    if (convCount == 0 && _currentPage == 'chat') {
      selected = 0; // first footer item (settings)
    } else {
      selected = _resolveSelectedIndex(convCount, chat.currentIndex);
    }

    Widget titleWidget = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          const Icon(fluent.FluentIcons.robot, size: 20),
          const SizedBox(width: 10),
          const Text('NexAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );

    if (isDesktop) {
      titleWidget = fluent.DragToMoveArea(child: titleWidget);
    }

    return fluent.NavigationView(
      appBar: fluent.NavigationAppBar(
        automaticallyImplyLeading: false,
        title: titleWidget,
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            fluent.IconButton(
              icon: const Icon(fluent.FluentIcons.add, size: 14),
              onPressed: () {
                chat.newConversation();
                setState(() => _currentPage = 'chat');
              },
            ),
            if (isDesktop) ...[
              const SizedBox(width: 4),
              const WindowButtons(),
            ],
          ],
        ),
      ),
      pane: fluent.NavigationPane(
        selected: selected,
        onChanged: (index) {
          setState(() {
            if (index < convCount) {
              _currentPage = 'chat';
              chat.selectConversation(index);
            } else if (index == convCount) {
              _currentPage = 'settings';
            } else {
              _currentPage = 'about';
            }
          });
        },
        displayMode: fluent.PaneDisplayMode.compact,
        items: [
          fluent.PaneItemHeader(header: const Text('Conversations')),
          ...conversationItems,
        ],
        footerItems: [
          fluent.PaneItemSeparator(),
          fluent.PaneItem(
            icon: const Icon(fluent.FluentIcons.settings),
            title: const Text('Settings'),
            body: const SettingsPage(),
          ),
          fluent.PaneItem(
            icon: const Icon(fluent.FluentIcons.info),
            title: const Text('About'),
            body: const AboutPage(),
          ),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return Row(
      children: [
        fluent.IconButton(
          icon: Icon(fluent.FluentIcons.chrome_minimize, size: 12, color: theme.inactiveColor),
          onPressed: () => windowManager.minimize(),
        ),
        fluent.IconButton(
          icon: Icon(fluent.FluentIcons.chrome_full_screen, size: 12, color: theme.inactiveColor),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        fluent.IconButton(
          icon: Icon(fluent.FluentIcons.chrome_close, size: 12, color: theme.inactiveColor),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
