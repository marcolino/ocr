#!/usr/bin/env python

import os
import pandas as pd
import Levenshtein
import nltk
from nltk.tokenize import word_tokenize
from sacrebleu import corpus_bleu

# Scarica il tokenizer se non già presente
nltk.download('punkt')

# -------- CONFIGURAZIONE --------
REFERENCE_FOLDER = "books/txt_reference" # cartella con testi corretti di riferimento
OCR_FOLDERS = ["books/txt_tesseract_1_0_0", "books/txt_tesseract_5_3_0", "books/txt_easyocr_1_7_2", "books/txt_tesseract_5_3_0_chatgpt"] # cartelle OCR
OUTPUT_CSV = "ocr_comparison_results.csv" # file di output

# -------- FUNZIONI UTILI --------
def load_text(path):
  with open(path, "r", encoding="utf-8") as f:
    return f.read()

def char_accuracy(ref, hyp):
  distance = Levenshtein.distance(ref, hyp)
  return max(0, 1 - distance / max(len(ref), 1)) * 100

def word_accuracy(ref, hyp):
  ref_words = word_tokenize(ref)
  hyp_words = word_tokenize(hyp)
  correct = sum(r==h for r,h in zip(ref_words, hyp_words))
  return correct / max(len(ref_words), 1) * 100

def bleu_score(ref_texts, hyp_texts):
  # sacreBLEU expects list of references as list of lists
  refs = [[r] for r in ref_texts]
  return corpus_bleu(hyp_texts, refs).score

def generate_comment(ref_texts, hyp_texts):
  comments = []
  for r, h in zip(ref_texts, hyp_texts):
    if "0" in r and "O" in h or "O" in r and "0" in h:
      comments.append("Confusione O/0")
    if any(c in r and c not in h for c in "àèéòù"):
      comments.append("Errori su accenti")
    if len(word_tokenize(r)) != len(word_tokenize(h)):
      comments.append("Omissioni o duplicazioni di parole")
  if not comments:
    return "Buona accuratezza"
  # rimuove duplicati
  return ", ".join(sorted(set(comments)))

# -------- SCRIPT PRINCIPALE --------
results = []

reference_files = sorted(os.listdir(REFERENCE_FOLDER))

for ocr_folder in OCR_FOLDERS:
  char_acc_list = []
  word_acc_list = []
  ref_texts, hyp_texts = [], []
  
  for filename in reference_files:
    ref_path = os.path.join(REFERENCE_FOLDER, filename)
    hyp_path = os.path.join(ocr_folder, filename)
    
    if not os.path.exists(hyp_path):
      print(f"Attenzione: {hyp_path} non trovato, salta.")
      continue
    
    ref_text = load_text(ref_path)
    hyp_text = load_text(hyp_path)
    
    char_acc_list.append(char_accuracy(ref_text, hyp_text))
    word_acc_list.append(word_accuracy(ref_text, hyp_text))
    ref_texts.append(ref_text)
    hyp_texts.append(hyp_text)
  
  avg_char_acc = sum(char_acc_list)/len(char_acc_list)
  avg_word_acc = sum(word_acc_list)/len(word_acc_list)
  avg_bleu = bleu_score(ref_texts, hyp_texts)
  
  # Punteggio finale 1-100
  score = 0.4*avg_char_acc + 0.4*avg_word_acc + 0.2*avg_bleu
  
  comment = generate_comment(ref_texts, hyp_texts)
  
  results.append({
    "Cartella OCR": ocr_folder,
    "Char Acc %": round(avg_char_acc, 2),
    "Word Acc %": round(avg_word_acc, 2),
    "BLEU": round(avg_bleu, 2),
    "Score 1-100": round(score, 2),
    "Commento sintetico": comment
  })

# Salva tabella finale
df = pd.DataFrame(results)
df.to_csv(OUTPUT_CSV, index=False)
print(f"Tabella comparativa salvata in {OUTPUT_CSV}")
print(df)
