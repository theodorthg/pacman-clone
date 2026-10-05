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
(global registriert, `mcp__chrome-devtools__*`) als Fallback.

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

## Technisches Architektur-Dossier (2026-09-16, automatisierter Lauf)

`docs/architecture-dossier/` — ein druckbares Claude-Artifact nach demselben
Muster wie Galagas Dossier (siehe die globale CLAUDE.md, Abschnitt
„Technische Dokumentation als Claude-Artifact"): `index.html` als
Artifact-Quelle, `build_standalone.py` für den Base64-Inline-PDF-Export,
`prepare_assets.py` für Diagramm-/Bild-Aufbereitung, `diagrams/*.dot` für
die Graphviz-Quellen. Inhalt speziell für Pacman (fünf Module): Steuerung
(vier gleichwertige Eingabewege — Tastatur/Gamepad, Touch-Swipe, Maus-Klick
mit `MazeGrid.find_path()`-BFS —, alle über dieselbe `_queued`-Warteschlange
in `player.gd`), Szenenaufbau + das ungewöhnliche Kollisionsmodell (**keine
Godot-Physik**: `player.gd`/`ghost.gd` sind `CharacterBody2D`, aber nirgends
im Projekt ein `move_and_slide()` oder ein gesetzter
`collision_layer`/`collision_mask` — jede „Kollision" ist ein
Dictionary-Lookup gegen `MazeGrid` oder ein Distanz-/Segment-Check in
`game.gd::_check_caught()`/`_swept_gap()`), Geister-KI (`ghost.gd`s
Sechs-Zustands-Automat HOUSE→LEAVING→SCATTER/CHASE→FRIGHTENED→EYES, ein
Skript für alle vier Persönlichkeiten, `_chase_target()`s vier
Original-Arcade-Zielregeln inkl. Inky-Vektorverdopplung), Power-Pellets +
Scoring (Geister-Fresskette 200/400/800/1600, geometrisch wachsende
Extra-Leben-Schwelle), wichtige Signale (inkl. der Beobachtung, dass
`score_changed` zwar emittiert, aber von niemandem abonniert ist — das HUD
aktualisiert sich direkt).

Zwei Graphviz-Diagramme: `scenetree.dot` (Szenenbaum von `pacman_map.tscn`,
dreizeilig gruppiert über unsichtbare Anker-Nodes, weil die 11 direkten
Kindnodes in einer Reihe unlesbar breit geraten wären) und `ghost_fsm.dot`
(der Geister-Zustandsautomat als eigenes Modul 05 — bei Pacman naheliegender
als ein UML-Klassendiagramm, weil die Zustandsmaschine der eigentliche
Kern der Spiellogik ist).

Zwei **echte** In-Game-Screenshots (`fig-chase.jpg`/`fig-frightened.jpg`)
statt Platzhalter — mangels offenem Editor (parallel lief eine
Galaga-Session mit eigenem `--editor`-Prozess, kein `godot-mcp-pro`-Zugriff
auf dieses Projekt) per Wegwerf-`_capture.gd`/`_capture.tscn`
(`pacman_map.tscn` laden, `settings.request_play()` aufrufen, ~7,5 s auf
Blinky/Pinky im Chase warten, dann direkt `game._start_frightened()`
aufrufen für den zweiten Shot) mit `godot --path . res://_capture.tscn --
<out_dir>` (braucht `DISPLAY`, kein `--editor`-Prozess, daher unproblematisch
neben der laufenden Galaga-Session) erzeugt, danach gelöscht (nicht
committet, wie bei Galagas eigenem `_capture.gd`).

Der „Dossier-Farben ⇄ Godot-Editor-Farben"-Umschalter für die Code-Panels
(seit Galaga Standard-Angebot bei jedem technischen Dossier, siehe globale
CLAUDE.md) ist von Anfang an dabei, inklusive Print-Unterstützung — der
Umschalter-Zustand bleibt auch im PDF sichtbar (nur die Code-Panels wechseln
auf das dunkle Editor-Aussehen, der Rest bleibt beim hellen Print-Schema).
Die Editor-Farbwerte sind identisch mit denen im Galaga-Dossier (dieselbe
Quelle `editor_data/editor_settings-4.7.tres` — ein globales, nicht
projektspezifisches Setting) und wurden zur Sicherheit erneut direkt aus der
Datei gegengeprüft, nicht aus dem Galaga-Dossier übernommen.

Verifiziert wie bei Galaga per `google-chrome --headless --print-to-pdf`
gegen die tatsächliche `file://`-Datei von
`Pacman-Architektur-Dossier.html` (13 Seiten) + `pdftoppm`-Sichtprüfung aller
Seiten, inklusive einer zweiten Prüfung mit vorab aktiviertem
Syntax-Umschalter (Aktivierungs-Skript ans Dateiende angehängt statt eines
`</body>`-String-Replace — siehe die entsprechende Testfalle im
Galaga-Dossier-Log der globalen CLAUDE.md).

## Splash mit Fake-Ladebalken (Stand 2026-09-26)

`splash-screen.png` (960×1280, 3:4, Hintergrund `#050716`) ist aus der
vorhandenen Nutzer-Grafik `splashscreen.jpeg` („PAC-CLONE ADVENTURE“)
erzeugt: `magick splashscreen.jpeg -resize 960x1280 -background "#050716"
-gravity center -extent 960x1280 -strip splash-screen.png`. Boot-Splash
(0,5 s) + `splash.gd` (aus mario-clone portiert): Bild mit gelbem
Fake-Ladebalken 3 s, dann Start-Screen; überspringbar. **Nur beim ersten
App-Start** (`Splash.shown` ist `static` und überlebt die Szenen-Reloads,
die pacman für jeden neuen Lauf macht); `game.gd` pausiert den Tree
währenddessen. Offene Punkte sammelt ab jetzt `TODO.md`.


## Mehrere Labyrinthe + 2 Spieler (Stand 2026-10-05, v1.3)

- **Labyrinthe**: `MazeGrid.GRID` ist jetzt `static var` (`MazeGrid.set_maze(i)`,
  `maze_for_level(level)`), Daten in `maze_data.gd` (**generiert** von
  `python3 tools/make_mazes.py`, Seeds/Seitengänge in `SPECS`; Labyrinth 0 =
  Original). Fest in allen: Geisterhaus, Tunnelzeile 13, Mittelband Zeilen 8–18,
  Startstreifen Zeile 22, Kraftpillen-Ecken, `NO_UP`-Zellen — nur oben (Zeilen
  1–7) und unten (19–28) werden neu erzeugt. Labyrinth 0 behält die handgemalte
  Tilemap (`tiles`), 1–4 zeichnet `maze_art.gd` (Wände pastell + dunkle Kontur,
  Korridore = Clear-Color-Blau). `Pills._ready` setzt Labyrinth 0 (statisch!
  nach Szenen-Reload sonst veraltet). Vor `Pills.reset_all()` immer
  `Game._apply_maze_for_level()`.
- **2 Spieler abwechselnd**: Zustand pro Spieler in `Game._ps`, Wechsel in
  `_switch_player()` (inkl. Pills-Snapshot und Labyrinth).
- Selbsttest `_check_maze()` prüft jedes Labyrinth (Erreichbarkeit, Sackgassen,
  feste Zellen). `draw_line(from, to, color, width)` — Farbe VOR Breite.
- `class_name`-Dateien neu → erst `godot --headless --path . --import`, sonst
  kennt `--script` sie nicht.
- **Wandernde Frucht** (`fruit_walker.gd`, v1.4): Sprite2D mit Gittersteuerung
  wie die Geister, Zufallsabbiegen, `leave()` → BFS zum nächsten Tunnel.
  Verweildauer `fruit_time_min/max` = 14–18 s.
- **Continue** (v1.5): `Game._save_checkpoint()` schreibt beim Eintritt in einen
  neuen Labyrinth-Block `progress/checkpoint_level`; `SettingsMenu` zeigt
  „Continue (Level N)“ und startet mit `cfg["start_level"]`.
- **Ab v1.6 zeichnet `maze_art.gd` ALLE Labyrinthe** (auch 0, blau) mit
  abgerundeten Ecken: Eckpunkte des Gitters klassifizieren (1 Wand = konvex →
  Ecke mit Hintergrundfarbe wegschneiden, 1 Frei = konkav → Wand-Fillet), Kanten
  um `R` an gerundeten Enden kürzen. Außerhalb des Gitters zählt als frei
  (= Clear-Color, die Korridorfarbe). Die `tiles`-TileMapLayer bleibt in der
  Szene, ist aber unsichtbar.
- **Netz-Züge (v1.7)**: `turns_net.gd` (`TurnsNet`, Nachrichten `cfg`/`state`/
  `turn_end`) über `net_link.gd` (Kopie aus tetris; `GAME="pacman"`,
  `MAGIC="PACMAN-LAN-1"`, Env `PACMAN_RELAY`, `application/config/relay_url` in
  project.godot). UI = „Game mode“-Panel in `settings_menu.gd` (`_mode_screen()`).
  `Game._net_*`: jedes Gerät spielt nur seine Züge (`_net_waiting` sperrt
  `_physics_process`), der Gegner-Stand kommt aus `_ps[remote]`. Test:
  `tools/nettest.gd` (host/guest [online]); lokaler Relay: `cd ../mario-clone/
  server && PORT=8765 node relay.js`. **Nicht `pkill -f "node relay.js"`** —
  trifft die eigene Shell.
