/// Speech helpers for chat STT/TTS (Phase 2).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatSpeechService {
  ChatSpeechService();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  bool _ttsReady = false;

  bool get isListening => _speech.isListening;

  Future<bool> ensureSpeech() async {
    if (_speechReady) return true;
    try {
      _speechReady = await _speech.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _speechReady = false;
    }
    return _speechReady;
  }

  Future<bool> ensureTts() async {
    if (_ttsReady) return true;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsReady = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      _ttsReady = false;
    }
    return _ttsReady;
  }

  Future<void> startListening({
    required void Function(String text, bool finalResult) onResult,
    String localeId = 'zh_CN',
  }) async {
    final ok = await ensureSpeech();
    if (!ok) {
      throw StateError('语音识别不可用');
    }
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  Future<void> speak(String text) async {
    final ok = await ensureTts();
    if (!ok) throw StateError('语音播报不可用');
    final clipped = text.trim();
    if (clipped.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clipped.length > 800 ? clipped.substring(0, 800) : clipped);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
