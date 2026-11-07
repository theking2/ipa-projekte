#!/bin/bash
# Verarbeitet PDFs, bei denen mindestens eine Seite keine Textebene hat.
# Originale werden nie veraendert. Ergebnis: <Name>-OCR.pdf im selben Ordner.
LOG=/logs/ocr.log
MIN_PAGE_CHARS=50   # Seite mit weniger Zeichen gilt als Scan

needs_ocr() {
  n=$(pdfinfo "$1" 2>/dev/null | awk '/^Pages:/{print $2}')
  [ -z "$n" ] && return 1
  for p in $(seq 1 "$n"); do
    c=$(pdftotext -f "$p" -l "$p" "$1" - 2>/dev/null | wc -c)
    [ "$c" -lt "$MIN_PAGE_CHARS" ] && return 0
  done
  return 1
}

while true; do
  find /data -type f -iname '*.pdf' ! -iname '*-OCR.pdf' ! -iname '*.part.pdf' -print0 |
  while IFS= read -r -d '' f; do
    out="${f%.pdf}-OCR.pdf"; part="${f%.pdf}.part.pdf"
    [ -e "$out" ] && continue
    needs_ocr "$f" || continue
    echo "$(date -Is) START $f" >> "$LOG"
    if ocrmypdf -l deu+eng --deskew --rotate-pages --skip-text --output-type pdf --jobs 2 "$f" "$part" >> "$LOG" 2>&1; then
      mv "$part" "$out"
      after=$(pdftotext "$out" - 2>/dev/null | wc -c)
      echo "$(date -Is) OK    $out (Zeichen nachher: $after)" >> "$LOG"
    else
      rm -f "$part"
      echo "$(date -Is) FEHLER $f" >> "$LOG"
    fi
  done
  sleep 300
done
