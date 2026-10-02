import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'package:cyber_nova/config/app_config.dart';

const String kSystemPrompt = '''You are the visual extraction component of Cyber Nova, an AI-assisted Legal Metrology packaged-commodity inspection system for India.

CORE INSTRUCTION: Treat this first and foremost as a PRECISE OCR task. You must read every piece of visible text on the product packaging, including small print, corners, bottom edges, and side panels. Do NOT restrict yourself to large or prominent text.

Your responsibility is to inspect the supplied product label image and extract information that is visibly present on the packaging.

You are NOT the final legal compliance authority.

If information is truly not visible AT ALL, return null.

HOWEVER — if information is partially visible, slightly blurred, or in a small font but still readable by a human, you MUST extract it with an appropriately reduced confidence (0.4-0.7). DO NOT return null just because text is small or slightly unclear.

Preserve the visible text as accurately as possible, including exact wording, capitalisation, and numbers.

PRIORITY EXTRACTION LIST (scan the ENTIRE label for these fields):

1. Branded / full Product Name — including any brand prefix
2. Common / generic product name — the generic commodity description (e.g. "Bread", "Biscuit", "Rice"). Return null if no visible generic/common name differs from the branded title
3. Manufacturer — Mfg. by, Manufactured by, Manufacturer
4. Packer — Packed by, Mkt. by, Marketed by, Packer
5. Importer — Imported by, Importer
6. Complete postal address of any of the above parties (including street, city, district, pin code)
7. Dimensions / Size — only when applicable and visible. e.g. "10 × 5 × 2 cm" for garments, blankets, textiles, packages. Return null if not applicable / not declared
8. Country of origin — Made in, Country of Origin, Origin
9. Net quantity — NET WT, Net Qty, Net Weight, Net Volume, followed by number + unit
   UNITS TO RECOGNISE: g, gm, gram, grams, kg, kilogram, ml, milliliter, L, ltr, litre, liter, nos, no, pieces, pcs, piece, count, unit
   ALSO recognise declared number/count based quantities: Pack, Case, Dozen, Piece when clearly a quantity declaration (context-aware)
10. Unit (as above)
11. MRP / Maximum Retail Price — HIGHEST PRIORITY
    SPECIFIC MRP PATTERNS: Look carefully for ANY of the following:
      • Text labels: "MRP", "M.R.P.", "MRP:", "M.R.P:", "Maximum Retail Price", "Max Retail Price", "Max. Ret. Price"
      • Currency symbols: ₹ (Indian Rupee sign), Rs, Rs., INR, Re, Re.
      • Tax notes: "Incl. of all taxes", "Inclusive of all taxes", "incl taxes", "(incl. of all taxes)"
      • Suffix: /- (rupee suffix), .00, .50, .95, .99, .25 and other 2-decimal endings
    EXAMPLES:
      "MRP ₹350.00/- (Incl. of all taxes)"  → value=350.00, currency=INR
      "Maximum Retail Price: Rs. 99.50"      → value=99.50, currency=INR
      "₹25/-"                                → value=25.0, currency=INR
    If you see ANY number adjacent to a rupee symbol or MRP label, extract it.
12. MRP currency — almost always INR for Indian products; if unsure, default to "INR"
13. Manufacturing / packing / import date where visible
    DATE PATTERNS: MFD, Mfg, Mfg., Pkd, Pkd., Packed, Dt, followed by MM/YY, MM/YYYY, MMM YYYY (e.g. MAR 2026), or Month Year
14. Best before / use by / expiry date where visible
15. Consumer care name / contact — "Consumer Care", "Customer Care", "For complaints contact:" — combine ALL visible consumer-care information (name, address, phone, email, toll-free) into a single combined consumer_care value preserving exact visible text
16. Email address (if visible) — still extract, but consumer_care is the primary combined contact
17. Phone / mobile / landline / toll-free numbers — still extract, but consumer_care is primary
18. Unit sale price where visible (e.g. "Price per 100g: ₹X")
19. Batch / lot number — Batch No., Lot No., B. No., followed by alphanumeric code
20. Language used — e.g. if declarations clearly in English + Hindi in Devanagari script, note both; else the primary languages detected. Use language_used as the stable key.
21. Other important declarations (FSSAI logo/number, veg/non-veg mark, barcode text, etc.)

For EVERY field return an object with:
- value: the extracted normalised value (string or number as appropriate)
- exact_visible_text: the exact raw text as printed on the package, character-for-character where possible
- confidence: a number between 0 and 1 (0.0 = pure guess, 1.0 = perfectly clear print)
- evidence_description: short sentence describing where on the package you found it

IMPORTANT CONFIDENCE RULES (do NOT skip extraction just because text is imperfect):
- Confidence 0.9–1.0: perfectly clear, large, perfectly-printed black text on white background
- Confidence 0.7–0.9: normal clear label print with minor imperfections
- Confidence 0.4–0.7: small font, slightly blurry, partial occlusion, uneven lighting, slight angle → STILL EXTRACT THE VALUE
- Confidence 0.1–0.3: only a fragment visible, very uncertain
- Confidence 0.0 or null: genuinely nothing visible at all

Return structured JSON only. Use this exact shape:

{
  "product_name": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "common_name": {"value": null, "exact_visible_text": null, "confidence": 0.0, "evidence_description": null},
  "manufacturer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "packer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "importer": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "address": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "dimensions_size": {"value": null, "exact_visible_text": null, "confidence": 0.0, "evidence_description": null},
  "country_of_origin": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "net_quantity": {"value": 0, "unit": "g", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "mrp": {"value": 0, "currency": "INR", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "packing_date": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "best_before": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "consumer_care": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "email": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "phone": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "unit_sale_price": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "batch_number": {"value": "...", "exact_visible_text": "...", "confidence": 0.0, "evidence_description": "..."},
  "language_used": {"value": null, "exact_visible_text": null, "confidence": 0.0, "evidence_description": null},
  "language_of_declarations": {"value": null, "exact_visible_text": null, "confidence": 0.0, "evidence_description": null},
  "other_declarations": [],
  "overall_confidence": 0.0
}

Never invent missing information. If you cannot read a field but can see a fragment, return the fragment with low confidence instead of null.

Do NOT decide whether the product is compliant. That is the rule engine's job.
''';

