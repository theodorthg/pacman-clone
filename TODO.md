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

## Erledigt

- [x] 2026-09-29 itch.io jetzt per `butler` in die Channels linux / android / windows / web (`theodorthg/pac-clone`, wie bei mario-clone); Patch-Release v1.2.1: Stand seit v1.2 (Splash mit Ladebalken, weißer Android-Startbildschirm) — damit Windows-Release und itch.io aktuell sind.
- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
- [x] 2026-09-26 Splash mit Fake-Ladebalken (`splash.gd`) aus der
      vorhandenen Grafik `splashscreen.jpeg`, Boot-Splash gesetzt; nur beim
      ersten App-Start.
