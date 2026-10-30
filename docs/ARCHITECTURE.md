# Architecture

This document covers how the game is put together: the global systems, how a page (level) works, the node layout of every scene, and how to add new content.

## Design rules that shape the code

The Story Bible's book rules map directly onto systems:

| Book rule | Where it lives |
| --- | --- |
| Page angle sets the view | `Page.view_mode` (`PageView.Mode.SIDE` / `TOP`), read by `Patch` and enemies |
| Tabs, flaps and wheels are real | `PullTab` (an `Interactable`) moving any `Node2D`, usually an `AnimatableBody2D` |
| The Margin is real | A page whose `view_mode` is `TOP`, reached through a `PageDoor` |
| The Narrator writes the rules | `DialogueUI.narrate()` captions; Lost Letters tracked in `GameState.letters` |
| Mending heals | `HealthComponent` (paper condition), `Bookmark` checkpoints, tape pickups |

## Global systems (autoloads)

The autoloads load in this order (Project > Project Settings > Globals > Autoload):

| Name | Type | Responsibility |
| --- | --- | --- |
| `EventBus` | script | Global signals (`player_health_changed`, `checkpoint_reached`, `dialogue_started`, and others). Systems emit and listen here instead of holding references to each other. |
| `Settings` | script | Volume and fullscreen, saved to `user://settings.cfg`. |
| `GameState` | script | The current playthrough: health, Scraps, letters, abilities, collected pickups, story flags, side quests, checkpoint. Also reads and writes the save slots. A new game starts at `FIRST_PAGE` (the Prologue). |
| `InputGlyphs` | script | Detects whether the player is on a controller or keyboard, for prompt labels. |
| `AudioManager` | script | Crossfading music plus a pooled sound-effect player (`play_sfx(&"jump")`). Uses the `Music` and `SFX` buses. |
| `SceneManager` | script (CanvasLayer) | Page-turn transitions, spawn placement, respawning, returning to the title screen. |
| `BookFrame` | script (CanvasLayer 5) | Draws every page as an open book lying on a desk: a shader warps everything below layer 5 onto the pages in perspective, with a scalloped border, gutter, cover and shadow. Scenes with `in_book = false` (the Margin, cutscenes) fill the screen instead. The pause menu's Book view button turns it off. Keep clickable UI on layer 6 or above so it isn't warped. |
| `HUD` | scene | Health tokens, Scraps, Lost Letter count, and the boss health bar. |
| `DialogueUI` | scene | Conversations (typewriter + voice blips) and narrator captions. |
| `PauseMenu` | scene | Pause, quest log, volume, fullscreen, save and quit. Runs while the tree is paused. |

### Save data

Saves are JSON at `user://save_slot_N.json`. Because `use_custom_user_dir` is on, that's `%APPDATA%\PatchPopUpKingdom\` on Windows and `~/Library/Application Support/PatchPopUpKingdom/` on macOS. Each save is written to a `.tmp` file and then renamed, so a crash can't corrupt it. Bump `GameState.SAVE_VERSION` when the format changes and migrate old saves in `load_game()`.

## How a page works

Every level scene's root has `scripts/world/page.gd` (`class_name Page`). On `_ready` it:

1. Sets `Patch.view_mode` from its own `view_mode`.
2. Places Patch at the spawn point `SceneManager` asked for (a named `Marker2D` in the `spawn_points` group, or an exact checkpoint position). Without one, it uses the marker named `Start`.
3. Sets the `Camera2D` limits from `bounds`, and in side view sets the fall-off limit just below them.
4. Starts the page's music, shows the HUD, and shows `opening_caption` the first time the page is visited.

Moving between pages always goes through `SceneManager.change_page(path, spawn_name)`.

## Node layouts

### Side-view page: `scenes/levels/ch1_thistledown/thistledown_page_01.tscn`

