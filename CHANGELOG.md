# OpenRiichi Changelog

All notable changes to this project will be documented in this file.

Versions 0.1.0 and later (three-part numbers) are Practice Riichi Mahjong fork releases. The four-part versions below them are upstream OpenRiichi releases.

## [Unreleased]

## [0.2.0] - 2026-09-27

### Added
- Point Calculation Practice singleplayer mode (Singleplayer menu, below Tenpai Speedrun) for learning to score hands. Each round deals a random winning hand with its full context: round and seat wind, dealer status, ron or tsumo, riichi, dora and ura dora indicators, and situational yaku (ippatsu, haitei/houtei, rinshan, chankan). Hands can be open (chii/pon), contain open, closed or added kans, and include red fives. The player types the payment the way it's announced at the table: one value for ron, "X all" for a dealer tsumo, or two values for a non-dealer tsumo. Feedback says whether the answer was right and always shows the full calculation (han per yaku, itemised fu, basic points, payments). A Hints toggle on the setup screen adds a Hint button that shows the calculation before answering. Rounds repeat until the player returns to the menu.
- Unit test executable for the rules engine and the practice mode, run with `meson test -C build`. It is not installed or packaged.

### Changed
- The release workflow runs the unit tests after building and stops before anything is signed or published if a test fails. Release notes now describe both training modes.

### Fixed
- Fu calculation now follows standard rules. Previously a shanpon (dual pon) wait earned 2 wait fu, and wait detection compared tile types across every meld, including called melds, so some waits were misread. This could raise a hand by 10 fu (e.g. 40 fu counted as 50). The scorer now tries every way the winning tile could have completed a concealed group and keeps the most valuable interpretation, as the rules allow. Kanchan, penchan and tanki are worth 2 fu; ryanmen and shanpon are worth 0.
- Closed kans no longer make a hand count as open when scoring. Hands with a closed kan now keep menzen tsumo, the 10 fu for a closed ron, and full closed-hand han for yaku such as honitsu and sanshoku. The game already let players riichi with a closed kan, but scored those hands as open.
- These fixes change the points awarded in the regular game for affected hands. The server only announces who won, and every client scores the hand itself. So in multiplayer with unmodified OpenRiichi clients, players can end up with different point totals after an affected hand. An unmodified server will also still refuse a tsumo whose only yaku is menzen tsumo with a closed kan. Single-player and games where everyone runs this fork are consistent. To roll back, revert the `Scoring`/`calculate_yaku` changes in `source/Game/Logic/TileRules.vala`.

## [0.1.0] - 2026-04-27

### Added
- Tenpai Speedrun singleplayer mode: solo draw-and-discard practice that times the player from the first draw until they reach tenpai. Records every attempt and shows post-run statistics (averages and bests over the last 5/10/25/100 and all-time attempts, plus average wait-tile count, single-wait finish percentage, and most common finishing wait tile). After tenpai the player can restart or return to the main menu. Scores persist to `tenpai_speedrun.scores` in the user config directory.

## [0.2.1.1] - 2020-05-04

### Fixed
- Rendering issue on AMD GPUs.

## [0.2.1.0] - 2020-04-24

### Added
- Changelog file.
- Table texture selection option in options menu.
- Feature to persist window state between runs.
- Meson build scripts.
- More verbose debug log
- Compile and runtime option for data search directory
- About menu
- Game start animation

### Changed
- Disabled background music by default.
- Moved Engine project into a subfolder as a git submodule.
- Statically build Engine into executable file.
- Move shaders from GLSL 120 to GLES 100 for better macOS support.
- Changed audio backend to use SDLMixer instead of SFML audio.

### Fixed
- Compilation and runtime for linux and macOS.
- Game scene lights over/under exposing tiles.

### Removed
- Makefile build scripts.

## [0.2.0.3] - 2020-04-11

### Fixed
- Decision time option being applied by remote server.

## 0.2.0.2 - 2020-04-11 [YANKED]

### Added
- Variable decision time option, between 2 and 120 seconds.

## [0.2.0.1] - 2020-04-11

### Changed
- Revision numbers no longer considered for version compatibility.

### Fixed
- Some broken debug code.

## 0.2.0.0 - 2020-04-10 [YANKED]

### Added
- An animation system for both 3D and 2D scenes.
- A new shader system for auto generating shaders.
- A wrapper framework for 3D scenes, which automates many 3D tasks.

### Changed
- Merged the development branch which contained many bug fixes and impromevents.
- Improved networking and serialization system.
- Split up Engine into its own proper library.
- Rewrite of game scenes and menus.

### Fixed
- Accumulation of many bugs and defects.

## [0.1.3.2] - 2018-03-31

### Fixed
- Yaku calculations with called tiles.

## [0.1.3.1] - 2017-06-11

### Fixed
- Bug which caused slow loading of the main game scene.

## [0.1.3.0] - 2016-12-05

### Added
- Initial release, branched from older project.

[unreleased]: https://github.com/itsRevela/Practice-Riichi-Mahjong/compare/v0.2.0...HEAD
[0.2.0]:      https://github.com/itsRevela/Practice-Riichi-Mahjong/releases/tag/v0.2.0
[0.1.0]:      https://github.com/itsRevela/Practice-Riichi-Mahjong/releases/tag/v0.1.0
[0.2.1.1]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.2.1.1
[0.2.1.0]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.2.1.0
[0.2.0.3]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.2.0.3
[0.2.0.1]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.2.0.1
[0.1.3.2]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.1.3.2
[0.1.3.1]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.1.3.1
[0.1.3.0]:    https://github.com/FluffyStuff/OpenRiichi/releases/tag/v0.1.3