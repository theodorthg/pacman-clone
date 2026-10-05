# TODO — pacman

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben.

## Offen

- [ ] Alte, von Hand hochgeladene Dateien auf itch.io löschen (macht der Nutzer: https://itch.io/game/edit/…, Seite `pac-clone`) und beim Upload des Channels `web` „This file will be played in the browser“ setzen.
- [ ] Im Arbeitsverzeichnis liegen fremde, nicht committete Änderungen
      (Dateirechte 644→755 bei fast allen Dateien, `.claude/launch.json`,
      untracked PDFs/Dossier-`.import`s) — prüfen/aufräumen. (Die fehlenden
      MCP-Autoload-Zeilen in `project.godot` sind seit dem Splash-Commit
      wieder drin.)

Ideen für später (Einschätzung 2026-10-03, noch nicht beauftragt):
- Gleichzeitig zu zweit (beide im selben Labyrinth, sich nach einer
  Kraftpille gegenseitig fressen — „Battle Royale“-Art) wäre möglich,
  ist aber mit Swipe-Steuerung nur per Netz sinnvoll.
- Empfehlung: zuerst mehr Labyrinthe (Einzelspieler), Mehrspieler nur
  abwechselnd und niedrig priorisiert.

Gemeinsam für die Serie (Vorlage: mario-clone v1.6–v1.9):
- [ ] Bausteine aus mario-clone übernehmen statt neu erfinden: `CoopInput`
      + Beitreten-Bildschirm (jeder drückt A auf seinem Gerät),
      `NetLink`/`NetHost`/`NetClient` (Host rechnet, Gast zeigt; LAN +
      Online), Team-Eintrag in der Bestenliste, Spielstand/Continue,
      F12-Screenshot.
- [ ] Ein Relay für alle Spiele: `server/relay.js` um eine Spiel-Kennung
      in „host“/„join“ erweitern (sonst landet ein Galaga-Gast in einem
      Mario-Raum), Pfad bleibt `wss://broesel.net/mario-relay` oder ein
      neutraler Name.
- Hinweise: Hochkant-Spiele auf dem Handy zu zweit nur per Netz (zwei
  Leute an einem Handy-Bildschirm ist unpraktisch); lokal zu zweit am PC
  (geteilte Tastatur / zwei Pads) bzw. im Browser. Das RG552 kann wegen
  des kaputten Bluetooth kein zweites Pad.

## Erledigt

- [x] 2026-10-05 v1.10 Jingles für die Zwischenspiele (`tools/make_jingles.py` → `assets/sounds/intermission1-3.wav`, Chiptune, Regler „Intermission jingle“ in den Sound-Einstellungen, Bild bleibt bis zum Ende des Jingles). Geisterverhalten je Labyrinth (`Game._MAZE_RULES`: Tempo, Scatter-/Chase-Dauer, Blauzeit, Geisterhaus-Limits, Pinky-/Inky-/Clyde-Parameter; Classic/Ambush/Cunning/Marathon/Furious).
- [x] 2026-10-05 v1.9 Zwischenspiele (`intermission.gd`): nach Level 2, 5, 9 und danach jedem 4. Level ein kurzer Cartoon aus den Spiel-Sprites (Akt 1 Blinky jagt Pac-Man und wird dann vom Riesen-Pac-Man gejagt, Akt 2 Pinky+Inky, Akt 3 alle vier, am Ende rasen die Augen heim); ~8 s, mit beliebiger Taste/Tipp überspringbar.
- [x] 2026-10-05 v1.8 Wie bei Mario: Play (und Continue) öffnen direkt „How do you want to play?“ (1 Player / 2 Players this device / Online / Wi-Fi-LAN) — der Extra-Button im Startmenü entfällt; Continue-Level wird auch in Netz-Spiele übernommen (Host gibt vor). Netz auf zwei echten Geräten getestet (RG552 = Host, OnePlus = Gast, LAN-Auto-Suche, 3 Züge je Spieler, beide zeigen am Ende 70:70 „DRAW“). Gefunden per logcat: das WLAN des RG552 stockt gelegentlich mehrere Sekunden, ENet-Timeout von 8 s kappte die Verbindung kurz vor dem letzten `turn_end` → Timeout jetzt 10–30 s.
- [x] 2026-10-05 v1.7.2 Startmenü-Button heißt jetzt fest „Multiplayer Settings“ (statt wechselndem „Game mode: …“); das Untermenü zeigt oben „Current: …“ und die Wahl (1 Spieler / 2 Spieler hier / Online / WLAN-LAN) mit Untermenüs; Hilfe und Wartetexte angepasst.
- [x] 2026-10-05 v1.7.1 Netz-Züge auf echten Geräten getestet (PC als LAN-Host per `tools/nettest.gd`, RG552 als Gast per Menü: Host wurde automatisch gefunden, Verbinden, Zugwechsel mit Live-Stand „P1 160 x2 L1“, Spielende mit gleichen Ständen auf beiden Seiten). Fix: Fokus sprang bei jeder Host-Listenaktualisierung ins IP-Feld und öffnete die Bildschirmtastatur. Das Handy (OnePlus) war gesperrt und blieb außen vor.
- [x] 2026-10-05 v1.7 Spielmodus-Menü („Game mode“ im Startmenü): 1 Spieler / 2 Spieler an diesem Gerät / 2 Spieler Online (Relay, 4-Buchstaben-Code) / 2 Spieler WLAN-LAN, jeweils abwechselnd. Netz: jedes Gerät simuliert nur den eigenen Zug (`turns_net.gd` + `net_link.gd` aus tetris, Spiel-Kennung „pacman“); beim Warten sieht man Punkte/Leben/Level des anderen live; Spielende auf beiden Seiten mit beiden Ständen, je ein Hall-of-Fame-Eintrag (nur der eigene). Host = Spieler 1 und gibt die Spieleinstellungen vor. `tools/nettest.gd` testet das mit zwei Prozessen (LAN und Relay). Android: Internet-Berechtigung an. Noch nicht auf echten zwei Geräten gespielt.
- [x] 2026-10-05 v1.6 Alle Labyrinthe (auch das Original) einheitlich von `maze_art.gd` gezeichnet, jetzt mit abgerundeten Ecken (konvex/konkav, Radius 6 px); die alte Tilemap-Grafik ist stillgelegt (`tiles` unsichtbar). Hilfe: neue Seiten „Bonus Fruit“, „Two Players“, „Mazes & Continue“ (`assets/help_src/{fruit,players,continue}.svg`), Goal-Seite angepasst.
- [x] 2026-10-05 v1.5 Continue: beim Betreten eines neuen Labyrinth-Blocks (Level 3/6/10/14/18/…) wird der Start-Level gespeichert (`progress/checkpoint_level` in settings.cfg); Startmenü zeigt dann „Continue (Level N)“ — neuer Lauf ab diesem Level mit frischem Punktestand und Leben (beide Spieler im 2-Spieler-Modus).
- [x] 2026-10-05 v1.4 Wandernde Frucht (`fruit_walker.gd`): kommt durch einen Seitentunnel, biegt an jeder Kreuzung zufällig ab (nie direkt zurück), ist mit 55 px/s deutlich langsamer als Pac-Man, bleibt 14–18 s und läuft dann per BFS zum nächsten Tunnel und verschwindet; bleibt bei Hitstop/Tod stehen.
- [x] 2026-10-05 v1.3 Mehrere Labyrinthe: Original + 4 neue (`maze_data.gd`, erzeugt von `tools/make_mazes.py`: Skelett mit Geisterhaus/Tunnel/Mittelband bleibt, oben/unten zufällig aus Korridor-Gitter + Durchbrüchen, Seitengänge in Labyrinth 3/4); Wechsel Level 1–2 Original, 3–5 rosa, 6–9 türkis, 10–13 orange, ab 14 grün/rosa/türkis/orange im 4er-Takt. Gezeichnet von `maze_art.gd` (Original behält die Tilemap). Selbsttest prüft Erreichbarkeit, Sackgassen, feste Zellen. Pro Spieler im 2-Spieler-Modus eigenes Labyrinth je Level.
- [x] 2026-10-05 2 Spieler abwechselnd: Startmenü-Schalter „1 Player / 2 Players (turns)“ (`players` in settings.cfg); pro Spieler eigener Punktestand, Leben, Level, Brett (`Pills.snapshot()/restore()`) und Extraleben-Schwellen; nach einem Tod wechselt der Zug („P2 READY!“, „P1 GAME OVER“ bei letztem Leben); Endbildschirm mit beiden Punkteständen/Gewinner und je ein Hall-of-Fame-Eintrag pro Spieler (Namensfeld nacheinander). Logik per Wegwerf-Headless-Test geprüft; noch nicht auf dem RG552 live gespielt.
- [x] 2026-09-29 itch.io jetzt per `butler` in die Channels linux / android / windows / web (`theodorthg/pac-clone`, wie bei mario-clone); Patch-Release v1.2.1: Stand seit v1.2 (Splash mit Ladebalken, weißer Android-Startbildschirm) — damit Windows-Release und itch.io aktuell sind.
- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
- [x] 2026-09-26 Splash mit Fake-Ladebalken (`splash.gd`) aus der
      vorhandenen Grafik `splashscreen.jpeg`, Boot-Splash gesetzt; nur beim
      ersten App-Start.
