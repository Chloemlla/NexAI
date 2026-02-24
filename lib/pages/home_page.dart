import 'package:fluent_ui/fluent_ui.dart';
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

  int _resolveSelectedIndex(int convCount, int chatIndex) {
    switch (_currentPage) {
      case 'settings':
        return convCount;
      case 'about':
        return convCount + 1;
      default:
        if (convCount == 0) return -1;
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
        displayMode: isAndroid ? PaneDisplayMode.minimal : PaneDisplayMode.compact,
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

    // Wrap with SafeArea for Android edge-to-edge
    if (isAndroid) {
      body = SafeArea(
        bottom: false, // bottom handled per-page for input area
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
