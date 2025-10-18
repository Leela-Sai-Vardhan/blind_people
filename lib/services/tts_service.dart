import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // slower for clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Android-specific voice (safe fallback if unavailable)
    try {
      await _tts
          .setVoice({"name": "en-us-x-sfg#male_1-local", "locale": "en-US"});
    } catch (_) {}

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await initialize();
    await _tts.stop(); // avoid overlap
    await _tts.speak(text);
  }

  Future<void> stop() async => await _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
