import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_supabase/screens/task_page.dart';

void main() async {
  // supabase setup
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://nxbxxjohqxpfgnvhjgkj.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im54Ynh4am9ocXhwZmdudmhqZ2tqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU2NjQxMjAsImV4cCI6MjA3MTI0MDEyMH0.z5iyGC9xiNL_OjbNWIv1Xz1XJ7tslWSsBWQ8BpOGy48",
  );
  // run app
  runApp(MyApp());
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
      home: const TaskPage(),
    );
  }
}
