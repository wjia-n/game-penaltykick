import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/stadium_themes.dart';

/// Custom stadium creator (PRO): pick the sky, stands, grass and accent
/// colors. Everything persists; the picker shows the live result.
class CustomThemeScreen extends StatefulWidget {
  final KickAudio audio;
  final KickSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _swatches = [
    0xFF6FA8DC,
    0xFF4A3A7A,
    0xFF5A6A7A,
    0xFF2A9AC9,
    0xFFC97A3A,
    0xFF0E1A3A,
    0xFF101C48,
    0xFF3A4A5A,
    0xFF4E9A3D,
    0xFF3A7A2C,
    0xFF5E8A3A,
    0xFF2C6624,
    0xFFE07A2B,
    0xFFC93A2B,
    0xFF2B6AC9,
    0xFFF0B429,
    0xFFD9DEE2,
    0xFFF4F7EF,
    0xFF22262A,
    0xFFF8F8F4,
  ];

  static const _labels = {
    'skyTop': 'Sky (top)',
    'skyBottom': 'Sky (horizon)',
    'standDark': 'Stands (dark)',
    'standLight': 'Stands (light)',
    'grassLight': 'Grass (light stripe)',
    'grassDark': 'Grass (dark stripe)',
    'lineColor': 'Pitch lines',
    'netColor': 'Net',
    'accent': 'Accent',
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final t = s.customTheme;
        return Scaffold(
          backgroundColor: t.panel,
          appBar: AppBar(
            backgroundColor: t.panelDark,
            foregroundColor: Colors.white,
            title: const Text('Design my stadium'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                widget.audio.click();
                Navigator.of(context).pop();
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  s.resetCustomColors();
                },
                child: const Text('Reset',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: Column(
            children: [
              _preview(t),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final key in _labels.keys)
                      _colorRow(s, key, _labels[key]!),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.audio.click();
                          s.setTheme('custom');
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('USE MY STADIUM',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _preview(StadiumThemeDef t) {
    return Container(
      height: 130,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.skyTop, t.grassDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  t.standDark,
                  t.standLight,
                ]),
              ),
            ),
          ),
          Center(
            child: Text(
              'MY STADIUM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 3,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: const Offset(0, 2),
                      blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(KickSettings s, String key, String label) {
    final current = Color(s.customColors[key] ?? 0xFF000000);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.black26, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _swatches)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    s.setCustomColor(key, 0xFF000000 | c);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current.value == (0xFF000000 | c)
                            ? Colors.black
                            : Colors.black12,
                        width: current.value == (0xFF000000 | c)
                            ? 3
                            : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
