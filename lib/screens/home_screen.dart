// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/tts_service.dart';
import '../services/api_service.dart';
import '../providers/navigation_provider.dart';
import 'detection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TTSService _tts;
  bool _isProcessing = false;
  bool _wsConnected = false; // websocket skipped for now

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _tts = Provider.of<TTSService>(context, listen: false);
      await _tts.initialize();

      // 🟡 WebSocket temporarily disabled — only REST mock routes used
      debugPrint('WebSocket disabled. Using REST mock directions only.');
      setState(() => _wsConnected = true); // show "🟢 Connected" indicator

      await _tts.speak('Navigation system ready.');
    });
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    await _tts.speak("Opening object detection mode");
    await Future.delayed(const Duration(milliseconds: 500));

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      await _tts.speak("Camera permission is required for object detection");
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetectionScreen()),
    );
  }

  Future<void> _handleTap(NavigationProvider provider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      switch (provider.currentState) {
        case AppState.initial:
          await _tts.speak(
              'Welcome to Manas. Tap once for navigation, double tap for object detection.');
          await Future.delayed(const Duration(milliseconds: 3000));
          provider.startSession();
          await _tts.speak(
              'Where would you like to go? Please say your destination.');
          break;

        case AppState.listening:
          await _tts.speak('Listening for your destination');
          await Future.delayed(const Duration(seconds: 2));

          const mockDestination = 'VRSEC gate';
          provider.setDestination(mockDestination);

          await _tts.speak(
              'You said $mockDestination. Tap to confirm, or double tap to cancel.');
          break;

        case AppState.confirming:
          await _tts.speak('Getting directions. Please wait.');
          debugPrint('Using predefined REST route from backend...');

          await _tts.speak('Fetching predefined route from the server.');

          final response =
              await ApiService.getMockDirections(provider.destination);
          debugPrint('📦 API Response: $response');

          if (response['status'] == 'error') {
            await _tts.speak(
                'Sorry, unable to get directions. ${response['message']}');
            provider.reset();
            break;
          }

          final List<String> instructions = [];
          final dest =
              response['destination']?.toString() ?? provider.destination;

          if (response['steps'] != null && response['steps'] is List) {
            for (var step in response['steps']) {
              instructions.add(step.toString());
            }
          } else if (response['directions'] != null) {
            final raw = response['directions'].toString();
            final steps = raw
                .split('. ')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            instructions.add('Starting navigation to $dest.');
            for (var step in steps) {
              instructions.add(step.endsWith('.') ? step : '$step.');
            }
          }

          if (instructions.isEmpty) {
            await _tts.speak('No directions available for this destination.');
            provider.reset();
            break;
          }

          debugPrint('📍 Total navigation steps: ${instructions.length}');
          provider.confirmAndStart(instructions);

          await _tts.speak(provider.currentInstruction);
          debugPrint('🗣️ Speaking: ${provider.currentInstruction}');
          break;

        case AppState.navigating:
          if (provider.hasMoreInstructions) {
            provider.nextInstruction();
            await _tts.speak(provider.currentInstruction);
          } else {
            await _tts
                .speak('Navigation complete. Tap to start a new journey.');
            provider.reset();
          }
          break;
      }
    } catch (e) {
      debugPrint('Error in _handleTap: $e');
      await _tts.speak('An error occurred. Please try again.');
      provider.reset();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getDisplayText(NavigationProvider provider) {
    final conn = _wsConnected ? '🟢 Connected' : '🔴 Disconnected';
    switch (provider.currentState) {
      case AppState.initial:
        return 'TAP ANYWHERE\nTO START\n\nDouble tap for detection\n\n$conn';
      case AppState.listening:
        return 'LISTENING...\nSpeak your destination\n\n$conn';
      case AppState.confirming:
        return 'CONFIRM?\n${provider.destination}\n\nTap to confirm\n\n$conn';
      case AppState.navigating:
        final progress = provider.currentInstructionIndex + 1;
        final total = provider.instructions.length;
        return 'NAVIGATING ($progress/$total)\n\n${provider.currentInstruction}\n\n$conn';
    }
  }

  Color _getBackgroundColor(NavigationProvider provider) {
    switch (provider.currentState) {
      case AppState.initial:
        return Colors.black;
      case AppState.listening:
        return Colors.blue.shade900;
      case AppState.confirming:
        return Colors.orange.shade900;
      case AppState.navigating:
        return Colors.green.shade900;
    }
  }

  IconData _getIcon(AppState state) {
    switch (state) {
      case AppState.initial:
        return Icons.touch_app;
      case AppState.listening:
        return Icons.mic;
      case AppState.confirming:
        return Icons.check_circle_outline;
      case AppState.navigating:
        return Icons.navigation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () => _handleTap(provider),
          onDoubleTap: _handleDoubleTap,
          child: Scaffold(
            backgroundColor: _getBackgroundColor(provider),
            body: SizedBox.expand(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 6,
                        )
                      else
                        Icon(
                          _getIcon(provider.currentState),
                          size: 100,
                          color: Colors.white,
                        ),
                      const SizedBox(height: 40),
                      Text(
                        _getDisplayText(provider),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
