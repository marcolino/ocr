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
#  sudo apt install tesseract-ocr tesseract-ocr-ita imagemagick

INPUT_DIR=./books/tiff
OUTPUT_TESSERACT_DIR=./books/txt_tesseract_5_3_0
OUTPUT_EASYOCR_DIR=./books/txt_easyocr_1_7_2
TEMP_DIR=./books/tmp

mkdir -p "$OUTPUT_TESSERACT_DIR" "$OUTPUT_EASYOCR_DIR" "$TEMP_DIR"

for file_input in "$INPUT_DIR"/*; do
  if [[ "$file_input" =~ \.(pdf|tif|tiff)$ ]]; then
    base=$(basename "$file_input")
    name="${base%.*}"
    ext="${base##*.}"
    file_clean="$TEMP_DIR/${name}-clean.${ext}"
    file_output="${name}"

    echo "📖 processing image $name"

    # 1️⃣ Basic normalization and contrast correction with ImageMagick
    #echo "🧹 preprocessing image..."
    convert "$file_input" \
      -auto-orient \
      -colorspace Gray \
      -contrast-stretch 0.35x0.35% \
      -normalize \
      -deskew 40% +repage \
      -trim +repage \
      -morphology Close:1 Diamond \
      -normalize \
      -brightness-contrast 5x20 \
      "$file_clean"

    # 3️⃣ Tesseract OCR: Italian language, plain text output
    #echo "🔠 running Tesseract OCR..."
    tesseract "$file_clean" "$OUTPUT_TESSERACT_DIR/$file_output" -l ita --psm 3 txt 2>&1 | \
      egrep -v "Detected [0-9]+ diacritics" | \
      egrep -v "Estimating resolution"

    # 4️⃣ EasyOCR OCR: Italian language, plain text output
    #echo "🔠 running EasyOCR OCR..."
    if command -v python3 >/dev/null 2>&1 && [ -x ./easyocr_run.py ]; then
      ./easyocr_run.py "$file_clean" "$OUTPUT_EASYOCR_DIR/${file_output}.txt"
    fi

    # 4️⃣ Dehyphenation cleanup
    #echo "#️⃣ de-hyphening text..."
    if [ -x ./dehyphen.sh ]; then
      ./dehyphen.sh "$OUTPUT_TESSERACT_DIR/${file_output}.txt" "$OUTPUT_TESSERACT_DIR/${file_output}.txt"
      ./dehyphen.sh "$OUTPUT_EASYOCR_DIR/${file_output}.txt" "$OUTPUT_EASYOCR_DIR/${file_output}.txt"
    fi

    # Clean temporary files
    rm -f "$file_clean"
  fi
done

rmdir "$TEMP_DIR"
echo "✅ OCR complete."
exit 0