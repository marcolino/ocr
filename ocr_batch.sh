#!/usr/bin/env bash
#
# Scans a directory containing scanned books in TIFF format
#
# Description of the flow:
#  original.tif
#   ↓
#  ImageMagick: auto-rotate, normalize contrast, trim borders
#   ↓
#  unpaper: deskew, remove noise, whiten background
#   ↓
#  Tesseract OCR → UTF-8 text - # Easy OCR → UTF-8 text
#   ↓
#  dehyphen.sh cleanup
#   ↓
#  output.txt
#
# Prerequisites:
#  sudo apt update
#  sudo apt install tesseract-ocr tesseract-ocr-ita imagemagick unpaper

INPUT_DIR=./books/tiff
OUTPUT_TESSERACT_DIR=./books/txt_tesseract_5_3_0
OUTPUT_EASYOCR_DIR=./books/txt_easyocr_1_7_2
TEMP_DIR=./books/tmp

mkdir -p "$OUTPUT_TESSERACT_DIR" "$OUTPUT_EASYOCR_DIR" "$TEMP_DIR"

for f in "$INPUT_DIR"/*; do
  if [[ "$f" =~ \.(pdf|tif|tiff)$ ]]; then
    base=$(basename "$f")
    name="${base%.*}"
    echo "📖 processing image $name"

    # Temporary filenames
    TMP1="$TEMP_DIR/${name}_step1.tif"
    TMP2="$TEMP_DIR/${name}_clean.tif"

    # 1️⃣ Basic normalization and contrast correction with ImageMagick
    #echo "🧹 preprocessing image..."
    convert "$f" \
      -auto-orient \
      -colorspace Gray \
      -contrast-stretch 0.35x0.35% \
      -normalize \
      -deskew 40% \
      -trim +repage \
      "$TMP1"

    # 2️⃣ Advanced cleanup with convert (deskew, morphology, normalize, brightness-contrast)
    #echo "✅ cleaning up image..."
    convert "$TMP1" \
      -deskew 40% +repage \
      -morphology Close:1 Diamond \
      -normalize \
      -brightness-contrast 5x20 \
      "$TMP2"

    # 3️⃣ Tesseract OCR: Italian language, plain text output
    #echo "🔠 running Tesseract OCR..."
    tesseract "$TMP2" "$OUTPUT_TESSERACT_DIR/$name" -l ita --psm 3 txt 2>&1 | \
      egrep -v "Detected [0-9]+ diacritics" | \
      egrep -v "Estimating resolution"

    # 4️⃣ EasyOCR OCR: Italian language, plain text output
    #echo "🔠 running EasyOCR OCR..."
    if command -v python3 >/dev/null 2>&1 && [ -x ./easyocr_run.py ]; then
      ./easyocr_run.py "$TMP2" "$OUTPUT_EASYOCR_DIR/$name.txt"
    fi

    # 4️⃣ Dehyphenation cleanup
    #echo "#️⃣ de-hyphening text..."
    if [ -x ./dehyphen.sh ]; then
      ./dehyphen.sh "$OUTPUT_TESSERACT_DIR/$name.txt" "$OUTPUT_TESSERACT_DIR/$name.txt2"
      mv "$OUTPUT_TESSERACT_DIR/$name.txt2" "$OUTPUT_TESSERACT_DIR/$name.txt"

      ./dehyphen.sh "$OUTPUT_EASYOCR_DIR/$name.txt" "$OUTPUT_EASYOCR_DIR/$name.txt2"
      mv "$OUTPUT_EASYOCR_DIR/$name.txt2" "$OUTPUT_EASYOCR_DIR/$name.txt"
    fi

    # Clean temp files
    rm -f "$TMP1" "$TMP2"
  fi
done
rmdir "$TEMP_DIR"

echo "✅ OCR complete."

exit 0