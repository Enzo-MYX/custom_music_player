import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/home_carousel_screen.dart';
import 'services/library_manager.dart';
import 'services/playback_controller.dart';
import 'services/player_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationStatus = await Permission.notification.request();

  debugPrint('[audio] notification permission: $notificationStatus');

  final playerAudioHandler = PlayerAudioHandler();

  debugPrint('[audio] creating AudioService');

  final registeredAudioHandler = await AudioService.init(
    builder: () => playerAudioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.custom_music_player.playback',
      androidNotificationChannelName: 'Music playback',

      androidStopForegroundOnPause: false,

      notificationColor: Color(0xFF6750A4),
    ),
  );

  debugPrint(
    '[audio] AudioService initialized; '
    'sameHandler='
    '${identical(registeredAudioHandler, playerAudioHandler)}',
  );

  final playbackController = PlaybackController(playerAudioHandler);
  await playbackController.initialize();

  runApp(MusicPlayerApp(playbackController: playbackController));
}

class MusicPlayerApp extends StatefulWidget {
  final PlaybackController playbackController;

  const MusicPlayerApp({super.key, required this.playbackController});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp>
    with WidgetsBindingObserver {
  late final LibraryManager _manager;

  @override
  void initState() {
    super.initState();

    _manager = LibraryManager();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.playbackController.checkpoint());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.playbackController.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driftwave',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeCarouselScreen(
        manager: _manager,
        playbackController: widget.playbackController,
      ),
    );
  }
}
