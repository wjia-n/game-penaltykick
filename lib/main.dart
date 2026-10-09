import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/settings_service.dart';
import 'theme/stadium_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = KickSettings();
  await settings.load();
  final audio = KickAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  final store = StoreService();
  runApp(PenaltyKickApp(settings: settings, audio: audio, store: store));
}

class PenaltyKickApp extends StatefulWidget {
  final KickSettings settings;
  final KickAudio audio;
  final StoreService store;
  const PenaltyKickApp(
      {super.key,
      required this.settings,
      required this.audio,
      required this.store});

  @override
  State<PenaltyKickApp> createState() => _PenaltyKickAppState();
}

class _PenaltyKickAppState extends State<PenaltyKickApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Penalty Kick',
        debugShowCheckedModeBanner: false,
        theme: _stadiumTheme(widget.settings),
        home: SplashScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }
}

ThemeData _stadiumTheme(KickSettings s) {
  final t = StadiumThemes.byId(s.themeId, custom: s.customTheme);
  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.panel,
    appBarTheme: AppBarTheme(
      backgroundColor: t.panelDark,
      foregroundColor: Colors.white,
    ),
  );
}
