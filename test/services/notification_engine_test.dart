import 'package:flutter_test/flutter_test.dart';

import 'package:nexai/services/notification_engine_fallback.dart';
import 'package:nexai/services/notification_models.dart';

void main() {
  group('FallbackNexNotificationEngine', () {
    late FallbackNexNotificationEngine engine;
    late List<List<NexNotification>> snapshots;

    setUp(() {
      engine = FallbackNexNotificationEngine();
      snapshots = <List<NexNotification>>[];
      engine.onSnapshot(snapshots.add);
    });

    test('push emits newest-first and fades existing items', () {
      engine.push(NexNotifyData(message: 'first'));
      engine.push(
        NexNotifyData(
          message: 'second',
          type: NexNotifyType.error,
          title: 'title',
        ),
      );

      final latest = snapshots.last;
      expect(latest, hasLength(2));
      expect(latest.first.message, 'second');
      expect(latest.first.type, NexNotifyType.error);
      expect(latest.first.title, 'title');
      expect(latest.first.faded, isFalse);
      expect(latest.last.message, 'first');
      expect(latest.last.faded, isTrue);
    });

    test('details are carried into the snapshot', () {
      engine.push(
        NexNotifyData(message: 'm', details: const ['a', 'b']),
      );
      expect(snapshots.last.single.details, <String>['a', 'b']);
    });

    test('expire removes the item', () {
      engine.push(NexNotifyData(message: 'm'));
      final id = snapshots.last.single.id;
      engine.expire(id);
      expect(snapshots.last, isEmpty);
    });

    test('dismiss removes the item', () {
      engine.push(NexNotifyData(message: 'm'));
      final id = snapshots.last.single.id;
      engine.dismiss(id);
      expect(snapshots.last, isEmpty);
    });

    test('pause freezes the countdown and resume restarts it', () {
      engine.push(NexNotifyData(message: 'm'));
      final item = snapshots.last.single;

      engine.pause(item.id);
      final paused = snapshots.last.single;
      expect(paused.paused, isTrue);
      expect(paused.remaining, lessThanOrEqualTo(paused.duration));

      engine.resume(item.id);
      final resumed = snapshots.last.single;
      expect(resumed.paused, isFalse);
      expect(resumed.start, greaterThanOrEqualTo(item.start));
    });

    test('pause on a foreign id is a no-op', () {
      engine.push(NexNotifyData(message: 'm'));
      final before = snapshots.length;
      engine.pause(999);
      expect(snapshots.length, before);
    });
  });
}
