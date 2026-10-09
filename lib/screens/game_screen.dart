import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/penaltykick_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/stadium_themes.dart';

/// Penalty Kick match screen: painted stadium, visible AI turns, narration.
class GameScreen extends StatefulWidget {
  final KickAudio audio;
  final KickSettings settings;
  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late PenaltyKickEngine _engine;
  late AnimationController _cosmetic; // bot aim shuffles, idle motion
  bool _dialogShown = false;
  Offset? _dragAim; // striker's drag aim, in goal-rect-local coordinates

  StadiumThemeDef get _t => StadiumThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    final practice = s.mode == 'practice';
    final players = [
      PenkPlayer(
          name: s.playerNames[0],
          isBot: practice
              ? false
              : (s.mode == 'ai' && s.botSeat == 0)),
      PenkPlayer(
          name: s.playerNames[1],
          isBot: practice ? true : (s.mode == 'ai' && s.botSeat == 1)),
    ];
    _engine = PenaltyKickEngine(
      players: players,
      botDifficulty: BotDifficulty.values[s.difficulty.clamp(0, 2)],
      practice: practice,
    );
    _engine.onEvent = _onEngineEvent;
    _cosmetic = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    widget.audio.startGameMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.audio.gameStart();
    });
  }

  void _onEngineEvent(PenkEvent e) {
    final a = widget.audio;
    switch (e) {
      case PenkEvent.matchStart:
        a.gameStart();
      case PenkEvent.shotChosen:
        a.click();
      case PenkEvent.kickFlying:
        a.kick();
      case PenkEvent.goal:
        a.goal();
      case PenkEvent.save:
        a.save();
      case PenkEvent.miss:
        a.miss();
      case PenkEvent.invalid:
        a.invalid();
      case PenkEvent.humanWon:
        a.win();
      case PenkEvent.botWon:
        a.lose();
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    _cosmetic.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  Future<void> _onMatchOver() async {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;
    final s = widget.settings;
    final humanWon =
        _engine.winner != null && !_engine.players[_engine.winner!].isBot;
    await s.recordGame(humanWon: humanWon);
    // Ask for a review at a sensible moment: a few matches in, human played.
    if (s.gamesPlayed >= 3) {
      try {
        if (await InAppReview.instance.isAvailable()) {
          await InAppReview.instance.requestReview();
        }
      } catch (_) {}
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        engine: _engine,
        audio: widget.audio,
        onRematch: () {
          Navigator.of(context).pop();
          setState(() {
            _dialogShown = false;
            _engine.restart();
          });
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _pauseGame() {
    widget.audio.click();
    _engine.setPaused(true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        audio: widget.audio,
        onResume: () {
          Navigator.of(context).pop();
          _engine.setPaused(false);
        },
        onRestart: () {
          Navigator.of(context).pop();
          setState(() {
            _dialogShown = false;
            _engine.restart();
          });
        },
        onQuit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListenableBuilder(
      listenable: _engine,
      builder: (_, _) {
        if (_engine.over) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onMatchOver());
        }
        return Scaffold(
          backgroundColor: t.panelDark,
          appBar: AppBar(
            backgroundColor: t.panelDark,
            foregroundColor: Colors.white,
            title: Text(_engine.practice ? 'Practice' : 'Penalty Kick',
                style: TextStyle(
                    color: t.accent, fontWeight: FontWeight.w900)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                widget.audio.click();
                Navigator.of(context).pop();
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Restart match',
                onPressed: () {
                  widget.audio.click();
                  setState(() {
                    _dialogShown = false;
                    _engine.restart();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                tooltip: 'Pause',
                onPressed: _pauseGame,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_engine.practice) _practiceBoard(t) else _scoreboard(t),
                _banner(t),
                if (_engine.windLevel > 0 &&
                    _engine.phase == Phase.strikerAim)
                  _windLine(t),
                Expanded(child: _pitch(t)),
                _roundLine(t),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _practiceBoard(StadiumThemeDef t) {
    return Container(
      color: t.panelDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pStat('GOALS', '${_engine.practiceGoals}'),
          _pStat('SHOTS', '${_engine.practiceShots}'),
          _pStat('STREAK', '${_engine.practiceStreak}'),
          _pStat('BEST', '${_engine.practiceBest}'),
        ],
      ),
    );
  }

  Widget _pStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ],
    );
  }

  /// Wind indicator: direction + strength, shown before the striker shoots.
  Widget _windLine(StadiumThemeDef t) {
    final right = _engine.windDx >= 0;
    final label = _engine.windLevel >= 2 ? 'Strong wind' : 'Light breeze';
    return Container(
      color: t.panelDark,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(right ? Icons.arrow_forward : Icons.arrow_back,
              size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text('🌬️ $label — aim into it!',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _scoreboard(StadiumThemeDef t) {
    return Container(
      color: t.panelDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (int p = 0; p < 2; p++) ...[
            if (p == 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${_engine.players[0].goals} – ${_engine.players[1].goals}',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
            Expanded(
              child: _playerCard(t, p),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerCard(StadiumThemeDef t, int p) {
    final pl = _engine.players[p];
    final active = !_engine.over &&
        ((p == _engine.strikerIdx && _engine.phase == Phase.strikerAim) ||
            (p == _engine.keeperIdx && _engine.phase == Phase.keeperAim));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? t.accent.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Colors.white : Colors.white24,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pl.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (pl.isBot)
                const Text('🤖', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final m in _engine.marks[p])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: _markChip(m),
                ),
              for (int i = _engine.marks[p].length;
                  i < kicksPerSide;
                  i++)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.circle_outlined,
                      size: 13, color: Colors.white30),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _markChip(KickResult m) {
    switch (m) {
      case KickResult.goal:
        return const Icon(Icons.check_circle,
            size: 14, color: Color(0xFF7ED957));
      case KickResult.save:
        return const Icon(Icons.front_hand,
            size: 14, color: Color(0xFFFFD166));
      case KickResult.miss:
        return const Icon(Icons.cancel, size: 14, color: Color(0xFFEF476F));
    }
  }

  Widget _banner(StadiumThemeDef t) {
    String text = _engine.banner;
    if (_engine.phase == Phase.strikerAim && _engine.striker.isBot) {
      text = '${_engine.striker.name} is lining up the shot…';
    } else if (_engine.phase == Phase.keeperAim && _engine.keeper.isBot) {
      text = '${_engine.keeper.name} is reading the run-up…';
    }
    return Container(
      width: double.infinity,
      color: t.panelDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: AnimatedBuilder(
        animation: _cosmetic,
        builder: (_, _) {
          final busy = _engine.phase == Phase.strikerAim ||
              _engine.phase == Phase.keeperAim;
          final dots = busy
              ? '.' * (1 + ((_cosmetic.value * 3).floor() % 3))
              : '';
          return Text(
            text + dots,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }

  Widget _roundLine(StadiumThemeDef t) {
    final label = _engine.practice
        ? 'Practice kick ${_engine.kickIndex + 1} — endless!'
        : _engine.suddenDeath
            ? 'Sudden death — every kick counts!'
            : 'Round ${_engine.round.clamp(1, kicksPerSide)} of $kicksPerSide';
    return Text(
      label,
      style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w700),
    );
  }

  Widget _pitch(StadiumThemeDef t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final goal = _goalRect(Size(c.maxWidth, c.maxHeight));
          final aimAbs = _dragAim == null ||
                  !_engine.awaitingStriker
              ? null
              : Offset(goal.left + _dragAim!.dx,
                  goal.top + _dragAim!.dy);
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_cosmetic, _engine]),
                  builder: (_, _) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _StadiumPainter(
                      theme: t,
                      engine: _engine,
                      ballStyle:
                          BallStyles.all[widget.settings.ballStyle],
                      kitColor: KitStyles.all[widget.settings.kitStyle],
                      cosmetic: _cosmetic.value,
                      aimGuide: aimAbs,
                    ),
                  ),
                ),
              ),
              // Tappable goal zones for the human in an aim phase.
              _zoneOverlay(Size(c.maxWidth, c.maxHeight), t),
              // Big result flash during settling.
              if (_engine.phase == Phase.settling && _engine.lastResult != null)
                _resultFlash(),
            ],
          );
        },
      ),
    );
  }

  /// Aim overlay: tap a zone to shoot/dive, or (striker) drag toward a
  /// target for a drag-to-shoot. Quick taps still work — the gesture arena
  /// gives the tap to a tap and the drag to a pan, so both coexist.
  Widget _zoneOverlay(Size size, StadiumThemeDef t) {
    final aiming = _engine.awaitingStriker || _engine.awaitingKeeper;
    if (!aiming) return const SizedBox.shrink();
    final g = _goalRect(size);
    final canDrag = _engine.awaitingStriker;
    return Positioned(
      left: g.left,
      top: g.top,
      width: g.width,
      height: g.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _fireAt(g, d.localPosition),
        onPanUpdate: canDrag
            ? (d) => setState(() => _dragAim = d.localPosition)
            : null,
        onPanEnd: canDrag
            ? (_) {
                final aim = _dragAim;
                setState(() => _dragAim = null);
                if (aim == null) return;
                // Released outside the goal: cancel the drag, no shot.
                if (aim.dx < 0 ||
                    aim.dx > g.width ||
                    aim.dy < 0 ||
                    aim.dy > g.height) {
                  return;
                }
                _fireAt(g, aim);
              }
            : null,
        onPanCancel: () => setState(() => _dragAim = null),
        child: AnimatedBuilder(
          animation: _cosmetic,
          builder: (_, _) {
            final pulse = 0.25 + 0.2 * sin(_cosmetic.value * 2 * pi * 2);
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3),
              itemCount: 6,
              itemBuilder: (_, z) {
                return Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: pulse),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.sports_soccer,
                        color: Colors.white, size: 26),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Convert an overlay-local point to a goal zone and fire it.
  void _fireAt(Rect g, Offset local) {
    final col =
        (local.dx / g.width * 3).floor().clamp(0, 2);
    final row =
        (local.dy / g.height * 2).floor().clamp(0, 1);
    final zone = row * 3 + col;
    if (_engine.awaitingStriker) {
      _engine.chooseShot(zone);
    } else if (_engine.awaitingKeeper) {
      _engine.chooseDive(zone);
    }
    setState(() => _dragAim = null);
  }

  Widget _resultFlash() {
    final r = _engine.lastResult!;
    final text = r == KickResult.goal
        ? 'GOAL!'
        : r == KickResult.save
            ? 'SAVED!'
            : 'WIDE!';
    final color = r == KickResult.goal
        ? const Color(0xFF7ED957)
        : r == KickResult.save
            ? const Color(0xFFFFD166)
            : const Color(0xFFEF476F);
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 3),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

// Geometry shared by painter and overlay.
Rect _goalRect(Size s) {
  final gw = s.width * 0.8;
  final gh = s.height * 0.42;
  return Rect.fromLTWH((s.width - gw) / 2, s.height * 0.05, gw, gh);
}

Offset _zoneCenter(Rect goal, int zone) {
  return Offset(
    goal.left + ((zone % 3) + 0.5) / 3 * goal.width,
    goal.top + ((zone ~/ 3) + 0.5) / 2 * goal.height,
  );
}

/// Paints the whole stadium: sky, stands with crowd, striped grass, goal
/// with net, penalty spot, keeper, striker and the physical ball.
class _StadiumPainter extends CustomPainter {
  final StadiumThemeDef theme;
  final PenaltyKickEngine engine;
  final BallStyleDef ballStyle;
  final Color kitColor;
  final double cosmetic; // 0..1 looping idle time
  final Offset? aimGuide; // striker's drag aim, absolute pitch coords

  _StadiumPainter({
    required this.theme,
    required this.engine,
    required this.ballStyle,
    required this.kitColor,
    required this.cosmetic,
    this.aimGuide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintStands(canvas, size);
    _paintGrass(canvas, size);
    _paintGoal(canvas, size);
    _paintSpot(canvas, size);
    _paintStriker(canvas, size);
    _paintKeeper(canvas, size);
    _paintBall(canvas, size);
    if (aimGuide != null) _paintAimGuide(canvas, size);
  }

  /// Dotted aim line from the penalty spot to the striker's fingertip.
  void _paintAimGuide(Canvas canvas, Size size) {
    final aim = aimGuide!;
    final spot = Offset(size.width / 2, size.height * 0.88);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    // Dashes.
    const dash = 10.0;
    const gap = 7.0;
    final total = (aim - spot).distance;
    final dir = (aim - spot) / total;
    double d = 0;
    while (d < total) {
      final a = spot + dir * d;
      final b = spot + dir * (d + dash).clamp(0.0, total).toDouble();
      canvas.drawLine(a, b, line);
      d += dash + gap;
    }
    // Target reticle.
    canvas.drawCircle(
        aim,
        16,
        Paint()
          ..color = theme.accent.withValues(alpha: 0.9)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        aim, 4, Paint()..color = Colors.white.withValues(alpha: 0.95));
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.22);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.skyTop, theme.skyBottom],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintStands(Canvas canvas, Size size) {
    final top = size.height * 0.10;
    final h = size.height * 0.14;
    final rect = Rect.fromLTWH(0, top, size.width, h);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.standDark, theme.standLight],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    // Crowd: deterministic dots.
    final rand = Random(42);
    final dot = Paint();
    final shirtColors = [
      const Color(0xFFD94F3D),
      const Color(0xFF3D7AD9),
      const Color(0xFFF2D13D),
      const Color(0xFFF2F2F2),
      const Color(0xFF7A3EB8),
    ];
    for (int i = 0; i < 260; i++) {
      final x = rand.nextDouble() * size.width;
      final y = top + 4 + rand.nextDouble() * (h - 8);
      dot.color = shirtColors[rand.nextInt(shirtColors.length)]
          .withValues(alpha: 0.85);
      canvas.drawCircle(Offset(x, y), 1.6 + rand.nextDouble() * 1.4, dot);
    }
    // Stand roof line.
    canvas.drawRect(
      Rect.fromLTWH(0, top - 4, size.width, 6),
      Paint()..color = theme.standDark,
    );
  }

  void _paintGrass(Canvas canvas, Size size) {
    final top = size.height * 0.24;
    // Mowing stripes.
    const stripes = 6;
    final sh = (size.height - top) / stripes;
    for (int i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, top + i * sh, size.width, sh + 1),
        Paint()..color = i.isEven ? theme.grassLight : theme.grassDark,
      );
    }
    // Penalty box lines.
    final line = Paint()
      ..color = theme.lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final boxW = size.width * 0.6;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.47),
        width: boxW,
        height: size.height * 0.42,
      ),
      line,
    );
  }

  void _paintGoal(Canvas canvas, Size size) {
    final goal = _goalRect(size);
    // Net: light grid behind.
    final net = Paint()
      ..color = theme.netColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (double x = goal.left; x <= goal.right; x += 9) {
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (double y = goal.top; y <= goal.bottom; y += 9) {
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
    // Posts + crossbar.
    final post = Paint()
      ..color = theme.postColor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(goal.topLeft, goal.bottomLeft, post);
    canvas.drawLine(goal.topRight, goal.bottomRight, post);
    canvas.drawLine(goal.topLeft, goal.topRight, post);
  }

  void _paintSpot(Canvas canvas, Size size) {
    final spot = Offset(size.width / 2, size.height * 0.88);
    canvas.drawCircle(
        spot, 5, Paint()..color = theme.lineColor.withValues(alpha: 0.9));
  }

  void _paintStriker(Canvas canvas, Size size) {
    // Idle during aim; small run-up shuffle when the bot is aiming.
    double dx = 0;
    if (engine.phase == Phase.strikerAim && engine.striker.isBot) {
      dx = sin(cosmetic * 2 * pi * 2) * 10;
    }
    final base = Offset(size.width / 2 + dx - 34, size.height * 0.84);
    _drawFigure(canvas, base, 1.0, kitColor,
        lean: 0.15, armsUp: false, skin: const Color(0xFFE8B88A));
  }

  void _paintKeeper(Canvas canvas, Size size) {
    final goal = _goalRect(size);
    final rest = Offset(goal.center.dx, goal.top + goal.height * 0.62);
    Offset pos = rest;
    double lean = 0; // radians, + = diving right
    bool armsUp = false;
    final flying = engine.phase == Phase.flying && engine.flight != null;
    if (flying) {
      final f = engine.flight!;
      final target = _zoneCenter(goal, f.diveZone);
      final eased = _easeOut(f.progress);
      pos = Offset.lerp(rest, target + const Offset(0, 10), eased)!;
      final dir = (target.dx - rest.dx).sign;
      lean = dir * eased * 1.1;
      armsUp = true;
    } else if (engine.phase == Phase.settling ||
        engine.phase == Phase.over) {
      // Hold the final dive pose briefly.
      if (engine.diveZone >= 0) {
        final target = _zoneCenter(goal, engine.diveZone);
        pos = target + const Offset(0, 10);
        lean = (target.dx - rest.dx).sign * 1.1;
        armsUp = true;
      }
    } else if (engine.phase == Phase.keeperAim && engine.keeper.isBot) {
      // Shuffle side to side while reading the run-up.
      pos = rest + Offset(sin(cosmetic * 2 * pi * 3) * 14, 0);
    }
    _drawFigure(canvas, pos, 1.15, theme.panelDark,
        lean: lean, armsUp: armsUp, skin: const Color(0xFFD9A06E));
  }

  /// Stylized player figure: head, torso, arms, legs. Drawn, not an asset.
  void _drawFigure(Canvas canvas, Offset feet, double s, Color kit,
      {required double lean, required bool armsUp, required Color skin}) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(lean);
    canvas.scale(s);
    final kitPaint = Paint()..color = kit;
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.85);
    final skinPaint = Paint()..color = skin;
    // Legs.
    canvas.drawRect(const Rect.fromLTWH(-11, -34, 9, 34), darkPaint);
    canvas.drawRect(const Rect.fromLTWH(2, -34, 9, 34), darkPaint);
    // Torso (jersey).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, -66, 28, 36), const Radius.circular(9)),
      kitPaint,
    );
    // Arms.
    final armY = armsUp ? -78.0 : -58.0;
    final armSpread = armsUp ? 30.0 : 20.0;
    canvas.drawLine(const Offset(-12, -60), Offset(-armSpread, armY),
        skinPaint..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(12, -60), Offset(armSpread, armY),
        skinPaint..strokeWidth = 8..strokeCap = StrokeCap.round);
    // Head.
    canvas.drawCircle(const Offset(0, -78), 11, skinPaint);
    canvas.restore();
  }

  void _paintBall(Canvas canvas, Size size) {
    final goal = _goalRect(size);
    final spot = Offset(size.width / 2, size.height * 0.88);
    Offset pos = spot;
    double r = 15;
    final flying = engine.phase == Phase.flying && engine.flight != null;
    if (flying) {
      final f = engine.flight!;
      // The flight target is the decided landing spot: zone center, pushed
      // wide on a miss and drifted by the wind — matching the settle pose.
      final target = _zoneCenter(goal, f.shotZone) +
          Offset((f.landOffset.dx + engine.windDx) * goal.width,
              (f.landOffset.dy + engine.windDy) * goal.height);
      final eased = _easeIn(f.progress);
      pos = Offset.lerp(spot, target, eased)!;
      // Ball arcs: lift mid-flight, shrink slightly with "distance".
      final arc = sin(f.progress * pi) * size.height * 0.05;
      pos = pos + Offset(0, -arc);
      r = 15 - 4 * sin(f.progress * pi);
    } else if ((engine.phase == Phase.settling ||
            engine.phase == Phase.over) &&
        engine.shotZone >= 0 &&
        engine.lastResult != null) {
      final land = engine.lastLandOffset;
      pos = _zoneCenter(goal, engine.shotZone) +
          Offset((land.dx + engine.windDx) * goal.width,
              (land.dy + engine.windDy) * goal.height);
      r = 11;
    }
    _drawBall(canvas, pos, r);
  }

  /// A real leather ball: paneled sphere with patches and a highlight.
  void _drawBall(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..color = ballStyle.panel);
    // Patches.
    final patch = Paint()..color = ballStyle.patch;
    canvas.drawCircle(c, r * 0.34, patch);
    for (int i = 0; i < 5; i++) {
      final a = i / 5 * 2 * pi + 0.5;
      final p = c + Offset(cos(a), sin(a)) * r * 0.85;
      canvas.drawCircle(p, r * 0.30, patch);
    }
    // Seams.
    final seam = Paint()
      ..color = ballStyle.seam
      ..strokeWidth = max(1.0, r * 0.05)
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final a = i / 5 * 2 * pi + 0.5;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 0.34,
          c + Offset(cos(a), sin(a)) * r * 0.62, seam);
    }
    canvas.restore();
    // Outline + highlight for physicality.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        c + Offset(-r * 0.35, -r * 0.35),
        r * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.35));
    // Shadow on the grass.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy + r + 6), width: r * 1.7, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  double _easeIn(double t) => t * t;

  @override
  bool shouldRepaint(covariant _StadiumPainter old) => true;
}

