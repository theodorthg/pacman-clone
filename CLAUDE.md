# CLAUDE.md

## Aseprite MCP Pro

When using the Aseprite MCP Pro tools (`mcp__aseprite-mcp-pro__*`), follow the pixel art
skill guide below (canvas proportions, palette strategy, animation timing, and related
techniques).

@/home/bernd/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/aseprite-mcp-pro-server/skills.md

## Web-Test

Export geht nach `../web-release-pacman/index.html` (Stand 2026-09-14 an
tetris/galaga angeglichen — vorher fälschlich `pacman.html` in einem falsch
benannten `../../web-release/`-Ordner, eine Altlast des Nutzers aus der Zeit
vor der einheitlichen `../web-release-<name>/index.html`-Konvention; der alte
Ordner ist jetzt ungenutzt und kann gefahrlos gelöscht werden). `html/`-Preset
angeglichen: `variant/extensions_support=false`,
`progressive_web_app/enabled=false`,
`progressive_web_app/ensure_cross_origin_isolation_headers=false` — läuft
dadurch ohne zusätzliches Redirect-Script/Service-Worker direkt vom
Godot-Framework geladen, auf jedem simplen Static-Hosting (itch.io
eingeschlossen).

`.claude/launch.json` startet `python3 -m http.server 8098 --directory
../web-release-pacman` — Port **8098**, nicht 8099 (das ist bei tetris und
galaga belegt; alle drei Projekte liefen sich sonst bei parallelen Sessions
gegenseitig in die Quere, siehe globale CLAUDE.md). Per `preview_start`
(Konfigname `pacman-web`) im Claude-Browser-Panel öffnen, oder der Nutzer
direkt in einem echten Browser unter `http://localhost:8098/`. Das
In-App-Panel hat kein WebGL2 → für eigene Checks `chrome-devtools`-MCP
(`-s local` registriert, `mcp__chrome-devtools__*`) als Fallback.
