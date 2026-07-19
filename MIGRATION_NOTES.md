# Wasteland Echoes — Godot Port: Phase 1

This is the **data + logic layer** ported from the Swift/SwiftUI iOS project,
rebuilt as a Godot 4 project. No UI/scenes exist yet on purpose — see
"What's next" below for why, and what to build first.

## What's in this package

```
wasteland_echoes_godot/
├── project.godot                  # Godot project config (portrait, mobile renderer)
├── autoload/
│   └── game_manager.gd            # Ported GameManager.swift + GameModels.swift
├── data/
│   └── prompts.json                # Ported prompts.json, with fixes (see below)
└── scenes/
    ├── bootstrap_test.tscn         # Minimal scene to smoke-test the port
    └── bootstrap_test.gd
```

## How to test it right now

1. Open Godot 4 (4.3+), "Import" this folder, select `project.godot`.
2. Press Play (▶). It'll run `bootstrap_test.tscn`.
3. Check the **Output** panel at the bottom — you should see prompt 1's text
   and choices printed, proving the JSON loads and the engine resolves
   correctly. Uncomment `_auto_play()` in `bootstrap_test.gd` to walk the
   *entire* story graph from the console and confirm every branch resolves
   to a real prompt (this is also how you'll catch future dead-end bugs
   like the prompt-30 one, before they ship).

There's no visual UI yet — this step is purely to prove the ported engine
is correct before spending time on visuals.

## Bugs fixed during the port (from the iOS audit)

| Bug | Fix |
|---|---|
| `requiredIntFlags` on `"hp"` checked a flag that was never set, so HP-gated choices never actually reflected real HP | `_resolve_int_value()` now special-cases `hp`/`sta`/`mor`/`elapsedTime` to read the live stat |
| Two choices ("Offer the battery in trade.", "Offer a rare item.") only worked because the Swift code matched their exact button text | Replaced with a generic `branchOnFlag` field in the JSON — works regardless of button wording, and any future prompt can reuse it |
| Day-3 timeout was a hardcoded `if promptId == 28` check in Swift, and left the player soft-locked (no available choices) if time ran out mid-check | Generalized into a `timeoutRedirect` field any prompt can carry, checked on entry — also fixes the soft-lock |
| `"AshParticle.sks"` referenced a file that didn't exist | Renamed all particle references to engine-agnostic names (`ash_gray`, `ash_orange`, `fire`) — you'll create these as real Godot particle scenes in Phase 3 |
| Story dead-ended at prompt 29 → 30, which didn't exist | Added prompt 30 as an explicit, clearly-marked placeholder (`"isPlaceholder": true`) so the game ends gracefully instead of erroring. **This is not real content** — Day 3's actual resolution and the arrival at Haven still need to be written |
| The "win" state (`prompt.id == 201`) was referenced in code but prompt 201 never existed — the game could never actually be won | Not fixed yet — needs the actual ending written first |
| Prompt 1 says you need "The Key," prompt 28 says "Key secured," but the Day 3 briefing said "encrypted USB stick" | Changed the briefing to say "the Key" for consistency. **Please double check this was the right call** — if the USB stick was meant to replace the Key as the objective, let me know and I'll flip it back and update the other two instead. |
| `promptslena.json` (a companion/loyalty side-mechanic) existed but was never loaded by the app | Not ported — it's a real feature idea worth keeping, but needs a decision on whether/how it merges into the main story before it's built for real. Flagging it rather than silently dropping it or silently reviving unfinished work. |

## New JSON fields (for writing future content)

**`branchOnFlag`** on a choice — send the player down one of two paths based
on a flag, without needing any engine code changes:
```json
"branchOnFlag": {
  "flag": "hasBattery",
  "value": true,
  "ifTrue":  { "nextPromptId": 6, "narrativeOutcome": "...", "setFlags": {} },
  "ifFalse": { "nextPromptId": 8, "narrativeOutcome": "..." }
}
```

**`timeoutRedirect`** on a prompt — silently redirect to a different prompt
if a stat/time threshold is crossed by the time the player arrives:
```json
"timeoutRedirect": { "flag": "elapsedTime", "min": 60, "redirectToPromptId": 2828281 }
```

## What's deliberately NOT in this package yet

- **Images/audio** — your existing PNGs/JPGs and MP3s/WAVs aren't copied
  over yet (132MB, and several should be compressed first — see the asset
  size note from the original audit). Recommended folder layout to match
  when you're ready:
  ```
  assets/
  ├── backgrounds/day_1/..., day_2/..., day_3/...
  ├── ui/ (main_menu_background, splash, etc.)
  └── audio/music/, audio/sfx/
  ```
