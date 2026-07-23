# DiskScope öffentlich verteilen

DiskScope wird außerhalb des Mac App Store als Developer-ID-signierte und von
Apple notarisierte Open-Source-App verteilt.

## Voraussetzungen

1. Mitgliedschaft im Apple Developer Program.
2. Zertifikat vom Typ `Developer ID Application` im Schlüsselbund.
3. Aktuelle vollständige Xcode-Installation mit `notarytool`.
4. Ein in `notarytool` gespeichertes Keychain-Profil.

## Notary-Profil einmalig speichern

```sh
xcrun notarytool store-credentials "DiskScope-Notary"
```

Die Zugangsdaten werden im macOS-Schlüsselbund gespeichert und gehören nicht
in das Repository.

## Release erstellen

```sh
export DISKSCOPE_SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)"
export DISKSCOPE_NOTARY_PROFILE="DiskScope-Notary"
./release.sh
```

Das Skript:

1. baut eine Universal-App für Apple Silicon und Intel,
2. aktiviert Hardened Runtime,
3. signiert App und DMG mit Developer ID,
4. übermittelt das DMG an Apples Notarisierungsdienst,
5. heftet das Notarisierungsticket an das DMG,
6. validiert das fertige Release.

## Datenschutzfreigabe

Festplattenvollzugriff kann und darf nicht automatisch erteilt werden. Beim
ersten Start erklärt DiskScope diesen einmaligen Schritt und öffnet auf Wunsch
die entsprechende Systemeinstellung. Mit einer stabilen Developer-ID-Signatur
erkennt macOS spätere Releases weiterhin als dieselbe App.
