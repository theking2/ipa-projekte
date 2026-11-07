FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ocrmypdf tesseract-ocr-deu tesseract-ocr-eng poppler-utils ghostscript \
    unpaper pngquant findutils && rm -rf /var/lib/apt/lists/*
COPY ocr-loop.sh /usr/local/bin/ocr-loop.sh
RUN chmod +x /usr/local/bin/ocr-loop.sh
ENTRYPOINT ["/usr/local/bin/ocr-loop.sh"]
