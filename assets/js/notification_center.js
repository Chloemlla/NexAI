// In-app notification queue, ported from Happy-TTS Notification.tsx and run
// inside the embedded QuickJS runtime on Android. A pure-Dart mirror
// (FallbackNexNotificationEngine) keeps identical semantics on web/tests.
//
// Commands are invoked by evaluating NexNotifyCenter.<fn>(...); Dart then
// reads NexNotifyCenter.snapshot() as the authoritative queue. Countdown
// expiry is driven by Dart-side Timers calling expire(id), so no JS timers
// are needed here.
var NexNotifyCenter = (function () {
  'use strict';

  var items = []; // newest first
  var seq = 0;
  var DEFAULT_DURATION = 3000;

  function now() {
    return Date.now();
  }

  function normalizeDuration(value) {
    var ms = Number(value);
    if (!isFinite(ms) || ms <= 0) return DEFAULT_DURATION;
    return Math.min(Math.round(ms), 60000);
  }

  function isType(value) {
    return (
      value === 'success' ||
      value === 'error' ||
      value === 'warning' ||
      value === 'info'
    );
  }

  function push(payload) {
    var data =
      typeof payload === 'string' ? JSON.parse(payload) : payload || {};
    var duration = normalizeDuration(data.duration);
    var item = {
      id: ++seq,
      type: isType(data.type) ? data.type : 'info',
      title: typeof data.title === 'string' ? data.title : '',
      message: typeof data.message === 'string' ? data.message : '通知',
      details: Array.isArray(data.details)
        ? data.details.filter(function (d) {
            return typeof d === 'string';
          })
        : [],
      duration: duration,
      start: now(),
      faded: false,
      paused: false,
      remaining: duration
    };
    for (var i = 0; i < items.length; i++) {
      items[i].faded = true;
    }
    items.unshift(item);
    return JSON.stringify({
      id: item.id,
      start: item.start,
      duration: item.duration
    });
  }

  function remove(id) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].id === id) {
        items.splice(i, 1);
        return true;
      }
    }
    return false;
  }

  function expire(id) {
    return remove(id);
  }

  function dismiss(id) {
    return remove(id);
  }

  function pause(id) {
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.id === id && !it.paused) {
        var elapsed = now() - it.start;
        it.remaining = Math.max(0, it.duration - elapsed);
        it.paused = true;
        return true;
      }
    }
    return false;
  }

  function resume(id) {
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.id === id && it.paused) {
        it.start = now() - (it.duration - it.remaining);
        it.paused = false;
        return true;
      }
    }
    return false;
  }

  function snapshot() {
    return JSON.stringify(items);
  }

  return {
    push: push,
    expire: expire,
    dismiss: dismiss,
    pause: pause,
    resume: resume,
    snapshot: snapshot
  };
})();