const List<String> kFallbackModels = [
  'gemini-3.6-flash',
  'gemini-3.5-flash',
  'gemini-3.0-flash',
  'gemini-2.5-flash',
  'gemini-2.0-flash',
  'gemini-1.5-flash',
];

class GeminiVisionException implements Exception {
  final String message;
  final String code;

  GeminiVisionException(this.message, {this.code = 'gemini_error'});

  @override
  String toString() => message;
}

String _sanitizeErrorText(String text) {
  return text.replaceAllMapped(
    RegExp(r'(?i)(api[_-]?key|token)[=:\s]+[^\s,;]+', caseSensitive: false),
    (m) => '${m.group(1)}=[redacted]',
  );
}

final _jsonBraces = RegExp(r'\{[\s\S]*\}', multiLine: false);

Map<String, dynamic> _parseJsonPayload(String text) {
  var cleaned = text.trim();

  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    cleaned = cleaned.trim();
  }

  try {
    final decoded = jsonDecode(cleaned);
    return _coerceToStringDynamicMap(decoded);
  } catch (_) {
    final bracesMatch = _jsonBraces.firstMatch(cleaned);
    if (bracesMatch != null) {
      try {
        final decoded = jsonDecode(bracesMatch.group(0)!);
        return _coerceToStringDynamicMap(decoded);
      } catch (_) {}
    }
    throw GeminiVisionException(
      'Invalid Gemini response. The model did not return valid JSON.',
      code: 'invalid_gemini_response',
    );
  }
}

Map<String, dynamic> _coerceToStringDynamicMap(dynamic decoded) {
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('Not a JSON object');
}

List<String> _modelsToTry(String preferred) {
  final models = <String>[];
  if (preferred.trim().isNotEmpty) models.add(preferred.trim());
  for (final name in kFallbackModels) {
    if (!models.contains(name)) models.add(name);
  }
  return models;
}

double? _coerceNumber(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
  return null;
}

