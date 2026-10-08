import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Penalty Kick - alternating shootout: striker picks a zone, keeper dives.
class PenaltyKickScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const PenaltyKickScreen({super.key, required this.players, required this.callbacks});

  @override
  State<PenaltyKickScreen> createState() => _PenaltyKickScreenState();
}

enum _Phase { kickerAim, keeperAim, flying, result }

class _PenaltyKickScreenState extends State<PenaltyKickScreen> {
  final _rnd = Random();
  int kickIndex = 0; // each kick: kicker = kickIndex % 2
  _Phase phase = _Phase.kickerAim;
  int shotZone = -1;
  int diveZone = -1;
  String resultText = '';
  bool over = false;
  final List<List<String>> marks = [[], []]; // per player: 'goal' | 'save' | 'miss'
  final List<List<int>> shotHistory = [[], []]; // zones each player has shot at

  int get kickerIdx => kickIndex % 2;
  int get keeperIdx => (kickIndex + 1) % 2;
  int get round => kickIndex ~/ 2 + 1;
  bool get suddenDeath => kickIndex >= 10;

  @override
  void initState() {
    super.initState();
    widget.callbacks.setActivePlayer(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickSetup());
  }

  void _kickSetup() {
    if (over || !mounted) return;
    setState(() {
      phase = _Phase.kickerAim;
      shotZone = -1;
      diveZone = -1;
      resultText = '';
    });
    widget.callbacks.setActivePlayer(kickerIdx);
    if (widget.players[kickerIdx].isBot) {
      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted || over || phase != _Phase.kickerAim) return;
        _onShotChosen(_botShot());
      });
    }
  }

  /// Bot striker: loves corners, mixes it up, avoids the keeper's last dive.
  int _botShot() {
    const corners = [0, 2, 3, 5];
    if (_rnd.nextDouble() < 0.7) return corners[_rnd.nextInt(corners.length)];
    return _rnd.nextInt(6);
  }

  /// Bot keeper: studies the human's shooting patterns, dives at their favorite zone.
  int _botDive(int strikerIdx) {
    final hist = shotHistory[strikerIdx];
    if (hist.isNotEmpty && _rnd.nextDouble() < 0.65) {
      final counts = <int, int>{};
      for (final z in hist) {
        counts[z] = (counts[z] ?? 0) + 1;
      }
      final fav = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return fav;
    }
    return _rnd.nextInt(6);
  }

  void _onShotChosen(int zone) {
    if (over || phase != _Phase.kickerAim) return;
    Sfx.tap();
    setState(() {
      shotZone = zone;
      shotHistory[kickerIdx].add(zone);
      phase = _Phase.keeperAim;
    });
    if (widget.players[keeperIdx].isBot) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || over || phase != _Phase.keeperAim) return;
        _onDiveChosen(_botDive(kickerIdx));
      });
    }
  }

  void _onDiveChosen(int zone) {
    if (over || phase != _Phase.keeperAim) return;
    Sfx.click();
    setState(() {
      diveZone = zone;
      phase = _Phase.flying;
    });
  }

  void _resolve() {
    if (over) return;
    final corner = [0, 2, 3, 5].contains(shotZone);
    final missed = corner && _rnd.nextDouble() < 0.10;
    final saved = !missed && diveZone == shotZone;
    final goal = !missed && !saved;
    final mark = missed ? 'miss' : (saved ? 'save' : 'goal');
    setState(() {
      marks[kickerIdx].add(mark);
      phase = _Phase.result;
      resultText = missed
          ? 'WIDE! 😅'
          : saved
              ? 'SAVED! 🧤'
              : 'GOAL! 🎉';
    });
    if (goal) {
      Sfx.win();
      widget.players[kickerIdx].score += 1;
      widget.callbacks.refreshHud();
    } else {
      Sfx.lose();
    }
    Future.delayed(const Duration(milliseconds: 1350), () {
      if (!mounted || over) return;
      final w = _decideWinner();
      if (w != null) {
        _finish(w);
      } else {
        setState(() => kickIndex++);
        _kickSetup();
      }
    });
  }

  /// Returns winning player index, or null to continue.
  int? _decideWinner() {
    final g = [widget.players[0].score, widget.players[1].score];
    if (!suddenDeath) {
      final taken = [marks[0].length, marks[1].length];
      final left = [5 - taken[0], 5 - taken[1]];
      if (g[0] > g[1] + left[1]) return 0;
      if (g[1] > g[0] + left[0]) return 1;
      if (taken[0] == 5 && taken[1] == 5 && g[0] != g[1]) return g[0] > g[1] ? 0 : 1;
      return null;
    }
    // sudden death: decide after each completed pair
    if (kickIndex % 2 == 1 && g[0] != g[1]) return g[0] > g[1] ? 0 : 1;
    return null;
  }

  void _finish(int winnerIdx) {
    setState(() => over = true);
    final w = widget.players[winnerIdx];
    widget.callbacks.finish(
      winner: w,
      headline: '${w.name} wins the shootout! 🏆',
      subline: suddenDeath ? 'Settled in sudden death. Ice cold. ❄️' : 'Clinical from the spot. 🎯',
    );
  }

  Offset _zoneCenter(int zone, Size s) {
    // goal frame is inset: left/right 8, top 8, height = s.height * 0.62
    final goalW = s.width - 16;
    final goalH = s.height * 0.62;
    return Offset(
      8 + ((zone % 3) + 0.5) / 3 * goalW,
      8 + ((zone ~/ 3) + 0.5) / 2 * goalH,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final kicker = widget.players[kickerIdx];
    final keeper = widget.players[keeperIdx];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
              player: kicker,
              action: phase == _Phase.kickerAim
                  ? (kicker.isBot ? ' steps up… 🤖' : ', pick your spot! 🎯')
                  : phase == _Phase.keeperAim
                      ? (keeper.isBot ? ' reads the run-up… 👀' : ', ${keeper.name} — dive! 🧤')
                      : ' …',
            ),
          const SizedBox(height: 8),
          _scoreRow(t),
          const SizedBox(height: 8),
          Expanded(child: Center(child: _pitch(t))),
          const SizedBox(height: 8),
          Text(
            phase == _Phase.result
                ? resultText
                : suddenDeath
                    ? 'Sudden death — every kick counts! ⚡'
                    : 'Round ${min(round, 5)} of 5',
            style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _scoreRow(GameTheme t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int p = 0; p < 2; p++) ...[
          if (p == 1) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${widget.players[0].score} — ${widget.players[1].score}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: t.text)),
          ),
          Column(
            children: [
              Text(widget.players[p].emoji, style: const TextStyle(fontSize: 22)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in marks[p])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(m == 'goal' ? '✅' : (m == 'save' ? '🧤' : '❌'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pitch(GameTheme t) {
    return AspectRatio(
      aspectRatio: 1.05,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final goalH = size.height * 0.62;
          final spot = Offset(size.width / 2, size.height * 0.92);
          final keeperRest = Offset(size.width / 2, 8 + goalH * 0.5);
          return Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: t.radius,
              border: Border.all(color: t.primary.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Stack(
              children: [
                // goal frame with 6 tappable zones
                Positioned(
                  left: 8, right: 8, top: 8, height: goalH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.background,
                      borderRadius: t.radius,
                      border: Border.all(color: t.text, width: 3),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, childAspectRatio: 1.35),
                      itemCount: 6,
                      itemBuilder: (_, z) {
                        final active = (phase == _Phase.kickerAim && !widget.players[kickerIdx].isBot) ||
                            (phase == _Phase.keeperAim && !widget.players[keeperIdx].isBot);
                        return GestureDetector(
                          onTap: active
                              ? () => phase == _Phase.kickerAim ? _onShotChosen(z) : _onDiveChosen(z)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: active
                                  ? t.primary.withValues(alpha: 0.22)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active
                                    ? t.primary.withValues(alpha: 0.6)
                                    : t.muted.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // keeper
                if (phase == _Phase.flying)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, v, _) {
                      final p = Offset.lerp(keeperRest, _zoneCenter(diveZone, size), v)!;
                      return Positioned(
                        left: p.dx - 22, top: p.dy - 22,
                        child: const Text('🧤', style: TextStyle(fontSize: 44)),
                      );
                    },
                  )
                else
                  Positioned(
                    left: keeperRest.dx - 22, top: keeperRest.dy - 22,
                    child: const Text('🧤', style: TextStyle(fontSize: 44)),
                  ),
                // ball flight
                if (phase == _Phase.flying)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeIn,
                    onEnd: _resolve,
                    builder: (_, v, _) {
                      final p = Offset.lerp(spot, _zoneCenter(shotZone, size), v)!;
                      return Positioned(
                        left: p.dx - 14, top: p.dy - 14,
                        child: Text('⚽', style: TextStyle(fontSize: 34 - 10 * v)),
                      );
                    },
                  )
                else if (phase != _Phase.result || resultText.startsWith('W'))
                  Positioned(
                    left: spot.dx - 17, top: spot.dy - 17,
                    child: const Text('⚽', style: TextStyle(fontSize: 34)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
