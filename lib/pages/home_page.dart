import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show isDesktop, isAndroid;
import '../models/search_result.dart';
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/update_checker.dart';
import '../utils/navigation_helper.dart';
import 'chat_page.dart';
import 'notes_page.dart';
import 'note_detail_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'tools_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  int _androidNavIndex = 0;
  String _currentPage = 'chat';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure navigation callback is set up
    NavigationHelper.navigateToSettings = () {
      setState(() {
        if (isAndroid) {
          _androidNavIndex = 3; // Settings tab index
        } else {
          _currentPage = 'settings';
        }
      });
    };
  }

  @override
  void initState() {
    super.initState();
    if (isDesktop) windowManager.addListener(this);

    // Check for updates on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkUpdateOnStart(context);
    });
  }

  @override
  void dispose() {
    if (isDesktop) windowManager.removeListener(this);
    NavigationHelper.navigateToSettings = null; // Clean up callback
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
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    final pages = <Widget>[
      const ChatPage(),
      const NotesPage(),
      const ToolsPage(),
      const SettingsPage(),
    ];

    final pageTitles = ['NexAI', '笔记', '工具', '设置'];
    final isChat = _androidNavIndex == 0;
    final fullScreen = settings.fullScreenMode && isChat;

    return Scaffold(
      appBar: fullScreen
          ? null
          : AppBar(
              surfaceTintColor: cs.surfaceTint,
              title: Row(
                children: [
                  Hero(
                    tag: 'app_icon',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _androidNavIndex == 0
                              ? Icons.smart_toy_rounded
                              : _androidNavIndex == 1
                              ? Icons.note_alt_rounded
                              : _androidNavIndex == 2
                              ? Icons.build_rounded
                              : Icons.settings_rounded,
                          size: 18,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      pageTitles[_androidNavIndex],
                      key: ValueKey(_androidNavIndex),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (_androidNavIndex == 0) ...[
                  FilledButton.tonalIcon(
                    onPressed: () {
                      chat.newConversation();
                      // Haptic feedback would go here on mobile
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新建'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Badge(
                    isLabelVisible: chat.conversations.length > 1,
                    label: Text('${chat.conversations.length}'),
                    child: IconButton(
                      icon: Icon(
                        Icons.history_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => _showConversationSheet(context),
                      tooltip: '对话历史',
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (_androidNavIndex == 1) ...[
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final note = context.read<NotesProvider>().createNote();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NoteDetailPage(noteId: note.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新建'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_androidNavIndex),
              child: pages[_androidNavIndex],
            ),
          ),
          if (fullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 10,
              child: FloatingActionButton.small(
                heroTag: 'exit_full_screen',
                onPressed: () => settings.setFullScreenMode(false),
                backgroundColor: cs.surfaceContainerHighest.withAlpha(150),
                elevation: 2,
                child: const Icon(Icons.fullscreen_exit_rounded),
              ),
            ),
          if (fullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: FloatingActionButton.small(
                heroTag: 'history_full_screen',
                onPressed: () => _showConversationSheet(context),
                backgroundColor: cs.surfaceContainerHighest.withAlpha(150),
                elevation: 2,
                child: const Icon(Icons.history_rounded),
              ),
            ),
        ],
      ),
      bottomNavigationBar: fullScreen
          ? null
          : NavigationBar(
              selectedIndex: _androidNavIndex,
              onDestinationSelected: (i) =>
                  setState(() => _androidNavIndex = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              animationDuration: const Duration(milliseconds: 400),
              elevation: 3,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_outlined),
                  selectedIcon: Icon(Icons.chat_rounded),
                  label: '聊天',
                ),
                NavigationDestination(
                  icon: Icon(Icons.note_alt_outlined),
                  selectedIcon: Icon(Icons.note_alt_rounded),
                  label: '笔记',
                ),
                NavigationDestination(
                  icon: Icon(Icons.build_outlined),
                  selectedIcon: Icon(Icons.build_rounded),
                  label: '工具',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: '设置',
                ),
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
      backgroundColor: cs.surfaceContainerLow,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                String searchQuery = '';
                List<SearchResult> searchResults = [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primaryContainer,
                                  cs.secondaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.history_rounded,
                                size: 20,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '对话',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withAlpha(120),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${chat.conversations.length}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Search Bar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索消息...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withAlpha(150),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          setSheetState(() {
                            searchQuery = v;
                            searchResults = chat.searchMessages(v);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: cs.outlineVariant.withAlpha(80)),
                    Expanded(
                      child: searchQuery.isEmpty
                          ? _buildConversationList(
                              chat,
                              cs,
                              scrollController,
                              ctx,
                            )
                          : _buildSearchResultsList(
                              searchResults,
                              searchQuery,
                              cs,
                              scrollController,
                              chat,
                              ctx,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildConversationList(
    ChatProvider chat,
    ColorScheme cs,
    ScrollController scrollController,
    BuildContext ctx,
  ) {
    if (chat.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.surfaceContainerHighest, cs.surfaceContainer],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: cs.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '还没有对话',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text('开始新的聊天', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  chat.newConversation();
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('新建对话'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chat.conversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (_, idx) {
        final conv = chat.conversations[idx];
        final isActive = idx == chat.currentIndex;
        return Dismissible(
          key: ValueKey('conv_$idx'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.delete_rounded, color: cs.onErrorContainer),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                    title: const Text('删除对话'),
                    content: Text('删除 "${conv.title}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) {
            chat.deleteConversation(idx);
            if (chat.conversations.isEmpty) Navigator.of(ctx).pop();
          },
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            selected: isActive,
            selectedTileColor: cs.secondaryContainer.withAlpha(180),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(colors: [cs.primary, cs.tertiary])
                    : null,
                color: isActive ? null : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  isActive ? Icons.chat_rounded : Icons.chat_outlined,
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              conv.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            subtitle: conv.messages.isNotEmpty
                ? Text(
                    conv.messages.last.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conv.messages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? cs.primary.withAlpha(40)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${conv.messages.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? cs.primary : cs.outline,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
            onTap: () {
              chat.selectConversation(idx);
              Navigator.of(ctx).pop();
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList(
    List<SearchResult> results,
    String query,
    ColorScheme cs,
    ScrollController scrollController,
    ChatProvider chat,
    BuildContext ctx,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            const Text(
              '未找到匹配的消息',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (_, idx) {
        final result = results[idx];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: cs.surfaceContainerHighest.withAlpha(100),
          title: Text(
            result.conversation.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: _highlightText(result.message.content, query, cs),
            ),
          ),
          onTap: () {
            chat.selectConversation(result.conversationIndex);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  TextSpan _highlightText(String content, String query, ColorScheme cs) {
    if (query.isEmpty) return TextSpan(text: content);
    final List<TextSpan> spans = [];
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOf;

    while ((indexOf = lowerContent.indexOf(lowerQuery, start)) != -1) {
      if (indexOf > start) {
        spans.add(
          TextSpan(
            text: content.substring(start, indexOf),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: content.substring(indexOf, indexOf + query.length),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.bold,
            backgroundColor: cs.primaryContainer.withAlpha(100),
          ),
        ),
      );
      start = indexOf + query.length;
    }
    if (start < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(start),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return TextSpan(children: spans);
  }

  // ─── Desktop: Fluent UI layout ───
  int _resolveSelectedIndex(int convCount, int chatIndex) {
    switch (_currentPage) {
      case 'settings':
        return convCount;
      case 'about':
        return convCount + 1;
      default:
        if (convCount == 0) {
          _currentPage = 'settings';
          return 0;
        }
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
          icon: Icon(
            fluent.FluentIcons.delete,
            size: 12,
            color: theme.inactiveColor,
          ),
          onPressed: () {
            chat.deleteConversation(idx);
            if (chat.conversations.isEmpty) {
              setState(() => _currentPage = 'settings');
            } else {
              setState(() {});
            }
          },
        ),
      );
    }).toList();

    final convCount = conversationItems.length;

    int selected;
    if (convCount == 0 && _currentPage == 'chat') {
      selected = 0;
    } else {
      selected = _resolveSelectedIndex(convCount, chat.currentIndex);
    }

    Widget titleWidget = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          const Icon(fluent.FluentIcons.robot, size: 20),
          const SizedBox(width: 10),
          const Text(
            'NexAI',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );

    if (isDesktop) {
      titleWidget = DragToMoveArea(child: titleWidget);
    }

    return fluent.NavigationView(
      titleBar: Row(
        children: [
          Expanded(child: titleWidget),
          fluent.IconButton(
            icon: const Icon(fluent.FluentIcons.add, size: 14),
            onPressed: () {
              chat.newConversation();
              setState(() => _currentPage = 'chat');
            },
          ),
          if (isDesktop) ...[const SizedBox(width: 4), const WindowButtons()],
        ],
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
          fluent.PaneItemHeader(header: const Text('对话')),
          ...conversationItems,
        ],
        footerItems: [
          fluent.PaneItemSeparator(),
          fluent.PaneItem(
            icon: const Icon(fluent.FluentIcons.settings),
            title: const Text('设置'),
            body: const SettingsPage(),
          ),
          fluent.PaneItem(
            icon: const Icon(fluent.FluentIcons.info),
            title: const Text('关于'),
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
          icon: Icon(
            fluent.FluentIcons.chrome_minimize,
            size: 12,
            color: theme.inactiveColor,
          ),
          onPressed: () => windowManager.minimize(),
        ),
        fluent.IconButton(
          icon: Icon(
            fluent.FluentIcons.chrome_full_screen,
            size: 12,
            color: theme.inactiveColor,
          ),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        fluent.IconButton(
          icon: Icon(
            fluent.FluentIcons.chrome_close,
            size: 12,
            color: theme.inactiveColor,
          ),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
