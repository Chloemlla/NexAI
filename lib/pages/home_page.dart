import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show isDesktop, isAndroid;
import '../models/message.dart';
import '../models/search_result.dart';
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/update_checker.dart';
import '../utils/navigation_helper.dart';
import '../utils/app_security.dart';
import '../utils/security_status_checker.dart';
import '../utils/security_headers_interceptor.dart';
import '../services/nexai_security_service.dart';
import 'chat_page.dart';
import 'notes_page.dart';
import 'note_detail_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'graph_page.dart';
import 'tools_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  int _androidNavIndex = 0;
  String _currentPage = 'chat';
  SecurityStatusChecker? _securityChecker;
  final TextEditingController _desktopConversationSearchController =
      TextEditingController();
  String _desktopConversationSearchQuery = '';

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
      _checkIntegrity();
      _startSecurityStatusCheck();
    });
  }

  void _startSecurityStatusCheck() {
    try {
      // Create security service with secure Dio
      final dio = createSecureDio();
      final service = NexAISecurityService(dio);
      _securityChecker = SecurityStatusChecker(service);

      // Start periodic check (every 30 minutes)
      _securityChecker?.startPeriodicCheck(
        interval: const Duration(minutes: 30),
        context: context,
      );
    } catch (e) {
      debugPrint('Failed to start security status check: $e');
    }
  }

  void _checkIntegrity() {
    final security = AppSecurity.instance;

    // Show warning if APK integrity check failed
    if (!security.isApkHashValid && isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showIntegrityWarning();
        }
      });
    }
  }

  void _showIntegrityWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('安全警告'),
          ],
        ),
        content: const Text(
          'APK 完整性验证失败。安装的应用可能已被修改。\n\n'
          '为了您的安全，请从 GitHub 下载官方版本。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('忽略'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await UpdateChecker.openLatestReleasePage();
            },
            child: const Text('下载官方版本'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (isDesktop) windowManager.removeListener(this);
    _desktopConversationSearchController.dispose();
    NavigationHelper.navigateToSettings = null; // Clean up callback
    _securityChecker?.dispose();
    super.dispose();
  }

  Future<bool> _confirmDeleteConversation(
    BuildContext context,
    Conversation conversation,
    ColorScheme colorScheme,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            title: const Text('删除对话'),
            content: Text('确认删除 “${conversation.title}”？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _matchesConversationSearch(Conversation conversation) {
    final query = _desktopConversationSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final lastMessage = conversation.messages.isNotEmpty
        ? conversation.messages.last.content
        : '';
    final haystack = '${conversation.title}\n$lastMessage'.toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroid) return _buildAndroidLayout(context);
    return _buildDesktopLayout(context);
  }

  int get _desktopPageIndex {
    switch (_currentPage) {
      case 'notes':
        return 1;
      case 'tools':
        return 2;
      case 'settings':
        return 3;
      case 'about':
        return 4;
      default:
        return 0;
    }
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
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: _androidNavIndex == 0
                            ? Image.asset(
                                'assets/icon.png',
                                width: 32,
                                height: 32,
                              )
                            : Icon(
                                _androidNavIndex == 1
                                    ? Icons.note_alt_rounded
                                    : _androidNavIndex == 2
                                    ? Icons.build_rounded
                                    : Icons.settings_rounded,
                                size: 24,
                                color: cs.primary,
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
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (_androidNavIndex == 0) ...[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await chat.newConversation();
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
                    onPressed: () async {
                      final note = await context
                          .read<NotesProvider>()
                          .createNote();
                      if (!context.mounted) return;
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
                  IconButton(
                    icon: Icon(Icons.hub_rounded, color: cs.onSurfaceVariant),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GraphPage()),
                      );
                    },
                    tooltip: '知识图谱',
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
      body: Stack(
        children: [
          IndexedStack(index: _androidNavIndex, children: pages),
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
                                  letterSpacing: 0,
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
                onPressed: () async {
                  await chat.newConversation();
                  if (!ctx.mounted) return;
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
          onDismissed: (_) async {
            await chat.deleteConversation(idx);
            if (!ctx.mounted) return;
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

  // ─── Desktop: Material Design NavigationRail layout ───
  Widget _buildDesktopLayout(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const pages = <Widget>[
      ChatPage(),
      NotesPage(),
      ToolsPage(),
      SettingsPage(),
      AboutPage(),
    ];
    final filteredConversationEntries = chat.conversations
        .asMap()
        .entries
        .where((entry) => _matchesConversationSearch(entry.value))
        .toList();

    Widget titleWidget = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          Image.asset('assets/icon.png', width: 28, height: 28),
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

    return Scaffold(
      body: Column(
        children: [
          // Custom title bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withAlpha(60)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(child: titleWidget),
                // Conversation actions
                if (_currentPage == 'chat') ...[
                  IconButton(
                    icon: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () async {
                      await chat.newConversation();
                      setState(() => _currentPage = 'chat');
                    },
                    tooltip: '新建对话',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (isDesktop) ...[
                  const SizedBox(width: 4),
                  const WindowButtons(),
                ],
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Row(
              children: [
                // NavigationRail + conversation list
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerLow
                        : cs.surfaceContainerLowest,
                    border: Border(
                      right: BorderSide(color: cs.outlineVariant.withAlpha(60)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '对话',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer.withAlpha(140),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${chat.conversations.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    await chat.newConversation();
                                    if (!mounted) return;
                                    setState(() {
                                      _currentPage = 'chat';
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('新建'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _desktopConversationSearchController,
                              onChanged: (value) {
                                setState(() {
                                  _desktopConversationSearchQuery = value;
                                });
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '搜索对话或最后一条消息',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                ),
                                suffixIcon:
                                    _desktopConversationSearchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '清空搜索',
                                        onPressed: () {
                                          _desktopConversationSearchController
                                              .clear();
                                          setState(() {
                                            _desktopConversationSearchQuery =
                                                '';
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: chat.conversations.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: cs.onSurfaceVariant,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '还没有对话',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '从这里开始一个新的聊天。',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : filteredConversationEntries.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        color: cs.outline,
                                        size: 30,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '没有匹配结果',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextButton(
                                        onPressed: () {
                                          _desktopConversationSearchController
                                              .clear();
                                          setState(() {
                                            _desktopConversationSearchQuery =
                                                '';
                                          });
                                        },
                                        child: const Text('清空搜索'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                itemCount: filteredConversationEntries.length,
                                itemBuilder: (context, entryIndex) {
                                  final entry =
                                      filteredConversationEntries[entryIndex];
                                  final idx = entry.key;
                                  final conv = entry.value;
                                  final isActive =
                                      _currentPage == 'chat' &&
                                      idx == chat.currentIndex;
                                  final preview = conv.messages.isNotEmpty
                                      ? conv.messages.last.content
                                      : '还没有消息';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: ListTile(
                                      dense: true,
                                      minLeadingWidth: 0,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      selected: isActive,
                                      selectedTileColor: cs.secondaryContainer
                                          .withAlpha(180),
                                      leading: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          gradient: isActive
                                              ? LinearGradient(
                                                  colors: [
                                                    cs.primary,
                                                    cs.tertiary,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isActive
                                              ? null
                                              : cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isActive
                                              ? Icons.chat_rounded
                                              : Icons.chat_outlined,
                                          size: 18,
                                          color: isActive
                                              ? cs.onPrimary
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                      title: Text(
                                        conv.title,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          preview,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: isActive
                                                ? cs.onSecondaryContainer
                                                : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        tooltip: '删除对话',
                                        onPressed: () async {
                                          final confirmed =
                                              await _confirmDeleteConversation(
                                                context,
                                                conv,
                                                cs,
                                              );
                                          if (!confirmed || !mounted) return;

                                          await chat.deleteConversation(idx);
                                        },
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _currentPage = 'chat';
                                          chat.selectConversation(idx);
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Footer nav items
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: _currentPage == 'notes',
                        selectedTileColor: cs.secondaryContainer.withAlpha(180),
                        leading: Icon(
                          _currentPage == 'notes'
                              ? Icons.note_alt_rounded
                              : Icons.note_alt_outlined,
                          size: 20,
                          color: _currentPage == 'notes'
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: const Text('笔记', style: TextStyle(fontSize: 13)),
                        onTap: () => setState(() => _currentPage = 'notes'),
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: _currentPage == 'tools',
                        selectedTileColor: cs.secondaryContainer.withAlpha(180),
                        leading: Icon(
                          _currentPage == 'tools'
                              ? Icons.build_rounded
                              : Icons.build_outlined,
                          size: 20,
                          color: _currentPage == 'tools'
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: const Text('工具', style: TextStyle(fontSize: 13)),
                        onTap: () => setState(() => _currentPage = 'tools'),
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: _currentPage == 'settings',
                        selectedTileColor: cs.secondaryContainer.withAlpha(180),
                        leading: Icon(
                          _currentPage == 'settings'
                              ? Icons.settings_rounded
                              : Icons.settings_outlined,
                          size: 20,
                          color: _currentPage == 'settings'
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: const Text('设置', style: TextStyle(fontSize: 13)),
                        onTap: () => setState(() => _currentPage = 'settings'),
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: _currentPage == 'about',
                        selectedTileColor: cs.secondaryContainer.withAlpha(180),
                        leading: Icon(
                          _currentPage == 'about'
                              ? Icons.info_rounded
                              : Icons.info_outline_rounded,
                          size: 20,
                          color: _currentPage == 'about'
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        title: const Text('关于', style: TextStyle(fontSize: 13)),
                        onTap: () => setState(() => _currentPage = 'about'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Page body
                Expanded(
                  child: IndexedStack(
                    index: _desktopPageIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.minimize_rounded,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          onPressed: () => windowManager.minimize(),
          visualDensity: VisualDensity.compact,
          tooltip: '最小化',
        ),
        IconButton(
          icon: Icon(
            Icons.crop_square_rounded,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          visualDensity: VisualDensity.compact,
          tooltip: '最大化',
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 16, color: cs.onSurfaceVariant),
          onPressed: () => windowManager.close(),
          visualDensity: VisualDensity.compact,
          tooltip: '关闭',
        ),
      ],
    );
  }
}