```
ThistledownPage01 (Node2D, page.gd)        view_mode = SIDE, bounds = 5120 x 1088
├── Background (Parallax2D)                scroll_scale (0.25, 0.1), repeats every 1920 px
│   └── Hills (Sprite2D)
├── Ground (TileMapLayer)                  paper_tiles.tres; collision on physics layer "world"
├── PageEdges (StaticBody2D)               WorldBoundaryShape2D at both sides
├── Start, FromMargin (Marker2D)           group "spawn_points"
├── Actors (Node2D)
│   ├── ShepherdFluff (npc_shepherd_fluff.tscn)
│   ├── Dot (npc_dot.tscn)
│   └── Soggy1..3 (soggy.tscn)
├── Props (Node2D)
│   ├── Bookmark1 (bookmark.tscn)
│   ├── TabBridge (moving_platform.tscn)
│   ├── BridgeTab (pull_tab.tscn)          target -> TabBridge, move_offset (0, -192)
│   └── MarginDoor (page_door.tscn)        target_page -> kitchen_table.tscn, spawn "FromPage"
├── Pickups (Node2D)                       scraps, Lost Letter "F", tape, Fold Dash page
└── Patch (patch.tscn)                     carries the Camera2D
```

### Top-down page: `scenes/levels/margin/kitchen_table.tscn`

```
KitchenTable (Node2D, page.gd)             view_mode = TOP, bounds = 2560 x 1536
├── Table (TileMapLayer)                   floor tiles, no collision
├── Obstacles (TileMapLayer)               book-stack walls (collide), ink-puddle art (no collision)
├── Start, FromPage (Marker2D)             group "spawn_points"
├── Props (Node2D)
│   ├── BackIntoTheBook (page_door.tscn)
│   ├── Bookmark1 (bookmark.tscn)
│   ├── InkPuddle (ink_puddle_hazard.tscn) a Hitbox that hurts on touch
│   └── GiantTapeRoll (StaticBody2D)
├── ArrivalTalk (Area2D, dialogue_trigger.gd)
├── Actors (Node2D)                        Soggies chase Patch in top view
├── Pickups (Node2D)
├── Patch (patch.tscn)
└── Diorama (Node, desk_diorama.gd)        draws the page as a lit 3D desk
```

The Margin is shown in 3D by `DeskDiorama` (`scripts/world/desk_diorama.gd`). It builds a 3D world in a SubViewport behind everything (wood desk, book-stack walls and ink puddles from the TileMapLayers, a mug, pencils and blocks), then hides the 2D page so only the 3D one shows. The 2D nodes keep running all the gameplay: every few frames the diorama mirrors each visible Sprite2D as a paper-cutout Sprite3D (with a real shadow) and each Label as a Label3D, at 128 px per metre. To add 3D decoration, extend `_build_decor()`; gameplay changes still go in the 2D scene. This needs the Forward+ renderer.

On a flat page, Patch uses `MOTION_MODE_FLOATING` and no gravity, so the same tileset can be both a side-view floor and a top-down wall.

### Patch: `scenes/player/patch.tscn`

```
Patch (CharacterBody2D, patch.gd)          layer: player   mask: world
├── Visual (Node2D)                        flipped, squashed and tilted for paper-puppet animation
│   └── Sprite2D (patch.png, scale 0.75)
├── CollisionShape2D (Capsule r28 h84)
├── Hurtbox (Area2D, hurtbox.gd)           mask: enemy_attacks
├── AttackHitbox (Area2D, hitbox.gd)       layer: player_attacks; active only during a swipe
├── InteractArea (Area2D)                  mask: interactables
├── HealthComponent (Node)                 6 HP = three tokens; 1.0 s invulnerability
└── Camera2D                               smoothing on; limits set by the Page
```

Patch is a small state machine (`NORMAL`, `ATTACK`, `DASH`, `HURT`, `DEAD`). Abilities are gated by `GameState.has_ability()`: `crease_swipe` is known from the start, and `fold_dash` is unlocked by the ability page on Thistledown page 1.

