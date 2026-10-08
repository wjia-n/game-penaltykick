import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const PenaltyKickApp());

class PenaltyKickApp extends StatelessWidget {
  const PenaltyKickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.comicBurst,
      title: 'Penalty Kick',
      tagline: 'Score past the keeper in penalty shootouts',
      emoji: '⚽',
      slug: 'penaltykick',
      howToPlay:
          '• Take turns as striker and keeper — 5 kicks each, then sudden death.\n• Striker: tap a zone of the goal to place your shot. Corners are riskier!\n• Keeper: tap a zone to dive. Read the striker\'s habits. 🧤\n• Most goals wins. Solo? The bot studies your shooting patterns. 🤖',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => PenaltyKickScreen(players: players, callbacks: cb),
    );
  }
}
