import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final Duration _gapBetweenSpeeches =
      const Duration(milliseconds: 600); // delay between speeches
  final _queue = <String>[]; // queue for queued messages

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    try {
      await _tts
          .setVoice({"name": "en-us-x-sfg#male_1-local", "locale": "en-US"});
    } catch (_) {}

    _tts.setCompletionHandler(() async {
      _isSpeaking = false;
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        await Future.delayed(_gapBetweenSpeeches);
        await speak(next);
      }
    });

    _isInitialized = true;
  }

  /// Queues and speaks text safely (no overlapping)
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await initialize();

    if (_isSpeaking) {
      _queue.add(text);
      return;
    }

    _isSpeaking = true;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _queue.clear();
    _isSpeaking = false;
    await _tts.stop();
  }

  void dispose() {
    _queue.clear();
    _tts.stop();
  }
}
