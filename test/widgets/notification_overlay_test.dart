import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexai/services/nex_notify.dart';
import 'package:nexai/services/notification_models.dart';
import 'package:nexai/widgets/notification/notification_overlay.dart';

void main() {
  Widget host() => MaterialApp(
        home: const Scaffold(body: SizedBox()),
        builder: (context, child) => NotificationOverlay(child: child!),
      );

  testWidgets('shows a card and auto-dismisses after the duration',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    NexNotify.show('hello', type: NexNotifyType.success);
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);

    // The default 3s countdown elapses; the card animates out and is removed.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('renders title, details and the close button', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    NexNotify.show(
      'main message',
      title: 'the title',
      details: const ['detail one', 'detail two'],
    );
    await tester.pump();

    expect(find.text('the title'), findsOneWidget);
    expect(find.text('main message'), findsOneWidget);
    expect(find.text('detail one'), findsOneWidget);
    expect(find.text('detail two'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a new notification is stacked above and fades the older one',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    NexNotify.show('older');
    await tester.pump();
    NexNotify.show('newer');
    await tester.pump();

    expect(find.text('newer'), findsOneWidget);
    expect(find.text('older'), findsOneWidget);

    // Verify stacking order by vertical position.
    final newerY = tester.getTopLeft(find.text('newer')).dy;
    final olderY = tester.getTopLeft(find.text('older')).dy;
    expect(newerY, lessThan(olderY));

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('close button dismisses the card immediately', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    NexNotify.show('bye');
    await tester.pump();
    expect(find.text('bye'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bye'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('long-press pauses and releasing resumes the countdown',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    NexNotify.show('pausable');
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('pausable')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('悬停暂停 · Hover to pause'), findsOneWidget);
    await gesture.up();
    await tester.pump();

    // After resume the hint is gone and the card still auto-dismisses.
    expect(find.text('悬停暂停 · Hover to pause'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('pausable'), findsNothing);
  });
}
