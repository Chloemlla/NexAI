import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart' show isDesktop, isAndroid;
import '../providers/chat_provider.dart';
import '../providers/notes_provider.dart';
import 'chat_page.dart';
import 'notes_page.dart';
import 'note_detail_page.dart';
import 'graph_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  int _navIndex = 0;

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
    final cs = Theme.of(context).colorScheme;

    final pages = <Widget>[
      const ChatPage(),
      const NotesPage(),
      const SettingsPage(),
      const AboutPage(),
    ];

    final pageTitles = ['NexAI', 'Notes', 'Settings', 'About'];
