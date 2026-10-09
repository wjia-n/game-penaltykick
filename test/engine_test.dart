import 'package:flutter_test/flutter_test.dart';
import 'package:penaltykick/engine/penaltykick_engine.dart';

PenaltyKickEngine twoHumans() => PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'A', isBot: false),
        PenkPlayer(name: 'B', isBot: false),
      ],
      botDifficulty: BotDifficulty.medium,
    );

/// Drive one full kick with forced outcome, bypassing real timers.
Future<void> playKick(PenaltyKickEngine e, int shot, int dive,
    KickResult forced) async {
  e.chooseShot(shot);
  e.forcedResult = forced;
  e.chooseDive(dive);
  await Future.delayed(const Duration(milliseconds: 1100));
  await Future.delayed(const Duration(milliseconds: 1700));
}

void main() {
  test('goal scored when keeper dives elsewhere', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    await playKick(e, 0, 5, KickResult.goal);
    expect(e.players[0].goals, 1);
    expect(e.marks[0], [KickResult.goal]);
    expect(e.kickIndex, 1);
    expect(e.phase, Phase.strikerAim);
  });

  test('save when keeper matches the shot zone', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    e.chooseShot(2);
    e.forcedResult = KickResult.save;
    e.chooseDive(2);
    await Future.delayed(const Duration(milliseconds: 1100));
    await Future.delayed(const Duration(milliseconds: 1700));
    expect(e.players[0].goals, 0);
    expect(e.marks[0], [KickResult.save]);
  });

  test('early decision ends the shootout', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    // A scores 3, B scores 0 in the first three pairs -> 3-0, B has 2 left.
    for (int i = 0; i < 3; i++) {
      await playKick(e, 0, 5, KickResult.goal); // A striker
      await playKick(e, 0, 0, KickResult.save); // B striker, saved
      if (e.over) break;
    }
    expect(e.over, true);
    expect(e.winner, 0);
  });

  test('sudden death decides a tied shootout', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    // 5 kicks each, all goals -> 5-5 tie -> sudden death.
    for (int i = 0; i < 5; i++) {
      await playKick(e, 0, 5, KickResult.goal);
      await playKick(e, 0, 5, KickResult.goal);
    }
    expect(e.over, false);
    expect(e.suddenDeath, true);
    // Sudden death pair: A scores, B is saved -> A wins.
    await playKick(e, 0, 5, KickResult.goal);
    expect(e.over, false); // pair not complete yet
    await playKick(e, 0, 0, KickResult.save);
    expect(e.over, true);
    expect(e.winner, 0);
  });

  test('human input rejected in wrong phase', () {
    final e = twoHumans();
    addTearDown(e.dispose);
    e.chooseDive(3); // keeper phase not active
    expect(e.phase, Phase.strikerAim);
    expect(e.diveZone, -1);
  });

  test('restart resets all state', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    await playKick(e, 0, 5, KickResult.goal);
    e.restart();
    expect(e.kickIndex, 0);
    expect(e.players[0].goals, 0);
    expect(e.marks[0], isEmpty);
    expect(e.over, false);
    expect(e.phase, Phase.strikerAim);
  });

  test('hard bot keeper reacts to striker streak', () {
    final e = PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'Human', isBot: false),
        PenkPlayer(name: 'Bot', isBot: true),
      ],
      botDifficulty: BotDifficulty.hard,
    );
    addTearDown(e.dispose);
    // Human shot zone 0 twice in a row; hard keeper commits to the streak.
    e.shotHistory[0].addAll([0, 0]);
    expect(e.debugBotDiveZone(), 0);
  });

  test('hard bot striker avoids keeper favorite dive zone', () {
    final e = PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'Bot', isBot: true),
        PenkPlayer(name: 'Human', isBot: false),
      ],
      botDifficulty: BotDifficulty.hard,
    );
    addTearDown(e.dispose);
    // Human keeper dove to zone 0 repeatedly; hard striker picks the
    // farthest corner: zone 5.
    e.diveHistory[1].addAll([0, 0, 0]);
    expect(e.debugBotShotZone(), 5);
  });

  test('practice mode never ends and tallies stats', () async {
    final e = PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'Human', isBot: false),
        PenkPlayer(name: 'Human2', isBot: false),
      ],
      botDifficulty: BotDifficulty.medium,
      practice: true,
    );
    addTearDown(e.dispose);
    for (int i = 0; i < 6; i++) {
      await playKick(e, 1, 5, KickResult.goal);
    }
    expect(e.over, isFalse);
    expect(e.winner, isNull);
    expect(e.practiceShots, 6);
    expect(e.practiceGoals, 6);
    expect(e.practiceStreak, 6);
    expect(e.practiceBest, 6);
    expect(e.strikerIdx, 0); // human always shoots in practice
    // A miss resets the streak but keeps the best.
    await playKick(e, 1, 5, KickResult.miss);
    expect(e.practiceStreak, 0);
    expect(e.practiceBest, 6);
    expect(e.over, isFalse);
  });

  test('practice with AI keeper resolves via the bot dive timer', () async {
    final e = PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'Human', isBot: false),
        PenkPlayer(name: 'AI', isBot: true),
      ],
      botDifficulty: BotDifficulty.easy,
      practice: true,
    );
    addTearDown(e.dispose);
    e.chooseShot(1);
    e.forcedResult = KickResult.goal;
    // The bot keeper dives on its own engine timer (~650ms); wait out
    // the dive + flight + settle.
    await Future.delayed(const Duration(milliseconds: 3400));
    expect(e.practiceShots, 1);
    expect(e.practiceGoals, 1);
    expect(e.phase, Phase.strikerAim);
    expect(e.over, isFalse);
  });

  test('strong wind can push an on-target shot wide', () async {
    final e = twoHumans();
    addTearDown(e.dispose);
    e.debugSetWind(0.6, 0.0); // hard gust to the right
    e.chooseShot(1); // central zone…
    e.chooseDive(5); // …keeper dives elsewhere: would be a goal in still air
    await Future.delayed(const Duration(milliseconds: 1100));
    await Future.delayed(const Duration(milliseconds: 1700));
    expect(e.marks[0], [KickResult.miss]);
  });

  test('restart resets practice stats too', () async {
    final e = PenaltyKickEngine(
      players: [
        PenkPlayer(name: 'Human', isBot: false),
        PenkPlayer(name: 'Human2', isBot: false),
      ],
      practice: true,
    );
    addTearDown(e.dispose);
    await playKick(e, 1, 5, KickResult.goal);
    e.restart();
    expect(e.practiceShots, 0);
    expect(e.practiceGoals, 0);
    expect(e.practiceBest, 0);
    expect(e.phase, Phase.strikerAim);
  });
}
