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

## Playtest-Runde (2026-09-14): bildbasierte Hilfe, Seiten-Punkte-Fix,
Exit-Button im Start-Menü, Restart = Play, `build.sh` nachgerüstet.

- **`build.sh` gab es für pacman bisher gar nicht** (Lücke gegenüber tetris/
  galaga, die beide eins haben — vermutlich beim Anlegen des Projekts vor der
  entsprechenden Konvention übersehen). Nachgerüstet nach dem tetris-Vorbild
  (Linux/Web/Android, `assets/help_src/render.sh` vorab, `adb install -r` bei
  angeschlossenem Gerät).
- **Hilfe komplett neu, bildbasiert** (Nutzerwunsch, Vorbild tetris/galaga) —
  die 6 `HELP_PAGES` (Goal, 2× Maus, Tastatur/Gamepad, Touch, Settings) waren
  bislang reiner Fließtext (`{"title", "body"}`). Jetzt wie bei tetris/galaga:
  `assets/help_src/*.svg` → `render.sh` (Inkscape) → `assets/graphics/help/
  <name>.png`, `HELP_PAGES` verweist nur noch auf `"file"` statt `"body"`.
  Jede Illustration bettet echte Spiel-Sprites ein (`<image
  xlink:href="file:///…">` auf frisch aus den Spritesheets extrahierte
  Einzelframes unter `assets/graphics/help_sprites/` — Pac-Man nach rechts/
  oben, alle vier Geister in ihrer jeweiligen Farbe, die winzigen Pillen
  freigestellt aus ihrem großteils transparenten 32×32-Canvas). `settings_menu
  .tscn`s `help_panel` bekommt dafür ein `image`-`TextureRect` (460px breites
  Panel wie bei tetris/galaga) statt des alten `body`-Labels; `page_title`
  bleibt als echtes Label darüber (bleibt scharf, unabhängig von der
  Bild-Auflösung). `assets/help_src/` und `assets/graphics/help_sprites/`
  haben je ein `.gdignore` (wie bei galaga) — reine Zulieferer-Assets fürs
  externe Rendering, nicht fürs Godot-Importsystem gedacht.
- **Seiten-Punkte in der Hilfe waren hohe Balken, keine Quadrate**
  (Nutzer-Report) — `_refresh_help_dots()`s `ColorRect`s hatten kein
  `size_flags_vertical` gesetzt und füllten dadurch in der `nav`-Zeile
  standardmäßig deren volle Höhe (44px, von den `prev`/`next`-Buttons
  vorgegeben) statt bei ihrer eigenen `custom_minimum_size` (7×7) zu bleiben.
  Fix: `size_flags_vertical = Control.SIZE_SHRINK_CENTER`, wie es
  galagas Pendant schon immer richtig gemacht hat.
- **Start-Menü hatte gar keinen Exit-Button** (Nutzer-Report, entspricht der
  globalen Design-Vorgabe #7 — jedes Spiel braucht Exit als letzten Button
  im Start-Screen, ausgeblendet nur unter `OS.has_feature("web")`) — `root`
  hatte in `settings_menu.tscn` bislang nur Play/How to Play/Settings. Neuer
  `exit_btn`, Klick ruft `get_tree().quit()`, wird auf Web-Builds versteckt
  (gleiches Muster wie die Pause-Overlay schon für ihren eigenen Exit-Button
  nutzt, siehe `overlay_menu.gd::_open()`).
- **„Restart" aus der Pause sollte sich wie „Play" verhalten**, nicht wie
  eine Rückkehr zum Start-Bildschirm (Nutzer-Report) — `overlay_menu.gd`s
  `"restart"`-Aktion rief bisher nur `get_tree().reload_current_scene()` auf;
  `game.gd::_ready()` öffnet aber nach JEDEM Szenen-Reload bedingungslos
  wieder den Start-Screen (`_settings.call_deferred("open_start")`), Restart
  landete also wieder im Menü statt direkt im Spiel. Fix: neue
  `Game._auto_start_next_run`-`static var` (übersteht den Reload, da nur
  Node-Instanzen neu erzeugt werden, nicht die Skriptklasse) — `"restart"`
  setzt sie vor dem Reload, `_ready()` ruft bei gesetztem Flag
  `_settings.request_play()` (neue, dünne Hülle um `_on_play()`) statt
  `open_start()` auf. `_settings._load()` läuft ohnehin schon vorher in
  dessen eigener `_ready()`, die Werte kommen also exakt wie bei einem
  echten Play-Klick aus `user://settings.cfg`. Gilt automatisch auch für
  „Restart" auf dem Game-Over-/Win-Screen (dieselbe Aktion, derselbe Code-Pfad).
  Per Live-Test verifiziert: Restart aus der Pause → `_configuring=false`,
  `settings.visible=false`, `get_tree().paused=false`,
  `Game._auto_start_next_run` wieder `false` — kein Zwischenstopp am
  Start-Screen.
- Alle vier Punkte + der Build live per `godot-mcp-pro` verifiziert
  (Screenshot Start-Screen mit Exit-Button, Hilfe-Seite „GOAL" mit
  Illustration, Seiten-Punkte im Zoom als echte 7×7-Quadrate, Restart-Ablauf
  per Skript-Zustandsprüfung).
