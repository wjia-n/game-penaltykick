# Penalty Kick — RULES.md

_The authoritative source of truth for the game. If implementation conflicts
with this document, fix the implementation._

## 1. Objective

Outscore your rival in a penalty shootout. Players alternate as striker and
keeper across a series of kicks; the player with more goals when the shootout
ends wins.

## 2. Setup

- 2 players (seats 0 and 1). Seat names are renameable.
- Mode A: human vs AI keeper/striker (AI takes one seat, 3 difficulties).
- Mode B: 2 humans pass-and-play (both seats human, one phone).
- Mode C: practice — the human always shoots, the AI always keeps, endless
  kicks, no winner. Tracks shots, goals, current streak and best streak.
- Each player takes **5 kicks** as striker.
- Roles alternate every kick: kick N has striker = N % 2, keeper = (N+1) % 2.
- The goal mouth has 6 zones, numbered:

```
0 1 2
3 4 5
```

## 3. Turn order

1. Striker chooses a target zone (human taps; AI picks after a visible
   thinking beat).
2. Keeper chooses a dive zone (human taps; AI picks after a visible
   reading-the-run-up beat).
3. The kick resolves with a visible ball flight + keeper dive animation.
4. The result displays, then the next kick begins with roles swapped.

## 4. Legal moves

- Striker: pick any of the 6 goal zones — tap a zone, or drag toward a
  target (drag-to-shoot; releasing outside the goal cancels the shot).
- Keeper: pick any of the 6 goal zones.

## 5. Illegal moves

- Picking a zone when it is not your role's phase (input is ignored).
- Picking a zone after the match is over (input is ignored).
- The engine enforces this: human taps outside the active phase are rejected
  and play an "invalid" sound, never changing state.

## 6. Captures

Not applicable — no pieces are captured.

## 7. Special rules

- **Corner risk:** corner zones (0, 2, 3, 5) carry a 10% miss chance;
  central zones (1, 4) carry a 2% miss chance. Risky corners are harder
  for keepers to reach but can fly wide.
- **Save:** if the keeper dives to the exact zone the striker targeted
  (and the shot is not missed), the shot is saved.
- **Goal:** any on-target shot the keeper does not match is a goal.
- **Miss:** a missed shot goes wide of the post/bar — no goal, keeper
  irrelevant.
- **Wind:** Easy plays in still air. Medium has a light breeze, Hard a
  strong wind. Wind drifts the ball during flight and can push an
  on-target shot outside the frame (a miss). The wind direction and
  strength are shown to the striker before every kick. The kick outcome is
  decided when the kick is taken, so the flight animation always matches
  the settled result.

## 8. Scoring

- Each goal = 1 point for the striker of that kick.
- Saves and misses = 0 points.
- The scoreboard shows goals per player plus a per-kick mark:
  ✅ goal, 🧤 save, ❌ miss.

## 9. Winning conditions

- After 5 kicks each: the player with more goals wins.
- **Early decision:** if a player's lead exceeds the rival's remaining
  kicks, the shootout ends immediately.
- **Sudden death:** if tied after 5 kicks each, play continues one pair of
  kicks at a time; after each completed pair, if the scores differ, the
  leader wins.

## 10. Draw conditions

None — sudden death continues until someone leads after a completed pair.
A shootout cannot end in a draw.

## 11. AI strategy

### AI striker
- **Easy:** picks a random zone every kick.
- **Medium:** picks a corner 60% of the time, random otherwise.
- **Hard:** punishes the keeper's favorite dive zone — picks the corner
  farthest from it 80% of the time, with slight noise to stay human.

### AI keeper
- **Easy:** dives to a random zone every kick.
- **Medium:** studies the striker's shooting history — dives to the
  striker's favorite zone 50% of the time, random otherwise.
- **Hard:** commits to the striker's hot zone on a streak (same zone twice
  in a row), otherwise dives to the favorite zone 80% of the time.

## 12. Edge cases

- Human keeper vs AI striker: the AI's shot zone is hidden until the kick
  resolves; the human keeper picks a dive zone blind.
- Human striker vs AI keeper: the AI's dive zone is hidden until the kick
  resolves.
- Pausing mid-kick freezes the engine timer; resuming re-arms the current
  phase exactly where it left off.
- Restarting at any moment resets kicks, marks, history and scores, and
  begins a fresh shootout with the same seats.

## 13. Test cases

1. All 6 striker zones × all 6 keeper zones resolve without errors.
2. Corner shots miss roughly 10% over many kicks; central shots ~2%.
3. Keeper matching the shot zone (on target) always saves.
4. After 5 kicks each with unequal scores, the leader is declared winner.
5. Early decision: 3–0 after 3 kicks each with 2 kicks left ends the match.
6. Tie after 5 kicks each enters sudden death; a 1–0 split after a
   completed sudden-death pair ends it.
7. Hard AI keeper dives to the striker's repeated zone (streak reaction).
8. Hard AI striker avoids the keeper's favorite dive zone.
9. Pause during ball flight, then resume: the kick resolves correctly.
10. Restart mid-match resets all state; a new match plays to completion.
11. Practice mode: 20 kicks never ends the session; goals/streak tally up.
12. Strong wind can turn an on-target shot (keeper dived elsewhere) into
    a miss; still air never does.
