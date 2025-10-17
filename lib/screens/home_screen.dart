import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../providers/navigation_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'detection_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TTSService _tts;
  late WebSocketService _navigationWS;
  bool _isProcessing = false;
  bool _wsConnected = false;
  final String _currentSessionId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _tts = Provider.of<TTSService>(context, listen: false);
      await _tts.initialize();

      // Initialize Navigation WebSocket (Port 8000)
      _navigationWS = WebSocketService(Uri.parse('ws://10.0.11.239:8000/ws'));

      _navigationWS.onConnected = () {
        debugPrint("✅ Navigation WS Connected");
        setState(() => _wsConnected = true);
        _tts.speak("Navigation service connected");
      };

      _navigationWS.onMessage = (msg) {
        debugPrint("📩 Navigation WS Message: $msg");
        try {
          final data = msg;
          if (msg.contains('alert')) {
            _tts.speak("Navigation alert received");
          }
        } catch (e) {
          debugPrint("Message parse error: $e");
        }
      };

      _navigationWS.onDisconnected = () {
        debugPrint("⚠️ Navigation WS Disconnected");
        setState(() => _wsConnected = false);
      };

      _navigationWS.onError = (err) {
        debugPrint("❌ Navigation WS Error: $err");
      };

      _navigationWS.connect();
    });
  }

  @override
  void dispose() {
    // Stop navigation if active
    if (_wsConnected && _currentSessionId.isNotEmpty) {
      _navigationWS.sendJson({'reason': 'app_closed'});
    }
    _tts.dispose();
    _navigationWS.disconnect();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _navigateToDetection();
    } else {
      await _tts.speak("Camera permission is required for object detection");
    }
  }

  void _navigateToDetection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DetectionScreen()),
    );
  }

  Future<void> _handleTap(NavigationProvider provider) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      switch (provider.currentState) {
        case AppState.initial:
          await _tts.speak(
              "Welcome to Manas. Tap once for navigation, double tap for object detection.");
          await Future.delayed(const Duration(milliseconds: 3000));
          provider.startSession();
          await _tts.speak(
              "Where would you like to go? Please say your destination.");
          break;

        case AppState.listening:
          await _tts.speak("Listening for your destination");
          await Future.delayed(const Duration(seconds: 2));

          // Mock destination (replace with real speech-to-text)
          String mockDestination = "VRSEC gate";
          provider.setDestination(mockDestination);

          await _tts.speak(
              "You said $mockDestination. Tap to confirm, or double tap to cancel.");
          break;

        case AppState.confirming:
          await _tts.speak("Getting directions. Please wait.");

          // Send confirmation via WebSocket
          if (_wsConnected) {
            _navigationWS.sendJson(
                {'destination': provider.destination, 'action': 'confirmed'});
          }

          // Get directions from REST API
          final response =
              await ApiService.getMockDirections(provider.destination);
          debugPrint("API Response: $response");

          if (response['status'] == 'error') {
            await _tts.speak(
                "Sorry, unable to get directions. ${response['message']}");
            provider.reset();
            break;
          }

          // Parse navigation instructions
          List<String> instructions = [];
          if (response['directions'] != null) {
            String directionsText = response['directions'].toString();
            instructions
                .add("Starting navigation to ${response['destination']}");

            List<String> steps = directionsText
                .split('. ')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            for (var step in steps) {
              if (!step.endsWith('.')) {
                instructions.add('$step.');
              } else {
                instructions.add(step);
              }
            }

            instructions.add("You have arrived at ${response['destination']}");
          } else {
            await _tts.speak("Unable to parse navigation data.");
            provider.reset();
            break;
          }

          // Start navigation via WebSocket
          if (_wsConnected) {
            _navigationWS.sendJson({
              'destination': provider.destination,
              'steps': instructions.length
            });
          }

          provider.confirmAndStart(instructions);
          await _tts.speak(provider.currentInstruction);

          // Send initial progress
          if (_wsConnected) {
            _navigationWS.sendJson(
                {'step': 0, 'instruction': provider.currentInstruction});
          }
          break;

        case AppState.navigating:
          if (provider.hasMoreInstructions) {
            provider.nextInstruction();
            await _tts.speak(provider.currentInstruction);

            // Send progress update via WebSocket
            if (_wsConnected) {
              _navigationWS.sendJson({
                'step': provider.currentInstructionIndex,
                'instruction': provider.currentInstruction
              });
            }
          } else {
            await _tts
                .speak("Navigation complete. Tap to start a new journey.");

            // Stop navigation via WebSocket
            if (_wsConnected) {
              _navigationWS.sendJson({'reason': 'completed'});
            }

            provider.reset();
          }
          break;
      }
    } catch (e) {
      await _tts.speak("An error occurred. Please try again.");
      provider.reset();
      debugPrint("❌ Error: $e");
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _handleDoubleTap() async {
    await _tts.speak("Opening object detection mode");
    await Future.delayed(const Duration(milliseconds: 500));
    await _requestCameraPermission();
  }

  String _getDisplayText(NavigationProvider provider) {
    String connectionStatus = _wsConnected ? "🟢 Connected" : "🔴 Disconnected";

    switch (provider.currentState) {
      case AppState.initial:
        return "TAP ANYWHERE\nTO START\n\nDouble tap for detection\n\n$connectionStatus";
      case AppState.listening:
        return "LISTENING...\nSpeak your destination\n\n$connectionStatus";
      case AppState.confirming:
        return "CONFIRM?\n${provider.destination}\n\nTap to confirm\n\n$connectionStatus";
      case AppState.navigating:
        int progress = provider.currentInstructionIndex + 1;
        int total = provider.instructions.length;
        return "NAVIGATING ($progress/$total)\n\n${provider.currentInstruction}\n\n$connectionStatus";
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
}
