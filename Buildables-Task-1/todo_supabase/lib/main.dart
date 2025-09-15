import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_supabase/widgets/auth_wrapper.dart';

void main() async {
  if (kDebugMode) {
    print('🚀 [MAIN] Starting Todo Supabase App');
  }

  // supabase setup
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print('🔧 [MAIN] Loading environment variables');
  }
  await dotenv.load(fileName: ".env");

  if (kDebugMode) {
    print('🔧 [MAIN] Initializing Supabase');
    print(
      '🔧 [MAIN] SUPABASE_URL: ${dotenv.env['SUPABASE_URL'] != null ? 'Loaded' : 'Missing'}',
    );
    print(
      '🔧 [MAIN] SUPABASE_ANON_KEY: ${dotenv.env['SUPABASE_ANON_KEY'] != null ? 'Loaded' : 'Missing'}',
    );
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  if (kDebugMode) {
    print('✅ [MAIN] Supabase initialized successfully');
    print('🏃 [MAIN] Running app with ProviderScope');
  }

  // run app
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo Supabase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xff38b17d)),
        fontFamily: 'AnonymousPro',
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Color(0xff38b17d),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
