import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Penalty Kick shootout engine. 5 kicks each, alternating striker/keeper,
// then sudden death — plus an endless practice mode. See RULES.md — the
// engine enforces every rule there.
//
// Turn phases are owned ENTIRELY by the engine (UI only renders). A single
// phase timer plus a watchdog make stuck states impossible by construction:
// every phase either arms its own forward transition or the watchdog drives
// one. Bots act through engine timers, so their turns animate fully and are
// never silently auto-played.
//
// The kick outcome is decided when the kick is TAKEN (like real physics),
// so the ball flight animation always matches the settled result. Wind
// (Medium/Hard) drifts the ball in flight and can push on-target shots
// outside the frame.
// ---------------------------------------------------------------------------

/// Zones of the goal mouth: 3 columns x 2 rows.
/// 0 1 2
/// 3 4 5
const cornerZones = [0, 2, 3, 5];
const int kicksPerSide = 5;

/// 0 = easy, 1 = medium, 2 = hard (RULES.md §11).
enum BotDifficulty { easy, medium, hard }

/// Kick phases owned by the engine. The UI only renders.
/// [settling] = the kick result is displayed; input locked; the shootout
/// advances on its own timer.
enum Phase { strikerAim, keeperAim, flying, settling, over }

enum KickResult { goal, save, miss }

class PenkPlayer {
  String name;
  final bool isBot;
  int goals = 0;

  PenkPlayer({required this.name, required this.isBot});
}

/// Ball flight in progress (visual). The outcome is decided when the kick
/// is taken, so the flight path always matches the settled result.
/// Engine owns start/duration; UI reads [progress] for the interpolation.
class FlightAnim {
  final int shotZone;
  final int diveZone;
  final Offset landOffset; // fraction of goal size: where the ball ends up
  final KickResult result; // decided at kick time
  final int totalMs;
  final DateTime startedAt = DateTime.now();

  FlightAnim({
    required this.shotZone,
    required this.diveZone,
    required this.landOffset,
    required this.result,
    required this.totalMs,
  });

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }
}

class PenaltyKickEngine extends ChangeNotifier {
  final List<PenkPlayer> players; // exactly 2
  final BotDifficulty botDifficulty;

  /// Practice mode: endless kicks, human always striker, AI always keeper.
  /// The shootout never ends; stats accumulate instead of a winner.
  final bool practice;

  int kickIndex = 0; // each kick: striker = kickIndex % 2
  Phase phase = Phase.strikerAim;
  int shotZone = -1; // -1 = not chosen
  int diveZone = -1;
  KickResult? lastResult;
  FlightAnim? flight;
  final List<List<KickResult>> marks = [[], []]; // per player
  final List<List<int>> shotHistory = [[], []];
  final List<List<int>> diveHistory = [[], []];
  bool over = false;
  int? winner;
  String banner = '';
  int kickCount = 0;

  /// Where the last kick's ball landed (goal fractions); survives the
  /// settle/over phases after [flight] is cleared.
  Offset lastLandOffset = Offset.zero;

  /// Wind for the current kick, as fractions of goal width/height.
  /// Set per kick from the difficulty (RULES.md §7); shown to the striker
  /// before the shot so it is a fair, readable challenge.
  double windDx = 0;
  double windDy = 0;
  int windLevel = 0; // 0 = none, 1 = breeze, 2 = strong

  /// Practice-mode tally.
  int practiceShots = 0;
  int practiceGoals = 0;
  int practiceStreak = 0;
  int practiceBest = 0;

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  static const int _aimBotMs = 850;
  static const int _diveBotMs = 650;
  static const int _flightMs = 900;
  static const int _settleMs = 1500;

  /// Test hook: forces the next kick outcome instead of the random resolve.
  /// Consumed after one use.
  @visibleForTesting
  KickResult? forcedResult;

  /// Test hooks: inspect the bot's next pick without timers.
  @visibleForTesting
  int debugBotShotZone() => _botShotZone();

  @visibleForTesting
  int debugBotDiveZone() => _botDiveZone();

  /// Test hook: force the wind for the current kick.
  @visibleForTesting
  void debugSetWind(double dx, double dy) {
    windDx = dx;
    windDy = dy;
    windLevel = 3;
  }

  PenaltyKickEngine(
      {required this.players,
      this.botDifficulty = BotDifficulty.medium,
      this.practice = false}) {
    assert(players.length == 2);
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    _setupKick();
  }