### Soggy (basic enemy): `scenes/enemies/soggy.tscn`

```
Soggy (CharacterBody2D, soggy.gd)          layer: enemies   mask: world
├── Sprite2D
├── CollisionShape2D (Circle r34)
├── Hurtbox (Area2D)                       mask: player_attacks
├── ContactHitbox (Area2D, hitbox.gd)      layer: enemy_attacks
├── HealthComponent (Node)                 2 HP
└── LedgeCheck (RayCast2D)                 turns around at ledges (side view)
```

### Interactables, pickups and UI

- `Interactable` (an Area2D on layer `interactables`, mask `player`) is the base class for `NPC`, `PullTab` and `PageDoor`. Each one shows a "[E] Talk"-style prompt when Patch is near.
- `Collectible` (an Area2D, mask `player`) handles `SCRAP`, `LOST_LETTER`, `TAPE` and `ABILITY`. One-time pickups are remembered in the save by scene path and node path.
- `Bookmark` is a checkpoint: it sets the respawn point, heals Patch fully, and autosaves.
- UI scenes use `resources/ui_theme.tres` (Patrick Hand font, paper-styled buttons and panels). Every menu takes controller focus.

### Story flow (Prologue, Chapters 1 to 3)

```
prologue/prologue_intro      CutscenePage: Nell and Dad at bedtime
prologue/prologue_flood      Climb away from the RisingWater flood, out the OffThePage door
ch1_thistledown/page_01      Meet Fluff (lost_flock quest) and Dot (joins as companion)
ch1_thistledown/page_02      Windmill Hills: Windmill wheel, 3 LostSheep, doors to the race and arena
ch1_thistledown/ribbon_regatta   BoatRace minigame (ribbon_regatta quest), returns to page 2
ch1_thistledown/millwheel_arena  BossMillwheel fight, exit door to the interlude
interludes/interlude_01      CutscenePage at Gran's table, sets chapter1_complete, turns to Chapter 2
ch2_lanternfold/lanternfold_town   Top-down town: Lamplighter Sisters (festival_lanterns), Corrugate, Crumple (lost_cat)
margin/tape_heist            Top-down 3D desk at night: the tape strip unlocks tape_tail
ch2_lanternfold/shadow_theater     ShadowTheater rhythm minigame (shadow_show quest), returns to town
ch2_lanternfold/under_the_flap     Side view ink sea: zip rings, the yank-open FlapGate, drip spawners
ch2_lanternfold/kraken_arena       BossKraken fight, Drizzle reveal, exit door to the interlude
interludes/interlude_02      CutscenePage: Nell tells Dad to stop, sets chapter2_complete, turns to Chapter 3
ch3_spine/frostfold_slopes   Side view: pop_up_slam page, fold marks, ice walls, the cliff (LayPageFlat door)
ch3_spine/frostfold_flat     The same page top-down: Bindwell (restring_spine), slam the ice gap, StandUpBeyond door
margin/paperclip_heist       3D desk, very late: the paperclip (has_paperclip) and the plug ring (plug_moved)
ch3_spine/the_spine          Tall side-view climb: pitons, thread bridges, spools, the low point (patch_told_truth)
ch3_spine/sogg_arena         BossSogg phases 1-2; the Sogg drags Patch away into the interlude
interludes/interlude_03      CutscenePage: Dad asleep, Nell and Gran and the torn spine, sets chapter3_complete
```

### Chapter 1 systems

