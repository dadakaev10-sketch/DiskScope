# DiskScope

DiskScope ist eine lokale, native und quelloffene macOS-App zur Analyse von
Ordnergrößen.

## Download und Installation

**[DiskScope direkt als DMG herunterladen](https://github.com/dadakaev10-sketch/DiskScope/releases/latest/download/DiskScope.dmg)**

Alternativ findest du die DMG und alle Versionshinweise unter
[GitHub Releases](https://github.com/dadakaev10-sketch/DiskScope/releases/latest).
Ein Apple-Developer-Account ist für die Installation **nicht** erforderlich.

Die aktuelle Open-Source-Version ist noch nicht von Apple notarisiert. Deshalb
zeigt macOS beim ersten Start eine Sicherheitsmeldung:

1. `DiskScope.app` aus der DMG in den Ordner „Programme“ ziehen.
2. DiskScope einmal öffnen.
3. Falls macOS die App blockiert: „Systemeinstellungen“ → „Datenschutz &
   Sicherheit“ öffnen und unter „Sicherheit“ auf „Dennoch öffnen“ klicken.
4. DiskScope erneut öffnen und den einmaligen Festplattenvollzugriff erlauben,
   wenn auch geschützte Ordner analysiert werden sollen.

Lade ausführbare Dateien ausschließlich von der offiziellen Release-Seite
dieses Repositorys herunter.

## Funktionen

- logische und zugeordnete Dateigröße
- direkte Auswahl von Macintosh HD, Benutzerordnern und Laufwerken
- navigierbare Ordnerstruktur mit Größenangaben und Pfadnavigation
- Cache für die letzten fünf abgeschlossenen Analysen
- Mehrfachauswahl von Dateien und Ordnern für den Papierkorb
- eigene App-Ansicht mit Größe und Speicherort installierter Programme
- versteckte Dateien und Ordner werden mit ihrem Punktnamen dargestellt
- integrierte Sprachwahl für Deutsch, Englisch und Spanisch
- größte Unterordner und Dateien
- mögliche Duplikate anhand gleicher Namen und Dateigrößen
- Laufwerksbelegung
- Hinweise auf Cache-, temporäre und große Modelldateien
- Finder-Integration
- bestätigtes Verschieben einzelner Einträge in den Papierkorb
- keine Netzwerkverbindung und keine automatische Löschung

## Zugriff beim ersten Start

Beim ersten Start erklärt DiskScope einmalig, wie der vollständige
Festplattenzugriff in macOS freigegeben wird. Diese Freigabe muss aus
Sicherheitsgründen vom Nutzer selbst bestätigt werden. Danach fragt DiskScope
nicht erneut, solange App-Identität und Systemeinstellung erhalten bleiben.

## Bauen

Voraussetzung sind macOS 14 oder neuer und die Apple Command Line Tools. Die
App wird als Universal Binary für Apple Silicon und Intel gebaut:

```sh
./build.sh
```

Das Ergebnis liegt anschließend unter `build/DiskScope.app`.

## Lizenz

DiskScope steht unter der [MIT-Lizenz](LICENSE).

---

DiskScope is a native, open-source macOS disk analyzer. It runs entirely on
the local Mac, supports German, English and Spanish, never deletes files
automatically, and is available under the MIT License.
