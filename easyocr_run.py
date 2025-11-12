#!/usr/bin/env python3

import sys
import easyocr
import warnings

if len(sys.argv) != 3:
  print("Usage: easyocr_run.py input.tif output.txt")
  sys.exit(1)

language = 'it'
input_file, output_file = sys.argv[1], sys.argv[2]

warnings.filterwarnings("ignore", message=".*pin_memory.*")
reader = easyocr.Reader([language], gpu=False, verbose=False)
result = reader.readtext(input_file, detail=0, paragraph=True)

with open(output_file, "w", encoding="utf-8") as f:
  f.write("\n".join(result))