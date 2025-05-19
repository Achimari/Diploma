import 'package:flutter/material.dart';
import 'package:auris_app/pages/loadPageState.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoadPage(), // This page should then push to MainScaffold
    );
  }
}