- **Quests** live in `data/quests.json` (`title`, `goal`, `reward_scraps`). `GameState.start_quest`, `advance_quest` and `complete_quest` track them, and they're saved. An `NPC` with `quest_id` set picks its dialogue from the quest's state: give, progress, turn-in, then repeat.
- **Companions:** an `NPC` with `joins_as_companion` turns into `dot_companion.tscn` after talking, and sets `met_dot`. Every `Page` respawns Dot while that flag is set.
- **CutscenePage** (a `Control`) shows an illustration and a title caption, plays one conversation, then sets a flag, optionally saves, and turns to `next_page` (or the title screen).
- **RisingWater** is a `Hitbox` that rises at `rise_speed` until `stop_y`, and pauses during dialogue.
- **NarratorTrigger** shows a one-time caption; `{jump}`, `{attack}`, `{dash}` and `{interact}` become the right button names.
- **Windmill** spins a ring of `AnimatableBody2D` gondolas Patch can ride. A `PullTab` (now with an optional target) starts it.
- **BossMillwheel:** pull the three mooring tabs to jam the sails, then hit the core. Every 3 hits it recovers, spins faster, and calls 2 Soggies. `EventBus.boss_started`, `boss_health_changed` and `boss_defeated` drive the HUD boss bar.

### Chapter 2 systems

- **Tape Tail** (`tape_tail` ability, `grapple` action) lives in `Patch`: `try_grapple()` picks the best `GrapplePoint` in `grapple_range` (ahead of Patch, with a clear line in side view) and enters the `GRAPPLE` state. The tape shoots out, then a **ZIP** ring reels Patch in (world collisions off until he lands at `land_offset`, then a hop and carried momentum in side view) and a **YANK** ring calls `yank()`, which slides its `target` and emits `yanked`. The ring Patch would hit pulses.
- **Flag-gated doors:** `PageDoor.requires_flag` hides a door until a story flag is set (the Margin door needs `met_corrugate`, the harbor flap needs `corrugate_joined`).
- **Companions:** `Page.COMPANIONS` maps a flag to a follower scene; each `DotCompanion` has `companion_flag`, `follow_offset` and `bob`, so Dot floats and Corrugate waddles.
- **NPCCorrugate** runs his story in steps (needs tape, then the cat, then joins). `LostSheep` doubles as Crumple the cat via its `find_prompt`, captions and `leave_offset`.
- **FestivalLantern** is an `Interactable` that advances `festival_lanterns` and stays lit across saves.
- **ShadowTheater** is a rhythm game: a seeded chart of arrows on the beat, a hit window, and a win ratio. `autoplay` is for the smoke test.
- **DripSpawner** drops `InkDrip`s along a width while Patch is near.
- **BossKraken:** tentacles slam where Patch stands after a shadow warning. Yank both blotter rings to drop the blotters; it slumps with its eye in reach for `stun_time`. Every 3 hits it recovers, resets the rings, and calls 2 Soggies. When it dries out it plays `kraken_drizzle`, then opens the exit.
- **Top-down town:** the page root and its containers use `y_sort_enabled` so Patch walks behind houses; tile layers sit on `z_index` -1.
- **Tiles:** the atlas has a third and fourth row for Chapter 2: cobbles and boardwalk (floor), harbor water and hedges (solid on flat pages), and seabed top and fill (side view ground).

### Chapter 3 systems

