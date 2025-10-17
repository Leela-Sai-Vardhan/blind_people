// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // CHANGE this depending on emulator/device:
  // - Android emulator (AVD): use 10.0.2.2
  // - Android physical phone on same Wi-Fi: use your PC IP (e.g., 10.0.10.210)
  // - iOS simulator: use 127.0.0.1
  // Example set to PC IP you showed earlier:
  static const String baseUrl = 'http://10.0.10.210:5000';

  static Future<Map<String, dynamic>> getMockDirections(
      String destination) async {
    final uri = Uri.parse('$baseUrl/mock-directions');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'destination': destination}),
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } else {
      // return a map with error info so caller can handle TTS
      return {
        'status': 'error',
        'message': 'Server error: ${resp.statusCode}',
      };
    }
  }
}
