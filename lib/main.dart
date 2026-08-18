import 'package:flutter/material.dart';

import 'screens/library_manager_screen.dart';
import 'services/library_manager.dart';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = LibraryManager();

    return MaterialApp(
      title: 'Custom Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: LibraryManagerScreen(
        manager: manager,
      ),
    );
  }
}