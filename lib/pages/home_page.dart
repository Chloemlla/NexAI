import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show isDesktop;
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
  // Navigation targets: 'chat', 'settings', 'about'
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

  /// Compute the flat selected index from _currentPage + chat.currentIndex.
  /// items: [PaneItemHeader(skip), ...N conversations]  → selectable indices 0..N-1
  /// footerItems: [PaneItemSeparator(skip), Settings, About] → selectable indices N, N+1
  int _resolveSelectedIndex(int convCount, int chatIndex) {
    switch (_currentPage) {
      case 'settings':
        return convCount; // first footer selectable
      case 'about':
        return convCount + 1; // second footer selectable
      default: // 'chat'
        if (convCount == 0) return -1; // nothing to select
        return chatIndex.clamp(0, convCount - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final theme = FluentTheme.of(context);
    final mediaQuery = MediaQuery.of(context);

    final conversationItems = chat.conversations.asMap().entries.map((entry) {
      final idx = entry.key;
      final conv = entry.value;
      return PaneItem(
        icon: const Icon(FluentIcons.chat),
        title: Text(conv.title, overflow: TextOverflow.ellipsis),
        body: const ChatPage(),
        trailing: IconButton(
          icon: Icon(FluentIcons.delete, size: 12, color: theme.inactiveColor),
          onPressed: () {
            chat.deleteConversation(idx);
            // Stay on chat page; provider already adjusts currentIndex
            setState(() {});
          },
        ),
      );
    }).toList();

    final convCount = conversationItems.length;
    final selected = _resolveSelectedIndex(convCount, chat.currentIndex);

    Widget titleWidget = const Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          Icon(FluentIcons.robot, size: 20),
          SizedBox(width: 10),
          Text('NexAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );

    if (isDesktop) {
      titleWidget = DragToMoveArea(child: titleWidget);
    }

    Widget body = NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: titleWidget,
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.add, size: 14),
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
      pane: NavigationPane(
        selected: selected >= 0 ? selected : null,
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
        displayMode: PaneDisplayMode.compact,
        items: [
          PaneItemHeader(header: const Text('Conversations')),
          ...conversationItems,
        ],
        footerItems: [
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: const SettingsPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.info),
            title: const Text('About'),
            body: const AboutPage(),
          ),
        ],
      ),
    );

    // Edge-to-edge safe area padding for Android
    if (!isDesktop && mediaQuery.padding.bottom > 0) {
      body = MediaQuery(
        data: mediaQuery,
        child: body,
      );
    }

    return body;
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(FluentIcons.chrome_minimize, size: 12, color: theme.inactiveColor),
          onPressed: () => windowManager.minimize(),
        ),
        IconButton(
          icon: Icon(FluentIcons.chrome_full_screen, size: 12, color: theme.inactiveColor),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        IconButton(
          icon: Icon(FluentIcons.chrome_close, size: 12, color: theme.inactiveColor),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
