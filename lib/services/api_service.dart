import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: Configure based on your setup:
  // - Android emulator (AVD): use 10.0.2.2
  // - Android physical device on same Wi-Fi: use your PC's local IP (e.g., 192.168.x.x)
  // - iOS simulator: use 127.0.0.1
  // - Windows/macOS desktop: use 127.0.0.1

  static const String baseUrl =
      'http://10.0.10.210:5000'; // Default for Android

  /// Get navigation directions from the backend
  ///
  /// Returns a Map with either:
  /// - Success: {'status': 'success', 'destination': '...', 'steps': [...]}
  /// - Error: {'status': 'error', 'message': '...'}
  static Future<Map<String, dynamic>> getMockDirections(
      String destination) async {
    try {
      final uri = Uri.parse('$baseUrl/mock-directions');

      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'destination': destination}),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Connection timeout. Please check if the backend server is running.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'status': 'success',
          ...data,
        };
      } else if (response.statusCode == 404) {
        return {
          'status': 'error',
          'message': 'Destination not found in our database.',
        };
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('API Error: $e');
      return {
        'status': 'error',
        'message':
            'Unable to connect to navigation service. Please check your internet connection.',
      };
    }
  }
}
