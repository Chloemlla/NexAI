import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexai/models/note.dart';
import 'package:nexai/pages/note_detail_page.dart';
import 'package:nexai/providers/notes_provider.dart';
import 'package:nexai/providers/settings_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Route path_provider through a mocked channel backed by a temp dir so
    // real file I/O stays off the user's documents folder.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<NotesProvider> makeProvider() async {
    final provider = NotesProvider();
    await provider.restoreFromList([
      Note(
        id: 'n1',
        title: 'A very long note title to stress the header layout',
        content: '''
# 标题
#project/web #meeting #long-tag-name-here
- [ ] 任务一
- [x] 任务二
- [ ] 任务三

Some body text.
''',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toJson(),
    ]);
    return provider;
  }

  Future<double> bottomBarHeightAt(
    WidgetTester tester,
    NotesProvider notes,
    double textScale,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) => captured.add(details);
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotesProvider>.value(value: notes),
            ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                textScaler: TextScaler.linear(textScale),
              ),
              child: NoteDetailPage(noteId: 'n1'),
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    FlutterError.onError = oldHandler;
    for (final d in captured) {
      debugPrint('CAPTURED-ERROR@$textScale:\n${d.toString()}');
    }
    expect(tester.takeException(), isNull);
    return tester.getSize(find.byKey(const Key('noteBottomBar'))).height;
  }

  testWidgets(
    'note detail bars size to content instead of fixed heights',
    (tester) async {
      final notes = (await tester.runAsync(makeProvider))!;

      final h1 = await bottomBarHeightAt(tester, notes, 1.0);
      final h2 = await bottomBarHeightAt(tester, notes, 2.0);

      // Content-based sizing: at large text scale the bottom bar grows.
      expect(h2, greaterThan(h1));

      // Toolbar and tags bar render without layout exceptions at large scale.
      expect(find.byKey(const Key('noteToolbar')), findsOneWidget);
      expect(find.byKey(const Key('noteTagsBar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
