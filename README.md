# Practice Riichi Mahjong

A focused training tool for building faster, sharper riichi mahjong hands.

The single feature here: a **Tenpai Speedrun** mode that drops you into a solo loop of drawing and discarding until you reach tenpai, then times the run, counts the draws, and tracks your stats over time. It's built on top of [FluffyStuff/OpenRiichi](https://github.com/FluffyStuff/OpenRiichi) so the tile rendering, sound design, and rules engine are the same as a real client; only the surrounding mode is new.

---

## Why practice this?

Reaching tenpai is the bottleneck of every hand you play. Every turn before tenpai is a turn where you can't win and the table can. Trimming that runway is one of the highest-leverage skills in riichi:

- **Faster tenpai = more decisions per match.** You spend more rounds in scoring position instead of stuck shaping a shanten-3 mess.
- **Discard discipline.** Having a real-time discard pile staring back at you while you race the clock builds a habit of remembering what you've thrown away. That's the same instinct that keeps you out of furiten in real games.
- **Wait quality awareness.** The stats break down whether you tend to land on single-tile waits (fragile) versus multi-tile waits, and which tile types finish your hands most often, so you can spot habits you might want to fix.
- **Wind sensitivity.** Each attempt rolls a fresh round wind and seat wind; double-wind attempts are highlighted, so you build the reflex of valuing yakuhai winds in your shaping.

Repetition is the only way these reflexes become automatic. This mode is designed for short, infinite-restart practice sessions where you're getting tens of attempts in the time a normal hanchan would take.

---

## How a run works

1. You're dealt 13 random tiles, with a randomized round wind and seat wind shown at the top of the screen.
2. Click **Draw Tile** once to start the timer and pull your first tile.
3. From there it's automatic: every tile you click discards itself and the next tile is drawn instantly. Discard and draw sound effects play on every cycle.
4. Your discards stack into a 6-per-row pile in the top-left corner.
5. The instant your 13-tile hand is in tenpai (after a discard), the run ends and a stats screen shows up.

The drawn tile sits separated to the right of your sorted hand so you can see exactly what just came in without it shuffling your row. The hand stays visible on the results screen so you can see the shape you finished on.

---

## What the stats track

Every finished run records: time, draw count, wait-tile count, the wait tiles themselves, and whether you finished in self-furiten (a wait tile already in your discard pile).

The results screen surfaces:

| Section | Shows |
| --- | --- |
| This run | time, draws, number and types of wait tiles, furiten warning |
| Last 5 / 10 / 25 / 100 | rolling avg time and draws, plus best time and best draws over each window |
| All-time | avg, best, and worst time and draws across every attempt |
| Habits | avg wait-tile count, single-wait finish %, most common finishing wait tile, furiten finish % |

Scores persist to `tenpai_speedrun.scores` in your user config directory (`%APPDATA%\OpenRiichi\` on Windows, `~/.config/OpenRiichi/` on Linux/macOS), so progress carries across sessions.

---

## Building from source

OpenRiichi is written in [Vala](https://wiki.gnome.org/Projects/Vala) and built with Meson + Ninja.

### Windows (MSYS2 + MinGW-w64)

Inside an `MSYS2 MINGW64` shell:

```bash
pacman --noconfirm -Syu
pacman --noconfirm -S \
  git \
  mingw-w64-x86_64-vala \
  mingw-w64-x86_64-pkg-config \
  mingw-w64-x86_64-gcc \
  mingw-w64-x86_64-meson \
  mingw-w64-x86_64-libgee \
  mingw-w64-x86_64-gtk3 \
  mingw-w64-x86_64-glew \
  mingw-w64-x86_64-SDL2_image \
  mingw-w64-x86_64-SDL2_mixer \
  mingw-w64-x86_64-pango
```

### Linux (Debian / Ubuntu)

```bash
sudo apt install -y \
  git valac gcc meson \
  libgee-0.8-dev libgtk-3-dev libglew-dev libpango1.0-dev \
  libsdl2-image-dev libsdl2-mixer-dev libsdl2-dev
```

### macOS (MacPorts)

```bash
sudo port install \
  git vala pkgconfig meson libgee gtk3 \
  libsdl2 libsdl2_image libsdl2_mixer glew pango
```

### Compile and run

```bash
git clone https://github.com/itsRevela/Practice-Riichi-Mahjong.git
cd Practice-Riichi-Mahjong
meson setup build -Dbuildtype=release
ninja -C build
./build/OpenRiichi --search-directory ./bin
```

The `--search-directory` flag points the executable at the bundled `bin/Data/` so it can find textures, sounds, and models. On Windows, replace `./build/OpenRiichi` with `build\OpenRiichi.exe`.

Once the game loads: **Singleplayer → Tenpai Speedrun**.

---

## Credits

The entire mahjong client (renderer, audio, rules, scoring, networking, all assets) is the work of [FluffyStuff](https://github.com/FluffyStuff) and contributors on [OpenRiichi](https://github.com/FluffyStuff/OpenRiichi), with its [Engine](https://github.com/FluffyStuff/Engine) library. This fork just adds the Tenpai Speedrun mode on top.

## License

Inherited from upstream: [GPLv3](https://www.gnu.org/licenses/quick-guide-gplv3.en.html). See [LICENSE](LICENSE).
