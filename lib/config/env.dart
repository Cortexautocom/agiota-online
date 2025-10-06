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
      return dotenv.get('SUPABASE_URL', 
        fallback: 'https://zqvbgfqzdcejgxthdmht.supabase.co');
    } catch (e) {
      return 'https://zqvbgfqzdcejgxthdmht.supabase.co';
    }
  }

  static String get supabaseAnonKey {
    // Para web em produção (deploy)
    if (kIsWeb && const bool.hasEnvironment('SUPABASE_ANON_KEY')) {
      return const String.fromEnvironment('SUPABASE_ANON_KEY');
    }
    
    // Para desenvolvimento local
    try {
      return dotenv.get('SUPABASE_ANON_KEY', 
        fallback: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxdmJnZnF6ZGNlamd4dGhkbWh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMTI5ODAsImV4cCI6MjA3MDY4ODk4MH0.e4NhuarlGNnXrXUWKdLmGoa1DGejn2jmgpbRR_Ztyqw');
    } catch (e) {
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxdmJnZnF6ZGNlamd4dGhkbWh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMTI5ODAsImV4cCI6MjA3MDY4ODk4MH0.e4NhuarlGNnXrXUWKdLmGoa1DGejn2jmgpbRR_Ztyqw';
    }
  }
}