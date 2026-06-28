# roblox-hvh — CS:GO-style HVH (rage) cheat menu for a Roblox place

A self-contained, **randomly-generated** CS:GO "rage / HVH" style cheat menu that
runs **inside** a Roblox place (no exploit / injector needed). It is built with
**Rojo** and merged into the user's place file.

> For use only inside your own single-player Studio place against the bundled NPCs.

## What it does

- Bound to **`Delete`**. The first time you open it, a small smooth loading bar
  drops in from the top, then the menu slides out.
- Tabbed CS:GO-style menu: **RAGE / ANTI-AIM / VISUALS / MISC**, draggable window,
  watermark, FOV circle.
- **Everything is rolled at runtime on each launch:**
  - cheat **name** (e.g. `Neverlose.cc`, `Skeetware v4`, `Onyxtap HVH`),
  - menu **theme** (colours / accent / corner radius / font / scanline / glow),
  - cheat **quality tier** (`SKID → FREE → MID → PAID → INTERNAL`) which drives the
    real **power**: aimbot hit-chance (some shots whiff!), smoothing, max FOV,
    headshot rate, damage scale, resolver on/off, and even **which features are
    available vs. shipped "broken"** — so two builds genuinely differ in strength.

### Working features (actually affect the game)

These abuse the **client-trusted gun remotes** already inside the `SSG-08` tool
(`TakeDamage` / `CastRay`), which is exactly how a real rage bot behaves.

- **RAGE** — Aimbot (camera lock), Silent Aim, Auto-Shoot rage bot, hitbox
  selector (Head/Torso/Random), FOV slider.
- **ANTI-AIM** — Spinbot, Jitter, Fake-lag.
- **VISUALS** — Box ESP, health bars, name + distance, tracers, chams
  (`Highlight`), FOV circle.
- **MISC** — WalkSpeed, JumpPower, Infinite Jump, Fly, Fullbright,
  Big-NPC-hitbox (genuinely enlarges the NPC head part).

## Layout

```
roblox-hvh/
├── src/cheat.client.luau   # the whole cheat (single LocalScript)
├── cheat.project.json      # Rojo project (builds the LocalScript model)
├── merge.py                # injects the built model into the place's StarterPlayerScripts
├── build.sh                # rojo build + merge -> final place
├── place/Place122222.rbxlx # the user's source place
└── build/                  # output (gitignored)
```

## Build

Requires [Rojo](https://rojo.space) (7.6.0, pinned in `aftman.toml`) and Python 3.

```bash
./build.sh place/Place122222.rbxlx build/Place122222_HVH.rbxlx
```

This:
1. `rojo build cheat.project.json` → `build/HvhCheat.rbxmx` (the cheat LocalScript),
2. `merge.py` injects it into `StarterPlayer ▸ StarterPlayerScripts` of the place,
3. writes the playable `build/Place122222_HVH.rbxlx`.

Open the output in Roblox Studio and press **Play** — equip the `SSG-08`, press
**`Delete`**, and the cheat loads.

## Editing live in Studio (optional)

```bash
rojo serve cheat.project.json
```
Then connect with the Rojo Studio plugin to hot-sync `src/cheat.client.luau`.