- **Scenes/UI** — Main Menu, Game View, Inventory, Settings, etc. Godot UI
  is normally built visually in the editor (drag nodes, set anchors), not
  hand-written as text files — that's a deliberate choice on my part, not
  a shortcut, since hand-authoring `.tscn` layout files blind is exactly
  the kind of thing that looks fine and is subtly broken until you open it.
- **Particle scenes** (`ash_gray`, `ash_orange`, `fire`) — these become
  `GPUParticles2D` nodes with a `ParticleProcessMaterial`, a close
  equivalent to your `.sks` files, built in-editor.

## Suggested next steps, in order

1. **Main Menu scene** — `Control` root, `TextureRect` background, `VBoxContainer`
   of buttons wired to `GameManager.start_game()` / `continue_game()` /
   `go_to_settings()`. Closest 1:1 port of `MainMenuView.swift`.
2. **Game View scene** — the big one: background `TextureRect`, a translucent
   `PanelContainer` for prompt text, a `VBoxContainer` of choice buttons built
   from `GameManager.current_prompt["choices"]`, and a stats `HBoxContainer`
   listening to the `stats_changed` signal. Port of `GameView.swift`.
3. **Particle scenes** for `ash_gray` / `ash_orange` / `fire`.
4. **Audio** — an `AudioStreamPlayer` setup with bus ducking for background
   music vs. narration, matching `AudioManager.swift`.
5. **Inventory / Settings scenes** — lower risk, port last.
6. Once there's a playable vertical slice: **asset compression pass**, then
   finish Day 3's real ending + the Haven arrival (prompt 201).
7. **Export presets** for iOS and Android (Project → Export in the editor) —
   this is also where you'll set the bundle ID / package name, icons, and
   signing.

I can build any of these next — Main Menu is the natural next piece since
it's the simplest and lets you see something on screen.

---

## Phase 2: Main Menu (added)

`scenes/main_menu.tscn` + `scenes/main_menu.gd` — real background art and
audio, wired to `GameManager`. This is now the project's entry point
(`run/main_scene` in `project.godot`). `bootstrap_test.tscn` is still there
if you want to re-run the console smoke test later.

**Assets included** (pulled from your iOS repo's `Assets.xcassets`/`Music`,
compressed):
- `assets/ui/main_menu_background.jpg` — resized 2048x2048 → 1600x1600,
  re-encoded at quality 82. **1.2MB → 320KB** (73% smaller), no visible
  quality loss at phone-screen size. This is the pattern to repeat for the
  other ~35 background images later (Phase 4 in the roadmap above) — same
  approach, just batched.
- `assets/audio/music/background_music1.mp3` — re-encoded from 320kbps to
  128kbps (**6.3MB → 3.5MB**). Background/ambient loops don't need 320kbps;
  your ear can't tell the difference under game audio and SFX.
- `assets/audio/sfx/button_tap.wav` — copied as-is (already tiny, 8KB).

**What "New Game" / "Continue Game" / "Settings" actually do right now:**
they call the real `GameManager` methods, then try to load
`game_view.tscn` / `settings_view.tscn`. Neither exists yet, so instead of
crashing they print the resulting game state to the Output console — so
you can still verify the button logic is correct before those scenes
exist. Once Game View is built, delete the `ResourceLoader.exists(...)`
fallback branches in `main_menu.gd`.

**Known rough edges, called out honestly rather than hidden:**
- I hand-wrote this `.tscn` as text rather than building it visually in
  the editor (which is the normal Godot workflow). The logic and asset
  references are correct, but exact pixel layout/spacing may need small
  nudges once you see it — that's expected, not a bug. If anything looks
  off, click the node in the Scene panel and adjust in the Inspector; nothing
  here needs to be rebuilt from scratch.
- Buttons only have a "normal" style override — no custom hover/pressed
  states yet, so those will look like default Godot theme buttons on
  press. Cosmetic only.
- No custom serif font for the title (the iOS version used the system
  serif font, which isn't a portable file). Using the default UI font for
  now — swap in a real `.ttf` on the Title label's font override whenever
  you pick one.
- Background music now autoplays as soon as Main Menu loads. On iOS it
  started on the splash-to-menu transition instead — move the autoplay
  logic to the Splash Screen once that scene exists.
