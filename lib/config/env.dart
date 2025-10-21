import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  static String get supabaseUrl {
    // Para web em produção (deploy)
    if (kIsWeb && const bool.hasEnvironment('SUPABASE_URL')) {
      return const String.fromEnvironment('SUPABASE_URL');
    }

    // Para desenvolvimento local
    try {
      return dotenv.get(
        'SUPABASE_URL',
        fallback: 'https://mngwbikqaxlmbjzyvxii.supabase.co',
      );
    } catch (e) {
      return 'https://mngwbikqaxlmbjzyvxii.supabase.co';
    }
  }

  static String get supabaseAnonKey {
    // Para web em produção (deploy)
    if (kIsWeb && const bool.hasEnvironment('SUPABASE_ANON_KEY')) {
      return const String.fromEnvironment('SUPABASE_ANON_KEY');
    }

    // Para desenvolvimento local
    try {
      return dotenv.get(
        'SUPABASE_ANON_KEY',
        fallback:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1uZ3diaWtxYXhsbWJqenl2eGlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzcyNDMsImV4cCI6MjA3NTM1MzI0M30.DPd8pcBZ-f20XhCsrsmG3Yls5KLn4wBCGFKYAcZlQRI',
      );
    } catch (e) {
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1uZ3diaWtxYXhsbWJqenl2eGlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzcyNDMsImV4cCI6MjA3NTM1MzI0M30.DPd8pcBZ-f20XhCsrsmG3Yls5KLn4wBCGFKYAcZlQRI';
    }
  }
}
