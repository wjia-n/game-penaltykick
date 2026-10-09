import 'dart:math';

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/stadium_themes.dart';
import '../widgets/name_field.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: match setup (vs AI / pass-and-play), renameable seats,
/// stadium/ball/kit customization, and navigation to Pro + settings.
class MenuScreen extends StatefulWidget {
  final KickAudio audio;
  final KickSettings settings;
  final StoreService store;
  const MenuScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  StadiumThemeDef get _t => StadiumThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) => Scaffold(
        backgroundColor: t.panelDark,
        appBar: AppBar(
          backgroundColor: t.panelDark,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('PENALTY KICK',
              style: TextStyle(
                  color: t.accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                widget.audio.click();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                        audio: widget.audio, settings: s)));
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(t),
                const SizedBox(height: 16),
                _sectionTitle(t, 'MATCH SETUP'),
                _modePicker(t, s),
                const SizedBox(height: 10),
                if (s.mode != 'passplay') _difficultyPicker(t, s),
                const SizedBox(height: 10),
                _nameEditors(t, s),
                const SizedBox(height: 16),
                _sectionTitle(t, 'STADIUM'),
                _themeGrid(t, s),
                const SizedBox(height: 16),
                _sectionTitle(t, 'BALL'),
                _ballRow(t, s),
                const SizedBox(height: 16),
                _sectionTitle(t, 'KIT'),
                _kitRow(t, s),
                const SizedBox(height: 24),
                _playButton(t),
                const SizedBox(height: 10),
                _proButton(t, s),
                const SizedBox(height: 10),
                _howTo(t),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(StadiumThemeDef t) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/penaltykick_logo.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 16,
            bottom: 12,
            child: Text(
              '5 kicks each. Then sudden death.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(StadiumThemeDef t, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: t.accent,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _modePicker(StadiumThemeDef t, KickSettings s) {
    return Row(
      children: [
        Expanded(
          child: _choiceCard(
            t,
            selected: s.mode == 'ai',
            title: '🤖 Vs AI',
            subtitle: 'Shootout · 3 difficulties',
            onTap: () {
              widget.audio.click();
              s.setMode('ai');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _choiceCard(
            t,
            selected: s.mode == 'passplay',
            title: '👥 Pass & Play',
            subtitle: '2 players · one phone',
            onTap: () {
              widget.audio.click();
              s.setMode('passplay');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _choiceCard(
            t,
            selected: s.mode == 'practice',
            title: '🎯 Practice',
            subtitle: 'Endless shooting',
            onTap: () {
              widget.audio.click();
              s.setMode('practice');
            },
          ),
        ),
      ],
    );
  }

  Widget _choiceCard(StadiumThemeDef t,
      {required bool selected,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? Colors.white : Colors.white24, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: selected ? Colors.white70 : Colors.white38,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _difficultyPicker(StadiumThemeDef t, KickSettings s) {
    const names = ['Easy', 'Medium', 'Hard'];
    final practice = s.mode == 'practice';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(practice ? 'Keeper AI difficulty' : 'AI difficulty',
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        if (i == 2 && !s.isPro) {
                          _proNudge(t);
                          return;
                        }
                        s.setDifficulty(i);
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: s.difficulty == i
                              ? t.accent
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: s.difficulty == i
                                ? Colors.white
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (i == 2 && !s.isPro)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.lock,
                                    size: 13, color: Colors.white70),
                              ),
                            Text(names[i],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!practice)
            Row(
              children: [
                const Text('AI plays as: ',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                for (int i = 0; i < 2; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Player ${i + 1}'),
                      selected: s.botSeat == i,
                      onSelected: (_) {
                        widget.audio.click();
                        s.setBotSeat(i);
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _nameEditors(StadiumThemeDef t, KickSettings s) {
    final practice = s.mode == 'practice';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Player names',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          for (int i = 0; i < 2; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 0 ? 8 : 0),
              child: PlayerNameField(
                settings: s,
                index: i,
                dark: true,
                label: ((s.mode == 'ai' && s.botSeat == i) ||
                        (practice && i == 1))
                    ? 'Player ${i + 1} (AI)'
                    : 'Player ${i + 1}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _themeGrid(StadiumThemeDef t, KickSettings s) {
    final themes = StadiumThemes.all;
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: themes.length,
          itemBuilder: (_, i) {
            final th = themes[i];
            final selected = s.themeId == th.id;
            final locked = th.isPro && !s.isPro;
            return GestureDetector(
              onTap: () {
                widget.audio.click();
                if (locked) {
                  _proNudge(t);
                  return;
                }
                s.setTheme(th.id);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2.5 : 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [th.skyTop, th.grassDark],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        th.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 3)
                          ],
                        ),
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: Icon(Icons.lock,
                            size: 13, color: Colors.white),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              widget.audio.click();
              if (!s.isPro) {
                _proNudge(t);
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CustomThemeScreen(
                      audio: widget.audio, settings: s)));
            },
            icon: Icon(
                s.isPro ? Icons.palette : Icons.lock,
                color: Colors.white70,
                size: 16),
            label: const Text('Design my own stadium',
                style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ballRow(StadiumThemeDef t, KickSettings s) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BallStyles.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final b = BallStyles.all[i];
          final selected = s.ballStyle == i;
          final locked = BallStyles.isPro(i) && !s.isPro;
          return GestureDetector(
            onTap: () {
              widget.audio.click();
              if (locked) {
                _proNudge(t);
                return;
              }
              s.setBallStyle(i);
            },
            child: Container(
              width: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? t.accent : Colors.white24,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(30, 30),
                        painter: _MiniBallPainter(ball: b),
                      ),
                      if (locked)
                        const Icon(Icons.lock,
                            size: 14, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(b.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kitRow(StadiumThemeDef t, KickSettings s) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: KitStyles.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = s.kitStyle == i;
          final locked = KitStyles.isPro(i) && !s.isPro;
          return GestureDetector(
            onTap: () {
              widget.audio.click();
              if (locked) {
                _proNudge(t);
                return;
              }
              s.setKitStyle(i);
            },
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? t.accent : Colors.white24,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: KitStyles.all[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white54, width: 1.5),
                        ),
                      ),
                      if (locked)
                        const Icon(Icons.lock,
                            size: 13, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(KitStyles.names[i],
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _playButton(StadiumThemeDef t) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: () {
          widget.audio.click();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameScreen(
                  audio: widget.audio, settings: widget.settings)));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
        child: const Text('KICK OFF',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3)),
      ),
    );
  }

  Widget _proButton(StadiumThemeDef t, KickSettings s) {
    return OutlinedButton.icon(
      onPressed: () {
        widget.audio.click();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProScreen(
                audio: widget.audio,
                settings: s,
                store: widget.store)));
      },
      icon: Icon(Icons.workspace_premium,
          color: s.isPro ? Colors.amber : t.accent),
      label: Text(
        s.isPro ? 'PRO active — thank you!' : 'Go PRO — unlock everything',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: t.accent, width: 1.5),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _howTo(StadiumThemeDef t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'HOW TO PLAY\n'
        '• You and your rival take turns as striker and keeper — 5 kicks each.\n'
        '• Striker: tap a goal zone to shoot, or drag toward your target for a drag-to-shoot. Corners beat keepers… but can fly wide!\n'
        '• Keeper: tap a zone to dive. Study the striker\'s habits.\n'
        '• On Medium/Hard, watch the wind — it drifts the ball in flight.\n'
        '• Level on kicks after 5 each? Sudden death decides it.\n'
        '• The AI studies YOUR shooting patterns — mix it up!\n'
        '• Practice mode: endless shooting against the keeper, no pressure.',
        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
      ),
    );
  }

  void _proNudge(StadiumThemeDef t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('That\'s a PRO feature — check out PRO!',
            style: TextStyle(color: Colors.white)),
        backgroundColor: t.panelDark,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'PRO',
          textColor: t.accent,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProScreen(
                    audio: widget.audio,
                    settings: widget.settings,
                    store: widget.store)));
          },
        ),
      ),
    );
  }
}

/// Tiny procedural ball preview for the picker row.
class _MiniBallPainter extends CustomPainter {
  final BallStyleDef ball;
  _MiniBallPainter({required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = ball.panel);
    canvas.drawCircle(c, r * 0.35, Paint()..color = ball.patch);
    for (int i = 0; i < 5; i++) {
      final a = i / 5 * 2 * 3.14159 + 0.5;
      final p = c + Offset(cos(a), sin(a)) * r * 0.8;
      canvas.drawCircle(p, r * 0.28, Paint()..color = ball.patch);
    }
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.black26
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
