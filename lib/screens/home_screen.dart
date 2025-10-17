import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../providers/navigation_provider.dart';
import 'package:services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TTSService _tts;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts = Provider.of<TTSService>(context, listen: false);
      _tts.initialize();
    });
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _handleTap(NavigationProvider provider) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    switch (provider.currentState) {
      case AppState.initial:
        await _tts.speak("Welcome to Manas. Tap anywhere to continue.");
        await Future.delayed(const Duration(milliseconds: 3500));
        provider.startSession();
        await _tts
            .speak("Where would you like to go? Please say your destination.");
        break;

      case AppState.listening:
        // Simulate voice input for now (will be replaced with actual STT in next phase)
        await _tts.speak("Listening for your destination");
        await Future.delayed(const Duration(seconds: 2));

        // Mock destination (will be replaced with real speech-to-text)
        String mockDestination = "City Library";
        provider.setDestination(mockDestination);

        await _tts.speak(
            "You said $mockDestination. Tap to confirm, or double tap to cancel.");
        break;

      case AppState.confirming:
        // Mock navigation instructions (will be replaced with API call)
        List<String> mockInstructions = [
          "Starting navigation to ${provider.destination}",
          "Head north on Main Street for 200 meters",
          "Turn right onto Oak Avenue",
          "Continue straight for 500 meters",
          "Your destination is on the right",
          "You have arrived at ${provider.destination}"
        ];

        provider.confirmAndStart(mockInstructions);
        await _tts.speak(provider.currentInstruction);
        break;

      case AppState.navigating:
        if (provider.hasMoreInstructions) {
          provider.nextInstruction();
          await _tts.speak(provider.currentInstruction);
        } else {
          await _tts.speak("Navigation complete. Tap to start a new journey.");
          provider.reset();
        }
        break;
    }

    setState(() => _isProcessing = false);
  }

  String _getDisplayText(NavigationProvider provider) {
    switch (provider.currentState) {
      case AppState.initial:
        return "TAP ANYWHERE\nTO START";
      case AppState.listening:
        return "LISTENING...\nSpeak your destination";
      case AppState.confirming:
        return "CONFIRM?\n${provider.destination}\n\nTap to confirm";
      case AppState.navigating:
        return "NAVIGATING\n\n${provider.currentInstruction}";
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

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () => _handleTap(provider),
          child: Scaffold(
            backgroundColor: _getBackgroundColor(provider),
            body: SizedBox(
              width: double.infinity,
              height: double.infinity,
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
}