const _kExpectedStringFields = [
  'product_name',
  'common_name',
  'manufacturer',
  'packer',
  'importer',
  'address',
  'dimensions_size',
  'country_of_origin',
  'packing_date',
  'best_before',
  'consumer_care',
  'email',
  'phone',
  'unit_sale_price',
  'batch_number',
  'language_used',
  'language_of_declarations',
];

Map<String, dynamic> _normalizeExtraction(Map<String, dynamic> raw) {
  final Map<String, dynamic> out = Map<String, dynamic>.from(raw);

  Map<String, dynamic> ensureField(dynamic rawField) {
    final map = rawField is Map
        ? Map<String, dynamic>.from(rawField)
        : <String, dynamic>{};
    map.putIfAbsent('value', () => null);
    map.putIfAbsent('exact_visible_text', () => null);
    map.putIfAbsent('confidence', () => 0.0);
    map.putIfAbsent('evidence_description', () => null);
    map.putIfAbsent('source_image_index', () => null);
    final conf = map['confidence'];
    if (conf is! double) {
      map['confidence'] = (conf is num) ? conf.toDouble() : 0.0;
    }
    final si = map['source_image_index'];
    if (si != null && si is! int) {
      map['source_image_index'] = int.tryParse(si.toString());
    }
    return map;
  }

  void hydrateStringField(String key) {
    final field = ensureField(out[key]);
    final val = field['value'];
    if (val == null || (val is String && val.trim().isEmpty)) {
      final visible = field['exact_visible_text'];
      if (visible is String && visible.trim().isNotEmpty) {
        field['value'] = visible.trim();
        if (field['confidence'] == 0.0) field['confidence'] = 0.5;
      }
    }
    out[key] = field;
  }

  for (final key in _kExpectedStringFields) {
    hydrateStringField(key);
  }

  {
    final field = ensureField(out['net_quantity']);
    final rawNum = _coerceNumber(field['value']);
    if (rawNum != null) {
      field['value'] = rawNum;
    } else {
      final visible = field['exact_visible_text'];
      if (visible is String && visible.trim().isNotEmpty) {
        final parsed = _parseNumberFromText(visible);
        if (parsed != null) {
          field['value'] = parsed;
          if (field['unit'] == null || (field['unit'] as String).trim().isEmpty) {
            field['unit'] = _extractUnitFromText(visible);
          }
          if (field['confidence'] == 0.0) field['confidence'] = 0.5;
        }
      }
    }
    if (field['unit'] is! String) {
      field['unit'] = field['unit']?.toString() ?? '';
    }
    out['net_quantity'] = field;
  }

  {
    final field = ensureField(out['mrp']);
    final rawNum = _coerceNumber(field['value']);
    if (rawNum != null) {
      field['value'] = rawNum;
    } else {
      final visible = field['exact_visible_text'];
      if (visible is String && visible.trim().isNotEmpty) {
        final parsed = _parseNumberFromText(visible);
        if (parsed != null) {
          field['value'] = parsed;
          if (field['confidence'] == 0.0) field['confidence'] = 0.5;
        }
      }
    }
    final currency = field['currency'];
    if (currency == null || (currency is String && currency.trim().isEmpty)) {
      field['currency'] = 'INR';
    } else if (currency is! String) {
      field['currency'] = currency.toString();
    }
    out['mrp'] = field;
  }

  if (out['other_declarations'] is! List) {
    final od = out['other_declarations'];
    if (od == null) {
      out['other_declarations'] = <String>[];
    } else {
      out['other_declarations'] = [od.toString()];
    }
  }

  if (out['overall_confidence'] is! num) {
    out['overall_confidence'] = 0.0;
  } else {
    out['overall_confidence'] = (out['overall_confidence'] as num).toDouble();
  }

  return out;
}

final _numberRegex = RegExp(r'(\d+(?:[.,]\d+)?)');

double? _parseNumberFromText(String text) {
  final match = _numberRegex.firstMatch(text.replaceAll(',', '.'));
  if (match == null) return null;
  final token = match.group(1)!;
  return double.tryParse(token);
}

final _unitRegex = RegExp(
  r'(kg|gm|g|gram|grams|kilogram|kilograms|ml|millilitre|millilitres|liter|liters|ltr|l|piece|pieces|pcs|pc|nos|no|count|units?|cm|mm|m)',
  caseSensitive: false,
);

