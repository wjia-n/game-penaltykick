import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/stadium_themes.dart';

/// Persisted settings + stats for Penalty Kick. Survives app restarts.
///
/// Stores: audio toggles, player names (2 slots), stadium/ball/kit choices
/// (incl. custom theme colors), game-mode setup (vs AI difficulty or
/// pass-and-play), Pro unlock state, and lifetime stats.
class KickSettings extends ChangeNotifier {
  static const _kMusic = 'pk_music_on';
  static const _kSfx = 'pk_sfx_on';
  static const _kVolume = 'pk_volume';
  static const _kMode = 'pk_mode'; // 'ai' | 'passplay' | 'practice'
  static const _kDifficulty = 'pk_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNamesLegacy = 'pk_player_names'; // legacy unordered StringSet key
  static const _kNamesJsonLegacy = 'pk_player_names_json'; // superseded JSON key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so a
  /// StringList key scrambles name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'penaltykick_player_names_json';
  static const _kBotSeat = 'pk_bot_seat'; // which seat (0/1) is the AI in vs-AI mode
  static const _kTheme = 'pk_theme_id';
  static const _kBall = 'pk_ball_style';
  static const _kKit = 'pk_kit_style';
  static const _kWins = 'pk_wins';
  static const _kGames = 'pk_games_played';
  static const _kIsPro = 'pk_is_pro';
  static const _kCustomPrefix = 'pk_custom_';

  static const defaultNames = ['Striker', 'Rival'];

  /// Encode the 2 player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String mode = 'ai'; // 'ai' = vs AI, 'passplay' = 2 humans pass-and-play
  int difficulty = 1; // medium default
  int botSeat = 1; // the AI plays seat 1 in vs-AI mode
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'daybreak';
  int ballStyle = 0;
  int kitStyle = 0;
  int wins = 0;
  int gamesPlayed = 0;
  bool isPro = false;

  /// Custom stadium theme colors (ARGB ints). Defaults mirror Daybreak Arena.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'skyTop': 0xFF6FA8DC,
    'skyBottom': 0xFFDCECF7,
    'standDark': 0xFF3A5A8C,
    'standLight': 0xFF6E93C2,
    'grassLight': 0xFF4E9A3D,
    'grassDark': 0xFF3A7A2C,
    'lineColor': 0xFFF4F7EF,
    'netColor': 0xFFD9DEE2,
    'accent': 0xFFE07A2B,
  };

  /// Builds the user-designed custom stadium from stored colors.
  StadiumThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return StadiumThemeDef(
      id: 'custom',
      name: 'My Stadium',
      skyTop: c('skyTop'),
      skyBottom: c('skyBottom'),
      standDark: c('standDark'),
      standLight: c('standLight'),
      grassLight: c('grassLight'),
      grassDark: c('grassDark'),
      lineColor: c('lineColor'),
      netColor: c('netColor'),
      postColor: const Color(0xFFF8FAFC),
      accent: c('accent'),
      panel: const Color(0xFFF4EFE3),
      panelDark: c('standDark'),
      textOn: const Color(0xFF20344C),
      textDim: c('standLight'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    mode = p.getString(_kMode) ?? 'ai';
    if (mode != 'ai' && mode != 'passplay' && mode != 'practice') mode = 'ai';
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    botSeat = (p.getInt(_kBotSeat) ?? 1).clamp(0, 1);
    // Player names: prefer the canonical order-safe JSON key. Migrate
    // through older keys once (the legacy StringList may already be
    // scrambled on Android — that is exactly the bug this replaces).
    final namesRaw = p.getString(_kNamesJson) ?? p.getString(_kNamesJsonLegacy);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNamesLegacy);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'daybreak';
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, BallStyles.all.length - 1);
    kitStyle = (p.getInt(_kKit) ?? 0).clamp(0, KitStyles.all.length - 1);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kBotSeat, botSeat);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNamesJsonLegacy); // drop superseded keys for good
    await p.remove(_kNamesLegacy);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBall, ballStyle);
    await p.setInt(_kKit, kitStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || StadiumThemes.isProTheme(themeId)) {
      themeId = 'daybreak';
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (KitStyles.isPro(kitStyle)) {
      kitStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom stadium creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String m) async {
    if (m != 'ai' && m != 'passplay' && m != 'practice') return;
    mode = m;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int d) async {
    difficulty = d.clamp(0, 2);
    // Hard mode is a Pro feature.
    if (!isPro && difficulty > 1) difficulty = 1;
    notifyListeners();
    await _save();
  }

  Future<void> setBotSeat(int s) async {
    botSeat = s.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  /// Save a player name on EVERY keystroke (raw, untrimmed — the field may
  /// be mid-edit). Focus-loss commit (see [commitPlayerName]) trims and
  /// restores the default for empty names.
  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    playerNames[index] =
        name.length > 16 ? name.substring(0, 16) : name;
    notifyListeners();
    await _save();
  }

  /// Focus-loss commit: trim the name; an empty field falls back to the
  /// default seat name so a half-cleared field never persists as blank.
  Future<void> commitPlayerName(int index) async {
    if (index < 0 || index > 1) return;
    final clean = playerNames[index].trim();
    playerNames[index] =
        clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || StadiumThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.all.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setKitStyle(int v) async {
    v = v.clamp(0, KitStyles.all.length - 1);
    if (!isPro && KitStyles.isPro(v)) return;
    kitStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished match. [humanWon] true if a human player won.
  Future<void> recordGame({required bool humanWon}) async {
    gamesPlayed++;
    if (humanWon) wins++;
    notifyListeners();
    await _save();
  }
}