class _PauseDialog extends StatelessWidget {
  final KickAudio audio;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseDialog(
      {required this.audio,
      required this.onResume,
      required this.onRestart,
      required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paused'),
      content: const Text('Take a breather. The shootout will wait.'),
      actions: [
        TextButton(
            onPressed: () {
              audio.click();
              onResume();
            },
            child: const Text('Resume')),
        TextButton(
            onPressed: () {
              audio.click();
              onRestart();
            },
            child: const Text('Restart')),
        TextButton(
            onPressed: () {
              audio.click();
              onQuit();
            },
            child: const Text('Quit')),
      ],
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final PenaltyKickEngine engine;
  final KickAudio audio;
  final VoidCallback onRematch;
  final VoidCallback onMenu;
  const _ResultDialog(
      {required this.engine,
      required this.audio,
      required this.onRematch,
      required this.onMenu});

  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.gameswajiha.penaltykick';

  @override
  Widget build(BuildContext context) {
    final w = engine.winner;
    final winnerName = w != null ? engine.players[w].name : 'Nobody';
    final score = '${engine.players[0].goals} – ${engine.players[1].goals}';
    final humanWon = w != null && !engine.players[w].isBot;
    return AlertDialog(
      title: Text(humanWon ? '🏆 You win!' : '$winnerName wins!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${engine.players[0].name}  $score  ${engine.players[1].name}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            engine.suddenDeath
                ? 'Settled in sudden death. Ice cold.'
                : 'Clinical from the spot.',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            audio.click();
            await SharePlus.instance.share(ShareParams(
              text:
                  'I just played Penalty Kick! Can you beat my shootout? $_storeUrl',
              subject: 'Penalty Kick',
            ));
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
        TextButton(
            onPressed: () {
              audio.click();
              onRematch();
            },
            child: const Text('Rematch')),
        TextButton(
            onPressed: () {
              audio.click();
              onMenu();
            },
            child: const Text('Menu')),
      ],
    );
  }
}
