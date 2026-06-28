# CS Arena

A Counter-Strike (CS2 / CS:GO) inspired **5v5 deathmatch arena** built in **Godot 4.3**.

You spawn straight into a round as a Counter-Terrorist alongside 4 CT bots, against
5 Terrorist bots. Two weapons — a **Scout (sniper)** and a **Desert Eagle** —
switchable on the **mouse wheel**, just like in CS.

> This is a clean, mod-friendly base. Cheats / a "HvH practice" sandbox can be
> layered on top later (the bots already do anti-aim-style strafing).

## Controls

| Action | Key |
| --- | --- |
| Move | `WASD` |
| Look | Mouse |
| Fire | Left mouse |
| Scope (Scout only) | Hold Right mouse |
| Switch weapon | Mouse wheel / `1` / `2` |
| Reload | `R` |
| Jump | `Space` |
| Walk (quiet) | `Shift` |
| Crouch | `Ctrl` / `C` |
| Free the mouse | `Esc` |
| Restart round | `F5` |

## Weapons

- **Scout (SSG 08)** — high damage, slow fire, right-click to scope. Stand still for pinpoint accuracy.
- **Desert Eagle** — hard-hitting semi-auto pistol.

Headshots deal multiplied damage. When a team is wiped, the other team scores and
the round resets after a few seconds.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) (standard, GDScript build).
2. Open the project (`project.godot`) in Godot.
3. Press **F5** / the Play button.

The project uses the **Compatibility (OpenGL)** renderer for broad hardware
support. You can switch it to **Forward+** in *Project Settings → Rendering →
Renderer* for nicer lighting if your GPU supports Vulkan.

## Project layout

```
scripts/
  boot.gd          # registers input actions in code
  teams.gd         # CT / T enum, colors, groups
  weapon_data.gd   # weapon stat resource
  arsenal.gd       # Scout + Deagle definitions
  fighter.gd       # shared base: health, hitscan, weapons, model
  player.gd        # first-person controller
  bot.gd           # combat AI
  map_builder.gd   # builds the arena + spawns
  hud.gd           # crosshair, scope, health/ammo/score
  crosshair.gd / scope.gd
  game_manager.gd  # spawns the 5v5 match and runs round logic
scenes/main.tscn   # entry scene (just hosts game_manager)
assets/            # CC0 art
```

## Assets / Credits

All art is **CC0** (public domain) by **[Kenney](https://kenney.nl)**:
Blaster Kit, Blocky Characters, Mini Arena, Prototype Textures.

No Valve / Counter-Strike assets are used — this is an original, legally clean
re-creation of the *style* of gameplay.
