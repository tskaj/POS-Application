import '../models/product.dart';

/// Returns a numeric-only EAN-13 barcode string for [product].
///
/// Strategy:
/// 1. Try to extract digits from `product.barcode`.
/// 2. If there are digits, build a 12-digit base (pad or trim) and append EAN-13 check digit.
/// 3. If no digits are found, fall back to using product.id to form the base.
String getNumericBarcode(Product product) {
  final raw = product.barcode.toString();
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

  String base12;
  if (digitsOnly.isNotEmpty) {
    // Use the digits found. If too long, take the leftmost 12 digits.
    if (digitsOnly.length >= 12) {
      base12 = digitsOnly.substring(0, 12);
    } else {
      base12 = digitsOnly.padLeft(12, '0');
    }
  } else {
    // Fallback: use product.id to create a deterministic numeric base
    final idStr = product.id.toString();
    if (idStr.length >= 12) {
      base12 = idStr.substring(0, 12);
    } else {
      base12 = idStr.padLeft(12, '0');
    }
  }

  final check = _calculateEan13CheckDigit(base12);
  return '$base12$check'; // 13 digits
}

/// Calculate EAN-13 check digit for a 12-digit string.
int _calculateEan13CheckDigit(String base12) {
  if (base12.length != 12) {
    // If incorrect length, normalize by padding/trimming
    final normalized = base12.length > 12
        ? base12.substring(0, 12)
        : base12.padLeft(12, '0');
    base12 = normalized;
  }

  int sum = 0;
  for (int i = 0; i < 12; i++) {
    final int digit = int.tryParse(base12[i]) ?? 0;
    // positions are counted from left, but weighting is from right: even positions *3
    // EAN-13: sum of digits in odd positions + 3 * sum of digits in even positions
    if ((i % 2) == 0) {
      // i = 0 is position 1 (odd)
      sum += digit;
    } else {
      sum += digit * 3;
    }
  }
  final mod = sum % 10;
  return mod == 0 ? 0 : (10 - mod);
}

/// Generate numeric EAN-13 string from a raw input string (may contain letters).
String getNumericBarcodeFromString(String raw) {
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

  String base12;
  if (digitsOnly.isNotEmpty) {
    if (digitsOnly.length >= 12) {
      base12 = digitsOnly.substring(0, 12);
    } else {
      base12 = digitsOnly.padLeft(12, '0');
    }
  } else {
    // If nothing numeric, fallback to a deterministic zero base
    base12 = '000000000000';
  }

  final check = _calculateEan13CheckDigit(base12);
  return '$base12$check';
}

/// Generate a set of lookup candidate strings from a scanned/raw barcode value.
///
/// This returns multiple normalized variants so the POS lookup can match
/// barcodes printed in different symbologies (e.g. Code39 with *start/stop*,
/// Codabar with A/B start/stop, plain numeric EAN/UPC or derived EAN-13 form).
List<String> generateBarcodeLookupCandidates(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return [];

  final lower = trimmed.toLowerCase();
  final candidates = <String>{};

  // Raw form (lowercased)
  candidates.add(lower);

  // Digits-only form
  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isNotEmpty) candidates.add(digitsOnly);

  // EAN-13 derived numeric form (always 13 digits)
  try {
    final ean = getNumericBarcodeFromString(trimmed);
    if (ean.isNotEmpty) candidates.add(ean);
  } catch (_) {}

  // Strip common start/stop characters used by some symbologies:
  // - Code39 often uses '*' as start/stop
  // - Codabar may use A/B/C/D as start/stop
  if (lower.length > 2) {
    // Code39: often wrapped with '*' characters
    if (lower.startsWith('*') && lower.endsWith('*')) {
      candidates.add(lower.substring(1, lower.length - 1));
    }

    // Codabar: simple first/last char check for A-D
    final firstChar = lower[0];
    final lastChar = lower[lower.length - 1];
    final codabarChars = RegExp(r'^[a-d]$', caseSensitive: false);
    if (codabarChars.hasMatch(firstChar) && codabarChars.hasMatch(lastChar)) {
      candidates.add(lower.substring(1, lower.length - 1));
    }
  }

  return candidates.toList();
}
