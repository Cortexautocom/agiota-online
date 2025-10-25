import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  static String get supabaseUrl {
    if (kIsWeb) {
      // 🔹 Para Web (Firebase Hosting)
      return const String.fromEnvironment('SUPABASE_URL');
    }
    // 🔹 Para desenvolvimento local
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    if (kIsWeb) {
      // 🔹 Para Web (Firebase Hosting)
      return const String.fromEnvironment('SUPABASE_ANON_KEY');
    }
    // 🔹 Para desenvolvimento local
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}
