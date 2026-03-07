import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class OcrResult {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final double confidence;
  final bool isReceipt;
  final String? error;

  OcrResult({
    this.amount,
    this.date,
    this.merchant,
    this.confidence = 0.0,
    this.isReceipt = true,
    this.error,
  });
}

class OcrService {
  TextRecognizer? _textRecognizer;

  Future<OcrResult> processReceipt(File imagePath) async {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imagePath);
    final RecognizedText recognizedText =
        await _textRecognizer!.processImage(inputImage);

    if (recognizedText.text.isEmpty) {
      return OcrResult(
          isReceipt: false, confidence: 0.0, error: 'No text found in image');
    }

    // Move heavy processing to another thread (isolate) to prevent ANR
    return await compute(_parseReceiptData, recognizedText.text);
  }

  static OcrResult _parseReceiptData(String text) {
    double? amount;
    DateTime? date;
    String? merchant;
    double confidence = 0.5;

    final List<String> lines = text.split('\n');

    // Simple receipt check: presence of specific keywords
    final receiptKeywords = RegExp(
        r"(?:TOTAL|CASH|TAX|VAT|VAT|RECEIPT|INVOICE|KSH|KES|AMOUNT|SUM|CHANGE|SUBTOTAL|QTY|PRICE)",
        caseSensitive: false);
    final hasKeywords = receiptKeywords.hasMatch(text);

    int keywordCount = 0;
    for (final line in lines) {
      if (receiptKeywords.hasMatch(line)) keywordCount++;
    }

    if (!hasKeywords && keywordCount < 1) {
      return OcrResult(
          isReceipt: false,
          confidence: 0.1,
          error: 'Does not look like a receipt');
    }

    if (keywordCount >= 3) confidence += 0.2;

    // Extract Merchant (Assume first or second line is merchant name)
    if (lines.isNotEmpty) {
      merchant = lines[0].trim();
      if (merchant.length < 3 && lines.length > 1) {
        merchant = lines[1].trim();
      }
    }

    // Extraction patterns
    final amountRegex = RegExp(
        r"(?:Total|Amount|Sum|Ksh|KES|USD)[:\s]*([\d,]+\.\d{2})",
        caseSensitive: false);
    final dateRegex = RegExp(r"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})");

    for (String line in lines) {
      // Amount extraction
      final amountMatch = amountRegex.firstMatch(line);
      if (amountMatch != null && amount == null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
        if (amount != null) confidence += 0.2;
      }

      // Date extraction — try DD/MM/YYYY first (Kenya standard locale)
      // then fall back to MM/DD/YYYY for ambiguous formats.
      final dateMatch = dateRegex.firstMatch(line);
      if (dateMatch != null && date == null) {
        try {
          final part1 = int.parse(dateMatch.group(1)!);
          final part2 = int.parse(dateMatch.group(2)!);
          final yStr = dateMatch.group(3)!;
          final y = yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr);

          // Prefer DD/MM (part1=day, part2=month) if month is valid
          if (part2 >= 1 && part2 <= 12 && part1 >= 1 && part1 <= 31) {
            date = DateTime(y, part2, part1); // DD/MM/YYYY
            confidence += 0.1;
          } else if (part1 >= 1 && part1 <= 12 && part2 >= 1 && part2 <= 31) {
            // Fallback: MM/DD/YYYY
            date = DateTime(y, part1, part2);
            confidence += 0.1;
          }
        } catch (_) {}
      }
    }

    // Fallback amount search (highest value that looks like an amount)
    if (amount == null) {
      final fallbackAmountRegex = RegExp(r"([\d,]+\.\d{2})");
      double? maxAmount;
      for (String line in lines) {
        final matches = fallbackAmountRegex.allMatches(line);
        for (var match in matches) {
          final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
          // In a receipt, total is rarely more than 1M for a single grocery/etc, but let's be safe
          if (val != null && (maxAmount == null || val > maxAmount)) {
            maxAmount = val;
          }
        }
      }
      amount = maxAmount;
      if (amount != null) confidence += 0.1;
    }

    return OcrResult(
      amount: amount,
      date: date,
      merchant: merchant,
      confidence: confidence.clamp(0.0, 1.0),
      isReceipt: true,
    );
  }

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