- **Pop-Up Slam** (`pop_up_slam` ability, `slam` action, or attack while holding down in mid-air) lives in `Patch`'s `SLAM` state: a hop, a plunge (immune to hits), then an impact that spawns a short-lived shockwave `Hitbox` and calls `on_slam(position, view_mode)` on everything in the `slam_listeners` group.
- **FoldMark:** a printed fold line with a pop-up peak (`Peak`, an `AnimatableBody2D`) folded flat underneath. A slam within `trigger_radius` springs it up by `rise_height`, carrying Patch; the sprite is region-clipped so only the part above ground shows, and the peak is only solid while it's up. `stay_up_time` folds it away again (the boss arena uses this). Emits `popped`.
- **SlamBreakable:** ice walls that only a slam can break, on standing or flat pages, and that stay broken across saves.
- **View flipping:** the Slopes and the Flat page are the same page in two views. `PageDoor`s with "Lay the page flat" / "Stand the page up" prompts move between them at matching spawn points, so the cliff that blocks the side view is just a line to walk round from above.
- **Key items:** `Collectible.Kind.KEY_ITEM` sets a story `flag` (the paperclip sets `has_paperclip`). A YANK `GrapplePoint` can set `sets_flag` and show `yank_caption` (the hairdryer plug sets `plug_moved` for the finale), and stays yanked after loading.
- **Pitons** are `GrapplePoint`s with paperclip art.
- **BossSogg:** drifts high and rains drips, then warns with a wet shadow and dives where Patch stands, soaking there for `soak_time`. A `FoldMark` popping within `catch_range` of it pins it, exposing Drizzle in its chest (the `Heart` hurtbox). 3 hits or `stun_time` and it tears free. At half health it enters phase 2 (bigger, faster, more rain, Soggies). At zero it plays `sogg_drags_patch`, swallows Patch, saves, and turns to `next_page` (the third interlude).
- **Tiles:** row 4 holds snow top and frozen-rock fill (side view ground); row 5 holds thread bridges (one-way), ice (solid), snowfield (flat floor) and snowdrifts (solid on flat pages).

- **BoatRace** generates its course from `course_seed`, so it's the same every try. Win with 2 bumps or fewer.

## Collision layers

| # | Name | Used by |
| --- | --- | --- |
| 1 | world | Tiles, platforms, page edges, solid props |
| 2 | player | Patch's body |
| 3 | enemies | Enemy bodies |
| 4 | player_attacks | Patch's AttackHitbox |
| 5 | enemy_attacks | Enemy contact hitboxes, hazards |
| 6 | interactables | NPCs, pull-tabs, doors |

## Tileset (`resources/paper_tiles.tres`, 64 px tiles)

| Atlas | Tile | Collision |
| --- | --- | --- |
| (0,0) | Grass top | Solid |
| (1,0) | Dirt fill | Solid |
| (2,0) | Cardboard plank | One-way (jump up through) |
| (3,0) | Soggy ground | Solid |
| (0,1) | Table wood (Margin floor) | None |
| (1,1) | Page floor (top-down) | None |
| (2,1) | Book stack (top-down wall) | Solid |
| (3,1) | Ink puddle (art) | None (place an `ink_puddle_hazard.tscn` for damage) |

## Adding content

**A new page**
1. Duplicate a demo page, or create a `Node2D` with `page.gd` and set `view_mode`, `bounds`, `opening_caption` and `music`.
2. Add a `TileMapLayer` using `paper_tiles.tres` and paint the level.
3. Add `Marker2D` spawn points to the `spawn_points` group, including one named `Start`.
4. Instance `scenes/player/patch.tscn`.
5. Link it to other pages with `page_door.tscn` (set `target_page` and `target_spawn`).

**New dialogue**
1. Add an entry to a file in `data/dialogue/`, as a list of `{"speaker": "...", "text": "..."}` lines.
2. If it's a new file, add it to `DIALOGUE_FILES` in `scripts/ui/dialogue_ui.gd`.
3. Add new speakers to `data/speakers.json`, with `name`, `color`, and voice `pitch`.

**A new ability**
1. Give it an id, e.g. `&"tape_tail"`.
2. Gate its input in `patch.gd` with `GameState.has_ability(&"tape_tail")`.
3. Unlock it with an `ability_page.tscn` pickup or by calling `GameState.unlock_ability()`.

**A new side quest**
1. Add it to `data/quests.json`.
2. On the quest giver's `NPC`, set `quest_id`, `quest_progress_dialogue` and `quest_turn_in_dialogue`.
3. Call `GameState.advance_quest(id)` wherever progress happens (see `lost_sheep.gd`).

**A new enemy**
Copy `soggy.tscn`. Keep the `Hurtbox`, `HealthComponent` and `ContactHitbox` structure so combat works without changes.