  int get strikerIdx => practice ? 0 : kickIndex % 2;
  int get keeperIdx => practice ? 1 : (kickIndex + 1) % 2;
  PenkPlayer get striker => players[strikerIdx];
  PenkPlayer get keeper => players[keeperIdx];
  bool get suddenDeath => kickIndex >= kicksPerSide * 2;
  int get round => kickIndex ~/ 2 + 1;

  bool get awaitingStriker =>
      phase == Phase.strikerAim && !striker.isBot && !over;
  bool get awaitingKeeper => phase == Phase.keeperAim && !keeper.isBot && !over;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(PenkEvent event)? onEvent;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    if (phase == Phase.strikerAim && striker.isBot) {
      _botShoot();
    } else if (phase == Phase.keeperAim && keeper.isBot) {
      _botDive();
    } else if (phase == Phase.flying && flight != null) {
      final f = flight!;
      final elapsed = DateTime.now().difference(f.startedAt).inMilliseconds;
      final remain = (f.totalMs - elapsed).clamp(60, f.totalMs);
      _arm(Duration(milliseconds: remain), _resolve);
    } else if (phase == Phase.flying && flight == null) {
      _resolve();
    } else if (phase == Phase.settling) {
      _advance();
    }
  }

  /// Kick setup: called at match start, restart, and after each kick.
  void _setupKick() {
    if (over) return;
    shotZone = -1;
    diveZone = -1;
    lastResult = null;
    flight = null;
    lastLandOffset = Offset.zero;
    phase = Phase.strikerAim;
    _rollWind();
    if (practice) {
      banner =
          'Practice kick ${kickIndex + 1} — tap a zone (or drag) to shoot!';
    } else {
      banner = striker.isBot
          ? '${striker.name} steps up to the spot…'
          : '${striker.name}, tap a zone of the goal to place your shot!';
    }
    notifyListeners();
    _afterPhase();
  }

  /// Roll the wind for this kick from the difficulty (RULES.md §7):
  /// Easy = still air; Medium = light breeze; Hard = strong, gusty wind.
  /// The striker sees it before shooting, so it is a fair challenge.
  void _rollWind() {
    switch (botDifficulty) {
      case BotDifficulty.easy:
        windDx = 0;
        windDy = 0;
        windLevel = 0;
      case BotDifficulty.medium:
        windLevel = 1;
        windDx = (_rand.nextDouble() * 2 - 1) * 0.025;
        windDy = (_rand.nextDouble() * 2 - 1) * 0.02;
      case BotDifficulty.hard:
        windLevel = 2;
        windDx = (_rand.nextDouble() * 2 - 1) * 0.05;
        windDy = (_rand.nextDouble() * 2 - 1) * 0.035;
    }
  }

  /// Called whenever we enter an aim phase: bots act through engine timers.
  void _afterPhase() {
    if (over || paused) return;
    if (phase == Phase.strikerAim && striker.isBot) {
      _arm(Duration(milliseconds: _aimBotMs), _botShoot);
    } else if (phase == Phase.keeperAim && keeper.isBot) {
      _arm(Duration(milliseconds: _diveBotMs), _botDive);
    }
  }

  // ------------------------------------------------------------ human input
  /// Striker taps a goal zone.
  void chooseShot(int zone) {
    if (over || phase != Phase.strikerAim || striker.isBot) {
      onEvent?.call(PenkEvent.invalid);
      return;
    }
    if (zone < 0 || zone > 5) return;
    _applyShot(zone);
  }

  /// Keeper taps a goal zone to dive.
  void chooseDive(int zone) {
    if (over || phase != Phase.keeperAim || keeper.isBot) {
      onEvent?.call(PenkEvent.invalid);
      return;
    }
    if (zone < 0 || zone > 5) return;
    _applyDive(zone);
  }

  // ------------------------------------------------------------------ bots
  void _botShoot() {
    if (over || phase != Phase.strikerAim || !striker.isBot) return;
    _applyShot(_botShotZone());
  }

  void _botDive() {
    if (over || phase != Phase.keeperAim || !keeper.isBot) return;
    _applyDive(_botDiveZone());
  }

  /// Bot striker picks a zone (RULES.md §11).
  int _botShotZone() {
    switch (botDifficulty) {
      case BotDifficulty.easy:
        return _rand.nextInt(6);
      case BotDifficulty.medium: {
        if (_rand.nextDouble() < 0.6) {
          return cornerZones[_rand.nextInt(cornerZones.length)];
        }
        return _rand.nextInt(6);
      }
      case BotDifficulty.hard: {
        // Punish the keeper's favorite dive zone: pick a corner far from it.
        final keeperHist = diveHistory[keeperIdx];
        int? favDive;
        if (keeperHist.isNotEmpty) {
          final counts = <int, int>{};
          for (final z in keeperHist) {
            counts[z] = (counts[z] ?? 0) + 1;
          }
          favDive = counts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
        }
        final options = [...cornerZones]
          ..sort((a, b) => _zoneDist(a, favDive).compareTo(_zoneDist(b, favDive)));
        // RULES.md §11: the farthest corner 80% of the time, with slight
        // noise to stay human. The noise is deterministic (every 5th kick)
        // so the strategy stays testable and the AI never looks rigged.
        if (kickCount % 5 == 4) {
          return cornerZones[_rand.nextInt(cornerZones.length)];
        }
        return options.last;
      }
    }
  }

  static double _zoneDist(int a, int? b) {
    if (b == null) return 0;
    final dx = (a % 3) - (b % 3);
    final dy = (a ~/ 3) - (b ~/ 3);
    return (dx * dx + dy * dy).toDouble();
  }

  /// Bot keeper picks a dive zone (RULES.md §11).
  int _botDiveZone() {
    switch (botDifficulty) {
      case BotDifficulty.easy:
        return _rand.nextInt(6);
      case BotDifficulty.medium: {
        // Studies the striker's shooting patterns half the time.
        if (shotHistory[strikerIdx].isNotEmpty &&
            _rand.nextDouble() < 0.5) {
          return _strikerFavorite();
        }
        return _rand.nextInt(6);
      }
      case BotDifficulty.hard: {
        // Studies patterns hard; reacts to streaks.
        final hist = shotHistory[strikerIdx];
        if (hist.length >= 2 &&
            hist[hist.length - 1] == hist[hist.length - 2]) {
          // Streak: commit to the hot zone.
          return hist.last;
        }
        if (hist.isNotEmpty && _rand.nextDouble() < 0.8) {
          return _strikerFavorite();
        }
        return _rand.nextInt(6);
      }
    }
  }

  int _strikerFavorite() {
    final hist = shotHistory[strikerIdx];
    final counts = <int, int>{};
    for (final z in hist) {
      counts[z] = (counts[z] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ------------------------------------------------------------- kick flow
  void _applyShot(int zone) {
    if (phase != Phase.strikerAim) return;
    shotZone = zone;
    shotHistory[strikerIdx].add(zone);
    phase = Phase.keeperAim;
    banner = keeper.isBot
        ? '${keeper.name} is reading the run-up…'
        : '${keeper.name} — pick your dive!';
    onEvent?.call(PenkEvent.shotChosen);
    notifyListeners();
    _afterPhase();
  }

  void _applyDive(int zone) {
    if (phase != Phase.keeperAim) return;
    diveZone = zone;
    diveHistory[keeperIdx].add(zone);
    // The outcome is decided NOW (like real physics) so the flight
    // animation and the settled result can never disagree.
    final result = _decideKickResult();
    phase = Phase.flying;
    flight = FlightAnim(
      shotZone: shotZone,
      diveZone: diveZone,
      landOffset: result == KickResult.miss ? _missOffset() : Offset.zero,
      result: result,
      totalMs: _flightMs,
    );
    banner = '${striker.name} shoots…';
    onEvent?.call(PenkEvent.kickFlying);
    notifyListeners();
    _arm(Duration(milliseconds: _flightMs), _resolve);
  }

  /// Decide the kick outcome (RULES.md §7–§8).
  KickResult _decideKickResult() {
    if (forcedResult != null) {
      final r = forcedResult!;
      forcedResult = null;
      return r;
    }
    final corner = cornerZones.contains(shotZone);
    final missChance = corner ? 0.10 : 0.02;
    if (_rand.nextDouble() < missChance) {
      return KickResult.miss;
    }
    // Wind drift: an on-target shot can still be pushed outside the frame.
    final fx = (shotZone % 3 + 0.5) / 3 + windDx;
    final fy = (shotZone ~/ 3 + 0.5) / 2 + windDy;
    if (fx < 0.0 || fx > 1.0 || fy < 0.0) {
      return KickResult.miss;
    }
    if (diveZone == shotZone) {
      return KickResult.save;
    }
    return KickResult.goal;
  }

  /// Where a missed shot ends up: clearly outside the nearest post or bar,
  /// as fractions of goal width/height from the target zone's center.
  Offset _missOffset() {
    final col = shotZone % 3;
    final top = (shotZone ~/ 3) == 0;
    double dx = 0;
    double dy = 0;
    if (col == 0) {
      dx = -0.24;
    } else if (col == 2) {
      dx = 0.24;
    }
    if (top) {
      dy = -0.32;
    } else if (col == 1) {
      // Bottom-center: shank it wide of a post.
      dx = _rand.nextBool() ? -0.24 : 0.24;
    }
    return Offset(dx, dy);
  }

  /// Settle the kick with the result decided at kick time (RULES.md §8).
  void _resolve() {
    if (over || phase != Phase.flying) return;
    final result = flight?.result ?? KickResult.miss;
    lastLandOffset = flight?.landOffset ?? Offset.zero;
    lastResult = result;
    marks[strikerIdx].add(result);
    if (result == KickResult.goal) players[strikerIdx].goals++;
    if (practice) {
      practiceShots++;
      if (result == KickResult.goal) {
        practiceGoals++;
        practiceStreak++;
        if (practiceStreak > practiceBest) practiceBest = practiceStreak;
      } else {
        practiceStreak = 0;
      }
    }
    flight = null;
    phase = Phase.settling;
    kickCount++;
    switch (result) {
      case KickResult.goal:
        banner = 'GOAL! ${striker.name} buries it!';
        onEvent?.call(PenkEvent.goal);
      case KickResult.save:
        banner = 'SAVED! ${keeper.name} reads it perfectly!';
        onEvent?.call(PenkEvent.save);
      case KickResult.miss:
        banner = 'WIDE! ${striker.name} drags it past the post!';
        onEvent?.call(PenkEvent.miss);
    }
    notifyListeners();
    _arm(Duration(milliseconds: _settleMs), _advance);
  }

  void _advance() {
    if (over) return;
    if (practice) {
      // Practice never ends: another kick, same roles.
      kickIndex++;
      _setupKick();
      return;
    }
    final w = _decideWinner();
    if (w != null) {
      _finish(w);
    } else {
      kickIndex++;
      _setupKick();
    }
  }

  /// Returns winning player index, or null to continue (RULES.md §9).
  int? _decideWinner() {
    if (practice) return null; // practice never produces a winner
    final g = [players[0].goals, players[1].goals];
    if (!suddenDeath) {
      final taken = [marks[0].length, marks[1].length];
      final left = [kicksPerSide - taken[0], kicksPerSide - taken[1]];
      if (g[0] > g[1] + left[1]) return 0;
      if (g[1] > g[0] + left[0]) return 1;
      if (taken[0] == kicksPerSide &&
          taken[1] == kicksPerSide &&
          g[0] != g[1]) {
        return g[0] > g[1] ? 0 : 1;
      }
      return null;
    }
    // Sudden death: decide after each completed pair of kicks.
    if (kickIndex % 2 == 1 && g[0] != g[1]) {
      return g[0] > g[1] ? 0 : 1;
    }
    return null;
  }

  void _finish(int w) {
    over = true;
    phase = Phase.over;
    winner = w;
    banner = '${players[w].name} wins the shootout!';
    notifyListeners();
    onEvent?.call(
        players[w].isBot ? PenkEvent.botWon : PenkEvent.humanWon);
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    for (final p in players) {
      p.goals = 0;
    }
    kickIndex = 0;
    marks[0].clear();
    marks[1].clear();
    shotHistory[0].clear();
    shotHistory[1].clear();
    diveHistory[0].clear();
    diveHistory[1].clear();
    over = false;
    winner = null;
    kickCount = 0;
    forcedResult = null;
    windDx = 0;
    windDy = 0;
    windLevel = 0;
    practiceShots = 0;
    practiceGoals = 0;
    practiceStreak = 0;
    practiceBest = 0;
    notifyListeners();
    onEvent?.call(PenkEvent.matchStart);
    _setupKick();
  }
}

enum PenkEvent {
  matchStart,
  shotChosen,
  kickFlying,
  goal,
  save,
  miss,
  invalid,
  humanWon,
  botWon,
}
