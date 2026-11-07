# Lokaler OCR-Dienst fuer IPA-Eingaben

Wandelt Scans ohne Textebene in durchsuchbare PDFs um, ohne dass Inhalte an externe Dienste gelangen. Ergebnis: `Originalname-OCR.pdf` im selben Dropbox-Unterordner. Originale werden nie ueberschrieben.

## Architektur

Zwei Container teilen sich `/srv/ipa-ocr/data`, ein dritter zeigt das Log.

| Container | Image | Netzwerk | Aufgabe |
| --- | --- | --- | --- |
| `ipa-sync` | `rclone/rclone:latest` | Internet | Alle 10 Minuten PDFs aus Dropbox nach `/data` ziehen (`--update`), `*-OCR.pdf` hochladen (`--ignore-existing`) |
| `ipa-ocr` | `ipa-ocr:3` (lokal gebaut) | `none` | Alle 5 Minuten PDFs mit mindestens einer Seite unter 50 Zeichen per OCRmyPDF verarbeiten |
| `ipa-log` | `ipa-ocr:3` | `none` | Folgt `/logs/ocr.log`, damit die Portainer-Logansicht den OCR-Verlauf zeigt |

Der OCR-Container hat keinen Netzwerkzugriff. Nur `ipa-sync` spricht mit Dropbox.

## Dateien

- `Dockerfile`: Debian bookworm-slim mit OCRmyPDF, Tesseract (deu, eng), poppler-utils, Ghostscript
- `ocr-loop.sh`: Verarbeitungsschleife (Erkennung pro Seite, `.part.pdf` als Zwischenname, Log nach `/logs/ocr.log`)
- `compose.yml`: Stack fuer `docker compose` oder Portainer
- `rclone.conf.example`: Vorlage ohne Zugangsdaten

## Einrichtung

```bash
sudo mkdir -p /srv/ipa-ocr/{build,data,logs,rclone}
# Dockerfile und ocr-loop.sh nach /srv/ipa-ocr/build kopieren
cd /srv/ipa-ocr/build && sudo docker build -t ipa-ocr:3 .

# Dropbox-Zugang (headless): rclone auf dem Host installieren und konfigurieren
sudo apt-get install -y rclone
sudo rclone config --config /srv/ipa-ocr/rclone/rclone.conf
sudo chmod 600 /srv/ipa-ocr/rclone/rclone.conf
sudo rclone ls "dropbox:IPA 2027" --config /srv/ipa-ocr/rclone/rclone.conf | head
```

Danach `compose.yml` als Stack deployen (Portainer: Stacks, Add stack, Web editor) oder per `docker compose up -d`. Das Image muss auf derselben Docker-Engine liegen, auf der der Stack laeuft.

## Betrieb

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
tail -f /srv/ipa-ocr/logs/ocr.log
docker logs --tail 20 ipa-sync
```

- **Skript aendern:** Datei bearbeiten, `head -2 ocr-loop.sh && bash -n ocr-loop.sh`, mit neuem Tag bauen, im Stack `image:` fuer `ipa-ocr` und `ipa-log` anpassen und den Stack aktualisieren (Haken «Re-pull image» aus, das Image ist nur lokal).
- **Datei erneut verarbeiten:** die zugehoerige `-OCR.pdf` in `/srv/ipa-ocr/data` loeschen. Die Schleife erzeugt sie innerhalb von 5 Minuten neu.
- **Nachweis «kein Netzwerk»:** `docker inspect ipa-ocr --format '{{.HostConfig.NetworkMode}}'` liefert `none`.

## Stolpersteine

- **`exec format error`:** Die Shebang steht nicht in Zeile 1 (oder die Datei hat `\r`-Zeilenenden). Pruefen: `head -c 80 ocr-loop.sh | od -c`.
- **Pull ueberschreibt lokale OCR-Dateien:** Ohne `--update` ersetzt `rclone copy` eine lokal erzeugte `-OCR.pdf` durch eine abweichende Dropbox-Version.
- **`deploy.resources.limits` greift nicht:** `mem_limit` auf Service-Ebene verwenden. Pruefen: `docker inspect ipa-ocr --format '{{.HostConfig.Memory}}'` liefert `2147483648`.
- **Portainer-Log von `ipa-ocr` leer:** Das Skript schreibt nur nach `/logs/ocr.log`. Dafuer gibt es `ipa-log`.
- **`docker build` aendert laufende Container nicht:** Erst die Stack-Aenderung auf den neuen Tag erstellt den Container neu.

## Offen vor dem Produktivbetrieb

- Datenschutz: Zulaessigkeit der lokalen Kopien bestaetigen lassen, Datentraegerverschluesselung klaeren.
- Aufbewahrung: festlegen, wann `/srv/ipa-ocr/data` nach Abschluss der Pruefung geleert wird.
- Qualitaetsschwelle fuer «OCR unbrauchbar» definieren (Stichprobe der Kernzahlen pro Scan).
- Eine neue Fassung einer Eingabe unter gleichem Namen wuerde die bestehende `-OCR.pdf` behalten. Optional in `ocr-loop.sh`: `[ "$out" -nt "$f" ] && continue` statt `[ -e "$out" ] && continue`.
- `rclone.conf` nie committen (steht in `.gitignore`).