String? _extractUnitFromText(String text) {
  final match = _unitRegex.firstMatch(text);
  if (match == null) return null;
  final raw = match.group(1)!.toLowerCase();
  switch (raw) {
    case 'g':
    case 'gm':
    case 'gram':
    case 'grams':
      return 'g';
    case 'kilogram':
    case 'kilograms':
    case 'kg':
      return 'kg';
    case 'ml':
    case 'millilitre':
    case 'millilitres':
      return 'ml';
    case 'liter':
    case 'liters':
    case 'ltr':
    case 'l':
      return 'L';
    case 'piece':
    case 'pieces':
    case 'pcs':
    case 'pc':
    case 'nos':
    case 'no':
    case 'count':
    case 'unit':
    case 'units':
      return 'pcs';
    default:
      return raw;
  }
}

class _InlineImage {
  final Uint8List bytes;
  final String mimeType;
  final String base64;
  final int index;
  const _InlineImage({
    required this.bytes,
    required this.mimeType,
    required this.base64,
    required this.index,
  });
}

class GeminiVisionService {
  static Future<Map<String, dynamic>> extract({
    required Uint8List imageBytes,
    String? filename,
  }) async {
    return extractMulti(images: [
      (bytes: imageBytes, filename: filename),
    ]);
  }

  static Future<Map<String, dynamic>> extractMulti({
    required List<({Uint8List bytes, String? filename})> images,
  }) async {
    if (images.isEmpty) {
      throw GeminiVisionException(
        'Please add at least one product image.',
        code: 'no_images',
      );
    }

    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.trim().isEmpty) {
      throw GeminiVisionException(
        'Gemini API key is not configured.',
        code: 'invalid_api_key',
      );
    }

