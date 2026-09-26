# TODO — pacman

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben.

## Offen

- [ ] Im Arbeitsverzeichnis liegen fremde, nicht committete Änderungen
      (Dateirechte 644→755 bei fast allen Dateien, `.claude/launch.json`,
      untracked PDFs/Dossier-`.import`s) — prüfen/aufräumen. (Die fehlenden
      MCP-Autoload-Zeilen in `project.godot` sind seit dem Splash-Commit
      wieder drin.)

## Erledigt

- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
- [x] 2026-09-26 Splash mit Fake-Ladebalken (`splash.gd`) aus der
      vorhandenen Grafik `splashscreen.jpeg`, Boot-Splash gesetzt; nur beim
      ersten App-Start.
