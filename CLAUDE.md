# CLAUDE.md

## Aseprite MCP Pro

When using the Aseprite MCP Pro tools (`mcp__aseprite-mcp-pro__*`), follow the pixel art
skill guide below (canvas proportions, palette strategy, animation timing, and related
techniques).

@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md

## Web-Test

Export geht nach `../../web-release/index.html` (Legacy-Pfad, abweichend von
der neueren `../web-release-<name>/` Konvention bei tetris/galaga — bewusst
so belassen, das ist der bestehende itch.io-Upload-Ordner des Nutzers).
`.claude/launch.json` startet `python3 -m http.server 8099 --directory
../../web-release` — per `preview_start` (Konfigname `pacman-web`) im
Claude-Browser-Panel öffnen, oder der Nutzer direkt in einem echten Browser
unter `http://localhost:8099/`. Das In-App-Panel hat kein WebGL2 → für
eigene Checks `chrome-devtools`-MCP (`-s local` registriert,
`mcp__chrome-devtools__*`) als Fallback.
