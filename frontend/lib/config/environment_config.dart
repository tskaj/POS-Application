import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://zafarcomputers.com/api';
  }

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }
}
