import 'package:flutter/foundation.dart';

enum AppState {
  initial,      // Tap anywhere to begin
  listening,    // Listening for destination
  confirming,   // Confirming destination
  navigating,   // Active navigation
}

class NavigationProvider extends ChangeNotifier {
  AppState _currentState = AppState.initial;
  String _destination = '';
  List<String> _instructions = [];
  int _currentInstructionIndex = 0;

  AppState get currentState => _currentState;
  String get destination => _destination;
  List<String> get instructions => _instructions;
  int get currentInstructionIndex => _currentInstructionIndex;
  
  String get currentInstruction {
    if (_instructions.isEmpty || _currentInstructionIndex >= _instructions.length) {
      return '';
    }
    return _instructions[_currentInstructionIndex];
  }

  bool get hasMoreInstructions => _currentInstructionIndex < _instructions.length - 1;

  void startSession() {
    _currentState = AppState.listening;
    notifyListeners();
  }

  void setDestination(String dest) {
    _destination = dest;
    _currentState = AppState.confirming;
    notifyListeners();
  }

  void confirmAndStart(List<String> navigationInstructions) {
    _instructions = navigationInstructions;
    _currentInstructionIndex = 0;
    _currentState = AppState.navigating;
    notifyListeners();
  }

  void nextInstruction() {
    if (hasMoreInstructions) {
      _currentInstructionIndex++;
      notifyListeners();
    }
  }

  void reset() {
    _currentState = AppState.initial;
    _destination = '';
    _instructions = [];
    _currentInstructionIndex = 0;
    notifyListeners();
  }
}