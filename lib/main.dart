import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/shuffle_screen.dart';
import 'services/library_manager.dart';
import 'services/playback_controller.dart';
import 'services/player_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationStatus = await Permission.notification.request();
  debugPrint(
    '[audio] notification permission: $notificationStatus',
  );

  final playerAudioHandler = PlayerAudioHandler();
  debugPrint('[audio] creating AudioService');

  final registeredAudioHandler = await AudioService.init(
    builder: () => playerAudioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId:
      'com.example.custom_music_player.playback',
      androidNotificationChannelName: 'Music playback',
    ),
  );
  debugPrint(
    '[audio] AudioService initialized; '
    'sameHandler=${identical(registeredAudioHandler, playerAudioHandler)}',
  );

  runApp(
    MusicPlayerApp(
      playbackController: PlaybackController(
        playerAudioHandler,
      ),
    ),
  );
}

class MusicPlayerApp extends StatefulWidget {
  final PlaybackController playbackController;

  const MusicPlayerApp({
    super.key,
    required this.playbackController,
  });

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  late final LibraryManager _manager;

  @override
  void initState() {
    super.initState();

    _manager = LibraryManager();
  }

  @override
  void dispose() {
    unawaited(widget.playbackController.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: ShuffleScreen(
        manager: _manager,
        playbackController: widget.playbackController,
      ),
    );
  }
}
