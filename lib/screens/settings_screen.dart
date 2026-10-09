import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/stadium_themes.dart';
import '../widgets/name_field.dart';

/// Settings: audio toggles + volume, player names, stats.
class SettingsScreen extends StatefulWidget {
  final KickAudio audio;
  final KickSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
        backgroundColor: t.panel,
        appBar: AppBar(
          backgroundColor: t.panelDark,
          foregroundColor: Colors.white,
          title: const Text('Settings'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _card(t, [
              _switchRow(t, 'Music', s.musicOn, (v) {
                s.setMusic(v);
                widget.audio.configure(
                    musicOn: v,
                    sfxOn: s.sfxOn,
                    volume: s.volume);
                if (v) {
                  widget.audio.startMenuMusic();
                }
              }),
              _switchRow(t, 'Sound effects', s.sfxOn, (v) {
                s.setSfx(v);
                widget.audio.configure(
                    musicOn: s.musicOn, sfxOn: v, volume: s.volume);
                if (v) widget.audio.click();
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.volume_up, color: t.accent),
                  Expanded(
                    child: Slider(
                      value: s.volume,
                      activeColor: t.accent,
                      onChanged: (v) {
                        s.setVolume(v);
                        widget.audio.configure(
                            musicOn: s.musicOn,
                            sfxOn: s.sfxOn,
                            volume: v);
                      },
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            _card(t, [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Player names',
                    style: TextStyle(
                        color: t.textOn,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              for (int i = 0; i < 2; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == 0 ? 8 : 0),
                  child: PlayerNameField(
                    settings: s,
                    index: i,
                    label: 'Player ${i + 1}',
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            _card(t, [
              Text('Career stats',
                  style: TextStyle(
                      color: t.textOn,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 8),
              _statRow(t, 'Matches played', '${s.gamesPlayed}'),
              _statRow(t, 'Shootouts won', '${s.wins}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(StadiumThemeDef t, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _switchRow(StadiumThemeDef t, String label, bool value,
      void Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: t.textOn,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        Switch(
          value: value,
          activeColor: t.accent,
          onChanged: (v) {
            widget.audio.click();
            onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _statRow(StadiumThemeDef t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: t.textDim, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: t.textOn,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
