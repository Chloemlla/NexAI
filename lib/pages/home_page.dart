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
  int _selectedIndex = 0;

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
          onPressed: () => chat.deleteConversation(idx),
        ),
        onTap: () {
          chat.selectConversation(idx);
          setState(() => _selectedIndex = idx);
        },
      );
    }).toList();

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
                setState(() => _selectedIndex = 0);
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
        selected: _selectedIndex < conversationItems.length ? _selectedIndex : null,
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
            onTap: () {
              setState(() => _selectedIndex = conversationItems.length);
            },
          ),
          PaneItem(
            icon: const Icon(FluentIcons.info),
            title: const Text('About'),
            body: const AboutPage(),
            onTap: () {
              setState(() => _selectedIndex = conversationItems.length + 1);
            },
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