    final prepared = <_InlineImage>[];
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      String? mime;
      if (img.filename != null) mime = lookupMimeType(img.filename!);
      mime ??= lookupMimeType('image.jpg', headerBytes: img.bytes);
      mime ??= 'image/jpeg';
      prepared.add(
        _InlineImage(
          bytes: img.bytes,
          mimeType: mime,
          base64: base64Encode(img.bytes),
          index: i + 1,
        ),
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[GeminiVision] images=${prepared.length} '
        'total_bytes=${prepared.fold<int>(0, (s, e) => s + e.bytes.lengthInBytes)}',
      );
    }

    final preferred = AppConfig.geminiModel;
    final models = _modelsToTry(preferred);

    Exception? lastExc;

    for (final model in models) {
      if (kDebugMode) debugPrint('[GeminiVision] trying model=$model');
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$model:generateContent?key=$apiKey';

      final parts = <Map<String, dynamic>>[];
      for (final p in prepared) {
        parts.add({
          'inline_data': {
            'mime_type': p.mimeType,
            'data': p.base64,
          },
        });
      }

      final labels = prepared.map((p) => 'Photo ${p.index}').join(', ');
      final userText = prepared.length == 1
          ? 'You are analyzing 1 product photo (Photo 1). '
              'Extract the visible packaged-commodity label declarations. '
              'SCAN EVERY PART OF THE IMAGE. Highest priority: MRP, net quantity, dates, '
              'manufacturer/packer/importer details, consumer care. Read small fonts carefully. '
              'For every detected field, set source_image_index = 1.'
          : 'You are analyzing multiple images of the SAME packaged commodity. '
              'These images may show different sides or portions of the same package. '
              'The provided images are: $labels. '
              'Combine information across ALL images. Do NOT duplicate information. '
              'If a declaration is visible in ANY image, use it. Do NOT guess information '
              'that is not visible. For every detected field, set source_image_index '
              'to the 1-based photo index (e.g. 1 for Photo 1, 2 for Photo 2) where the '
              'clearest evidence was found. '
              'SCAN EVERY PART OF EVERY IMAGE. Highest priority: MRP, net quantity, dates, '
              'manufacturer/packer/importer details, consumer care. Read small fonts carefully.';

      parts.add({'text': userText});

      final body = <String, dynamic>{
        'system_instruction': {
          'parts': [
            {'text': kSystemPrompt},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': parts,
          },
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.3,
          'top_p': 0.95,
        },
      };

      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          final rawText = _extractRawText(decoded);
          if (kDebugMode) {
            debugPrint(
              '[GeminiVision] model=$model success. raw_text_first_500='
              '${rawText.length > 500 ? rawText.substring(0, 500) : rawText}',
            );
          }
          final parsed = _parseJsonPayload(rawText);
          final normalized = _normalizeExtraction(parsed);
          return normalized;
        }

        final bodyText = _sanitizeErrorText(response.body);
        final lowered = bodyText.toLowerCase();

        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            lowered.contains('api key') ||
            lowered.contains('invalid_api_key')) {
          throw GeminiVisionException(
            'Gemini rejected the credentials. Check GEMINI_API_KEY.',
            code: 'invalid_api_key',
          );
        }

        if (response.statusCode == 429 ||
            lowered.contains('resource exhausted') ||
            lowered.contains('rate limit') ||
            lowered.contains('quota')) {
          throw GeminiVisionException(
            'Gemini rate limit reached. Please try again shortly.',
            code: 'rate_limit',
          );
        }

        final isRetryable = (response.statusCode == 503) ||
            lowered.contains('unavailable') ||
            lowered.contains('high demand') ||
            lowered.contains('try again later') ||
            (response.statusCode == 404 &&
                (lowered.contains('model') ||
                    lowered.contains('no longer available')));

        if (isRetryable) {
          if (kDebugMode) {
            debugPrint(
              '[GeminiVision] model=$model unavailable HTTP ${response.statusCode}, trying next.',
            );
          }
          lastExc = Exception(
            'Model $model unavailable (HTTP ${response.statusCode})',
          );
          continue;
        }

        throw GeminiVisionException(
          'Unable to analyze the image. Underlying: HTTP ${response.statusCode}: $bodyText',
          code: 'gemini_error',
        );
      } on GeminiVisionException {
        rethrow;
      } catch (exc) {
        if (kDebugMode) {
          debugPrint(
            '[GeminiVision] model=$model exception: $exc',
          );
        }
        lastExc = exc is Exception ? exc : Exception(exc.toString());
        continue;
      }
    }

    final msg = lastExc != null
        ? _sanitizeErrorText(lastExc.toString())
        : 'unknown';
    throw GeminiVisionException(
      'All Gemini models are currently unavailable due to high demand '
      '(503 UNAVAILABLE). Wait 1-2 minutes and try again. Last error: $msg',
      code: 'all_models_unavailable',
    );
  }

  static String _extractRawText(dynamic decoded) {
    if (decoded is! Map) return '';

    final promptFeedback = decoded['promptFeedback'];
    if (promptFeedback is Map) {
      final blockReason = promptFeedback['blockReason'];
      if (blockReason != null && blockReason.toString().isNotEmpty) {
        throw GeminiVisionException(
          'Gemini blocked the request. prompt_feedback=$blockReason',
          code: 'content_blocked',
        );
      }
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw GeminiVisionException(
        'Invalid Gemini response. No extraction text was returned. '
        'The model may have returned no candidates or been safety-filtered.',
        code: 'invalid_gemini_response',
      );
    }

    final partsText = <String>[];
    for (final cand in candidates) {
      if (cand is! Map) continue;
      final content = cand['content'];
      if (content is! Map) {
        final finish = cand['finishReason'];
        final feedback = cand['safetyRatings'];
        if (finish != null || feedback != null) {
          if (kDebugMode) {
            debugPrint(
              '[GeminiVision] candidate skipped. finishReason=$finish '
              'safetyRatings=$feedback',
            );
          }
          continue;
        }
        continue;
      }
      final parts = content['parts'];
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is Map) {
          final t = part['text'];
          if (t != null && t.toString().trim().isNotEmpty) {
            partsText.add(t.toString());
          }
        }
      }
    }

    if (partsText.isEmpty) {
      throw GeminiVisionException(
        'Invalid Gemini response. No extraction text was returned. '
        'The model may have returned no candidates or been safety-filtered.',
        code: 'invalid_gemini_response',
      );
    }

    return partsText.join('\n');
  }
}
