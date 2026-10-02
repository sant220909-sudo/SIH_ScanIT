import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/utils/app_theme.dart';

const double kConfidenceReviewThreshold = 0.75;

const String kPrototypeNotice =
    'MVP prototype checks only. These are not a complete Legal Metrology '
    'rule database and must be verified against authoritative current sources.';

const String kDisclaimer =
    'AI-assisted preliminary compliance assessment. Final compliance '
    'determination requires verification against applicable rules and '
    'authorized inspection procedures.';

const Map<String, Map<String, dynamic>> kRuleMaster = {
  'LM-001': {
    'rule_id': 'LM-001',
    'rule_reference': 'Rule 6(1)(b)',
    'field': 'product_name',
    'requirement':
        'Common or generic name of the commodity should be declared on the package.',
    'validation_type': 'presence',
    'severity': 'HIGH',
    'mandatory': true,
    'explanation':
        'Rule 6(1)(b) of the Legal Metrology (Packaged Commodities) Rules '
        'requires that every package clearly mention the common or generic '
        'name by which the commodity is ordinarily known.',
  },
  'LM-002': {
    'rule_id': 'LM-002',
    'rule_reference': 'Rule 6(1)(c)',
    'field': 'manufacturer_party',
    'requirement':
        'Name and address of the manufacturer, packer or importer, as applicable, should be declared on the package.',
    'validation_type': 'presence',
    'severity': 'HIGH',
    'mandatory': true,
    'explanation':
        'Rule 6(1)(c) requires the identity and address of the responsible '
        'person (manufacturer, packer, or importer) so that a consumer or '
        'enforcement authority can trace the source of a packaged commodity.',
  },
  'LM-003': {
    'rule_id': 'LM-003',
    'rule_reference': 'Rule 6(1)(c), Rule 12(1)',
    'field': 'net_quantity',
    'requirement':
        'Net quantity should be declared correctly in the prescribed standard unit of weight, measure or number as applicable.',
    'validation_type': 'presence',
    'severity': 'HIGH',
    'mandatory': true,
    'explanation':
        'Rule 6(1)(c) requires the net quantity; Rule 12(1) prescribes the '
        'manner of declaration and the standard units.',
  },
  'LM-004': {
    'rule_id': 'LM-004',
    'rule_reference': 'Rule 6(1)(e), Rule 12(1), Rule 2(m)',
    'field': 'mrp',
    'requirement':
        'Maximum Retail Price inclusive of all taxes should be declared in the prescribed manner on the package.',
    'validation_type': 'presence',
    'severity': 'HIGH',
    'mandatory': true,
    'explanation':
        'Rule 6(1)(e) mandates the MRP; Rule 12(1) the manner of '
        'declaration; Rule 2(m) of the Legal Metrology Act defines MRP as '
        'the maximum price inclusive of all taxes.',
  },
  'LM-005': {
    'rule_id': 'LM-005',
    'rule_reference': 'Rule 6(1)(d), Rule 2(m)',
    'field': 'packing_date',
    'requirement':
        'Month and year of manufacture, packing or import, as applicable, should be declared on the package.',
    'validation_type': 'presence_if_applicable',
    'severity': 'MEDIUM',
    'mandatory': false,
    'explanation':
        'Rule 6(1)(d) requires the month and year of manufacture or '
        'packing; Rule 2(m) provides the definitional context for '
        'traceability, recall, and freshness assessment.',
  },
  'LM-006': {
    'rule_id': 'LM-006',
    'rule_reference': 'Rule 6(1)(d)',
    'field': 'consumer_care',
    'requirement':
        'Consumer care details such as name, address, telephone number or email should be declared where applicable so that complaints can be registered.',
    'validation_type': 'presence',
    'severity': 'HIGH',
    'mandatory': true,
    'explanation':
        'Rule 6(1)(d) read with the consumer-protection provisions requires '
        'accessible grievance redressal contact information on the package.',
  },
  'LM-007': {
    'rule_id': 'LM-007',
    'rule_reference': 'Rule 6(2)',
    'field': 'country_of_origin',
    'requirement':
        'Country of origin or manufacture should be declared on the package where applicable.',
    'validation_type': 'presence_if_applicable',
    'severity': 'MEDIUM',
    'mandatory': false,
    'explanation':
        'Rule 6(2) requires declaration of the country of origin on '
        'imported packaged commodities as well as domestic cases where '
        'such a declaration is prescribed, enabling informed consumer choice.',
  },
  'LM-008': {
    'rule_id': 'LM-008',
    'rule_reference': 'Rule 9(4)',
    'field': 'language_of_declarations',
    'requirement':
        'All mandatory declarations should be made in Hindi in Devanagari script or English language. Other languages may additionally be used.',
    'validation_type': 'language_presence',
    'severity': 'MEDIUM',
    'mandatory': true,
    'explanation':
        'Rule 9(4) ensures that declarations are made in at least one of '
        'the two nationally understood languages (Hindi in Devanagari '
        'script or English) so that the information is accessible across '
        'the country. NOTE: Uncertain language detection does NOT '
        'automatically imply non-compliance.',
  },
  'LM-009': {
    'rule_id': 'LM-009',
    'rule_reference': 'Rule 12(6)',
    'field': 'quantity_expression',
    'requirement':
        "The declaration of net quantity should not contain misleading words such as 'minimum', 'not less than', 'average', 'about', 'approximately', 'Jumbo', 'Family Size', 'King Size' or any other qualifying/qualifying word when used to replace or distort the actual net quantity declaration itself.",
    'validation_type': 'quantity_expression_prohibited',
    'severity': 'MEDIUM',
    'mandatory': true,
    'explanation':
        'Rule 12(6) of the Legal Metrology (Packaged Commodities) Rules, 2011 prohibits qualifying words around the net-quantity declaration that could suggest a tolerance or overfill where one is not statutorily permitted, protecting consumers from underweight packaged goods. Qualifiers such as "Jumbo Pack", "Family Size", and "King Size" must not replace or distort the actual numeric quantity declaration.',
  },
  'LM-010': {
    'rule_id': 'LM-010',
    'rule_reference': 'Applicable rule to be verified',
    'field': 'batch_number',
    'requirement':
        'Batch, lot or code number should be declared on the package wherever applicable to enable traceability and recall.',
    'validation_type': 'presence_if_applicable',
    'severity': 'MEDIUM',
    'mandatory': false,
    'explanation':
        'Batch/lot numbering is required under various LM/FS/FSSAI '
        'provisions to identify manufacturing runs and allow targeted '
        'recalls. The exact Legal Metrology rule reference is to be '
        'verified against the latest notified text for the specific '
        'commodity class.',
  },
  'LM-011': {
    'rule_id': 'LM-011',
    'rule_reference': 'Applicable rule to be verified',
    'field': 'unit_sale_price',
    'requirement':
        'Unit sale price should be declared on the package wherever applicable per the relevant provisions so that consumers can compare prices on a per-unit basis.',
    'validation_type': 'presence_if_applicable',
    'severity': 'MEDIUM',
    'mandatory': false,
    'explanation':
        'The declaration of a unit sale price (per kg, per 100 g, per L, '
        'per 100 ml, etc.) supports transparent price comparison. The '
        'exact applicable rule reference and commodity thresholds are to '
        'be cross-checked against the current Legal Metrology '
        '(Packaged Commodities) Rules text.',
  },
  'LM-012': {
    'rule_id': 'LM-012',
    'rule_reference': 'Rule 13',
    'field': 'quantity_declaration_unit',
    'requirement':
        'The declaration of net quantity should use the standard units of weight, measure, or number prescribed by Rule 13. Non-standard units such as ounce (oz), pound (lb), quart, tola, etc. should be reviewed against the applicable schedule. Number-based declarations (Dozen, Pack, Case, Piece) are permissible only where appropriate to the commodity.',
    'validation_type': 'non_standard_unit',
    'severity': 'MEDIUM',
    'mandatory': true,
    'explanation':
        'Rule 13 of the Legal Metrology (Packaged Commodities) Rules, 2011 prescribes the manner of declaring the net quantity. Unofficial / traditional units (tola, lb, oz, quart) should be reviewed; number-based declarations by the dozen/piece/case are permitted for appropriate commodities but require inspector confirmation of commodity-appropriateness.',
  },
};

Map<String, dynamic> _asDict(dynamic obj) {
  if (obj == null) return {};
  if (obj is Map<String, dynamic>) return obj;
  if (obj is Map) return Map<String, dynamic>.from(obj);
  return {};
}

String? _getExtractedText(dynamic field) {
  final data = _asDict(field);
  final value = data['value'];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double _getConfidence(dynamic field) {
  final data = _asDict(field);
  try {
    final c = data['confidence'];
    if (c == null) return 0.0;
    return (c as num).toDouble();
  } catch (_) {
    return 0.0;
  }
}

String? _getExactText(dynamic field) {
  final data = _asDict(field);
  final text = data['exact_visible_text'];
  if (text == null) return null;
  final cleaned = text.toString().trim();
  return cleaned.isEmpty ? null : cleaned;
}

String? _getEvidence(dynamic field) {
  final data = _asDict(field);
  final text = data['evidence_description'];
  if (text == null) return null;
  final cleaned = text.toString().trim();
  return cleaned.isEmpty ? null : cleaned;
}

int? _getSourceIndex(dynamic field) {
  final data = _asDict(field);
  final value = data['source_image_index'];
  if (value is int) return value;
  return null;
}

class _PartyResult {
  final String? value;
  final double confidence;
  final String? exactText;
  final String? evidence;
  final int? sourceIndex;
  _PartyResult(
    this.value,
    this.confidence,
    this.exactText,
    this.evidence,
    this.sourceIndex,
  );
}

_PartyResult _manufacturerParty(Map<String, dynamic> extraction) {
  final candidates = [
    extraction['manufacturer'],
    extraction['packer'],
    extraction['importer'],
  ];
  dynamic best;
  for (final item in candidates) {
    if (_getExtractedText(item) != null &&
        (best == null ||
            _getConfidence(item) > _getConfidence(best))) {
      best = item;
    }
  }
  if (best == null) return _PartyResult(null, 0.0, null, null, null);
  return _PartyResult(
    _getExtractedText(best),
    _getConfidence(best),
    _getExactText(best),
    _getEvidence(best),
    _getSourceIndex(best),
  );
}

bool _netQuantityPresent(dynamic field) {
  final data = _asDict(field);
  final value = data['value'];
  final unit = data['unit'];
  final visible = _getExactText(field);
  if (value != null && value.toString().trim().isNotEmpty) return true;
  if (unit != null && unit.toString().trim().isNotEmpty) return true;
  return visible != null && visible.isNotEmpty;
}

bool _mrpPresent(dynamic field) {
  final data = _asDict(field);
  final value = data['value'];
  final visible = _getExactText(field);
  if (value != null && value.toString().trim().isNotEmpty) return true;
  return visible != null && visible.isNotEmpty;
}

String _statusForPresence(
    bool present, double confidence, bool mandatory) {
  if (!present) return mandatory ? 'FAIL' : 'REVIEW';
  if (confidence < kConfidenceReviewThreshold) return 'REVIEW';
  return 'PASS';
}

String _reason(
    String status, String fieldLabel, bool present, double confidence) {
  if (status == 'FAIL') {
    return '$fieldLabel was not detected on the package in any of the '
        'provided photos.';
  }
  if (status == 'REVIEW') {
    if (!present) {
      return '$fieldLabel was not clearly visible in any provided photo '
          'and needs human verification.';
    }
    return '$fieldLabel was detected with low/uncertain confidence '
        '(${confidence.toStringAsFixed(2)}) and needs human verification.';
  }
  return '$fieldLabel detected with sufficient confidence '
      '(${confidence.toStringAsFixed(2)}).';
}

final RegExp _englishLetters = RegExp(r'[a-zA-Z]{3,}');
final RegExp _devanagari = RegExp(r'[\u0900-\u097F]+');
final RegExp _misleadingQuantityPhrase = RegExp(
  r'\b(minimum|not\s+less\s+than|average|about|approximately)\b',
  caseSensitive: false,
);
final RegExp _promotionalSizePhrase = RegExp(
  r'\b(jumbo|family\s*size|king\s*size)\b',
  caseSensitive: false,
);
final RegExp _nonStandardUnitPhrase = RegExp(
  r'\b(ounce|oz|pound|lb|lbs|quart|tola|tole|sèr|ser)\b',
  caseSensitive: false,
);
final RegExp _numberQuantityPhrase = RegExp(
  r'\b(dozen|pack|case|piece|pcs|pc|count|nos)\b',
  caseSensitive: false,
);

class ComplianceCheckResult {
  final String ruleId;
  final String ruleReference;
  final String field;
  final String requirement;
  final String status;
  final String reason;
  final double confidence;
  final String severity;
  final bool mandatory;
  final String? explanation;
  final String? exactVisibleText;
  final String? evidenceDescription;
  final int? sourceImageIndex;

  ComplianceCheckResult({
    required this.ruleId,
    required this.ruleReference,
    required this.field,
    required this.requirement,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.severity,
    required this.mandatory,
    required this.explanation,
    this.exactVisibleText,
    this.evidenceDescription,
    this.sourceImageIndex,
  });

  Map<String, dynamic> toJson() => {
        'rule_id': ruleId,
        'rule_reference': ruleReference,
        'field': field,
        'requirement': requirement,
        'status': status,
        'reason': reason,
        'confidence': confidence,
        'severity': severity,
        'mandatory': mandatory,
        'explanation': explanation,
        'exact_visible_text': exactVisibleText,
        'evidence_description': evidenceDescription,
        'source_image_index': sourceImageIndex,
      };
}

class ComplianceSummary {
  final int passed;
  final int failed;
  final int review;

  ComplianceSummary({
    required this.passed,
    required this.failed,
    required this.review,
  });

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'failed': failed,
        'review': review,
      };
}

class RuleEngineEvaluation {
  final Map<String, dynamic> extraction;
  final List<ComplianceCheckResult> checks;
  final ComplianceSummary summary;
  final String overallStatus;
  final String disclaimer;
  final String prototypeNotice;

  RuleEngineEvaluation({
    required this.extraction,
    required this.checks,
    required this.summary,
    required this.overallStatus,
    required this.disclaimer,
    required this.prototypeNotice,
  });

  Map<String, dynamic> toApiPayload(String inspectionId) => {
        'inspection_id': inspectionId,
        'extraction': extraction,
        'checks': checks.map((c) => c.toJson()).toList(),
        'summary': summary.toJson(),
        'overall_status': overallStatus,
        'disclaimer': disclaimer,
        'prototype_notice': prototypeNotice,
      };
}

class _LanguageResult {
  final bool english;
  final bool hindi;
  final double confidence;
  final String valueLabel;
  _LanguageResult(this.english, this.hindi, this.confidence, this.valueLabel);
}

_LanguageResult _detectLanguages(Map<String, dynamic> extraction) {
  final buf = StringBuffer();
  void append(dynamic field) {
    final exact = _getExactText(field);
    if (exact != null) {
      buf.write(' ');
      buf.write(exact);
    }
    final value = _getExtractedText(field);
    if (value != null) {
      buf.write(' ');
      buf.write(value);
    }
    final ev = _getEvidence(field);
    if (ev != null) {
      buf.write(' ');
      buf.write(ev);
    }
  }

  for (final key in const [
    'product_name',
    'manufacturer',
    'packer',
    'importer',
    'address',
    'country_of_origin',
    'packing_date',
    'best_before',
    'consumer_care',
    'batch_number',
    'unit_sale_price',
  ]) {
    append(extraction[key]);
  }
  final other = extraction['other_declarations'];
  if (other is List) {
    for (final item in other) {
      buf.write(' ');
      buf.write(item.toString());
    }
  }
  final haystack = buf.toString();
  final engMatch = _englishLetters.hasMatch(haystack);
  final hindiMatch = _devanagari.hasMatch(haystack);

  double conf = 0.0;
  if (engMatch) conf += 0.5;
  if (hindiMatch) conf += 0.5;

  String label;
  if (engMatch && hindiMatch) {
    label = 'English + Hindi (Devanagari)';
  } else if (engMatch) {
    label = 'English';
  } else if (hindiMatch) {
    label = 'Hindi (Devanagari)';
  } else {
    label = 'Not detected';
  }
  return _LanguageResult(engMatch, hindiMatch, conf, label);
}

class RuleEngine {
  static RuleEngineEvaluation evaluateExtraction(
    Map<String, dynamic> extraction,
    String inspectionId,
  ) {
    final party = _manufacturerParty(extraction);
    final netQty = extraction['net_quantity'];
    final mrp = extraction['mrp'];

    final Map<String, dynamic> fieldMap = {
      'product_name': extraction['product_name'],
      'manufacturer_party': {
        'value': party.value,
        'confidence': party.confidence,
        'exact_visible_text': party.exactText,
        'evidence_description': party.evidence,
        'source_image_index': party.sourceIndex,
      },
      'net_quantity': netQty,
      'mrp': mrp,
      'consumer_care': extraction['consumer_care'],
      'country_of_origin': extraction['country_of_origin'],
      'packing_date': extraction['packing_date'],
      'unit_sale_price': extraction['unit_sale_price'],
      'batch_number': extraction['batch_number'],
    };

    final lang = _detectLanguages(extraction);
    final langField = extraction['language_of_declarations'] ??= <String, dynamic>{};
    if (langField is Map) {
      final map = Map<String, dynamic>.from(langField);
      if (map['value'] == null ||
          (map['value'] is String && map['value'].trim().isEmpty)) {
        map['value'] = lang.valueLabel;
      }
      final curConf = map['confidence'];
      if (curConf == null ||
          (curConf is num && curConf.toDouble() < lang.confidence)) {
        map['confidence'] = lang.confidence;
      }
      map['exact_visible_text'] = lang.valueLabel;
      map['evidence_description'] =
          'Declared-language heuristic: English=${lang.english}, Hindi(Devanagari)=${lang.hindi} based on visible text of all declarations.';
      extraction['language_of_declarations'] = map;
    }

    final checks = <ComplianceCheckResult>[];
    kRuleMaster.forEach((ruleId, rule) {
      final fieldKey = rule['field'] as String;
      final validationType = rule['validation_type'] as String;
      final mandatory = rule['mandatory'] == true;
      final severity = rule['severity'] as String? ?? 'MEDIUM';
      final explanation = rule['explanation'] as String?;
      final ruleRef = rule['rule_reference'] as String;
      final requirement = rule['requirement'] as String;
      final reqLabel =
          requirement.split(new RegExp(r'[.,]'))[0].trim();

      if (validationType == 'language_presence') {
        final anyDetected = lang.english || lang.hindi;
        final status = anyDetected ? 'PASS' : 'REVIEW';
        final reason = status == 'PASS'
            ? 'At least one of English or Hindi (Devanagari script) detected with sufficient confidence.'
            : 'Neither English nor Hindi (Devanagari script) could be '
                'reliably detected from the visible text. Please verify the '
                'language of declarations manually. NOTE: OCR uncertainty '
                'alone is NOT a finding of non-compliance.';
        checks.add(ComplianceCheckResult(
          ruleId: ruleId,
          ruleReference: ruleRef,
          field: fieldKey,
          requirement: requirement,
          status: status,
          reason: reason,
          confidence: lang.confidence,
          severity: severity,
          mandatory: mandatory,
          explanation: explanation,
          evidenceDescription: lang.valueLabel,
          exactVisibleText: lang.valueLabel,
        ));
        return;
      }

      if (validationType == 'quantity_expression_prohibited') {
        final exactVisibleField =
            _getExactText(netQty)?.toLowerCase() ?? '';
        final evidenceField =
            _getEvidence(netQty)?.toLowerCase() ?? '';
        final other = extraction['other_declarations'];
        final otherBuf = StringBuffer();
        if (other is List) {
          for (final item in other) {
            otherBuf.write(' ${item.toString().toLowerCase()}');
          }
        }
        final otherText = otherBuf.toString();

        final prohibitedInQty =
            _misleadingQuantityPhrase.hasMatch(exactVisibleField) ||
                _misleadingQuantityPhrase.hasMatch(evidenceField);
        final prohibitedElsewhere = !prohibitedInQty &&
            _misleadingQuantityPhrase.hasMatch(otherText);

        final promoInQty =
            _promotionalSizePhrase.hasMatch(exactVisibleField) ||
                _promotionalSizePhrase.hasMatch(evidenceField);
        final promoElsewhere = !promoInQty &&
            _promotionalSizePhrase.hasMatch(otherText);

        final qtyNumericMissing = !_netQuantityPresent(netQty);

        String status;
        String reason;
        double conf;
        String? matchText;
        bool exactMatchInQty = false;

        if (prohibitedInQty) {
          status = 'FAIL';
          final m = _misleadingQuantityPhrase
              .firstMatch(exactVisibleField.isEmpty ? evidenceField : exactVisibleField)
              ?.group(0);
          matchText = m ?? 'qualifier';
          reason = 'Potentially misleading quantity qualifier "$matchText" was '
              'detected inside or adjacent to the net quantity declaration text. Per Rule '
              '12(6) the net quantity itself should not use words such as '
              '"minimum", "not less than", "average", "about" or '
              '"approximately". Please verify context with the inspector.';
          conf = 0.8;
          exactMatchInQty = true;
        } else if (promoInQty && qtyNumericMissing) {
          status = 'REVIEW';
          final m = _promotionalSizePhrase
              .firstMatch(exactVisibleField.isEmpty ? evidenceField : exactVisibleField)
              ?.group(0);
          matchText = m ?? 'promo size';
          reason = 'Promotional size expression "$matchText" appears in or near '
              'the quantity declaration area AND a distinct numeric/standard-unit '
              'net quantity declaration was not clearly detected. Per Rule 12(6), '
              'marketing qualifiers must not replace the statutory quantity '
              'declaration. Inspector review is required.';
          conf = 0.7;
          exactMatchInQty = true;
        } else if (promoInQty) {
          status = 'REVIEW';
          final m = _promotionalSizePhrase
              .firstMatch(exactVisibleField.isEmpty ? evidenceField : exactVisibleField)
              ?.group(0);
          matchText = m ?? 'promo size';
          reason = 'Promotional qualifier "$matchText" was detected near the net '
              'quantity declaration. A numeric quantity declaration IS present, '
              'so this is informational and not an automatic Rule 12(6) '
              'violation. Verify that the marketing phrase does not distort '
              'the declared quantity.';
          conf = 0.55;
          exactMatchInQty = true;
        } else if (prohibitedElsewhere) {
          status = 'REVIEW';
          final m = _misleadingQuantityPhrase.firstMatch(otherText)?.group(0);
          matchText = m ?? 'qualifier';
          reason = 'A potentially misleading quantity qualifier "$matchText" was '
              'detected elsewhere on the package (outside the net quantity '
              'declaration, e.g. "about 10 servings"). This does NOT '
              'automatically indicate a Rule 12(6) violation. Human review '
              'of context is required.';
          conf = 0.45;
        } else if (promoElsewhere) {
          status = 'REVIEW';
          final m = _promotionalSizePhrase.firstMatch(otherText)?.group(0);
          matchText = m ?? 'promo size';
          reason = 'Promotional size expression "$matchText" was detected on the '
              'package outside the quantity declaration (e.g. branding area). '
              'This is informational only and NOT a Rule 12(6) violation by '
              'itself. Confirm that the phrase does not compete with or '
              'contradict the actual quantity declaration.';
          conf = 0.35;
        } else {
          status = 'PASS';
          reason =
              'No prohibited qualifying words were detected in the net '
              'quantity declaration. Promotional qualifiers (if any) were '
              'not found adjacent to the statutory quantity field.';
          conf = 0.85;
        }
        checks.add(ComplianceCheckResult(
          ruleId: ruleId,
          ruleReference: ruleRef,
          field: fieldKey,
          requirement: requirement,
          status: status,
          reason: reason,
          confidence: conf,
          severity: severity,
          mandatory: mandatory,
          explanation: explanation,
          exactVisibleText: exactMatchInQty
              ? (exactVisibleField.isEmpty ? null : exactVisibleField)
              : null,
          evidenceDescription: reason,
        ));
        return;
      }

      if (validationType == 'non_standard_unit') {
        final exactVisibleField =
            _getExactText(netQty)?.toLowerCase() ?? '';
        final valueField = _getExtractedText(netQty)?.toLowerCase() ?? '';
        final evidenceField =
            _getEvidence(netQty)?.toLowerCase() ?? '';
        final unitField = _asDict(netQty)['unit']?.toString().toLowerCase() ?? '';
        final other = extraction['other_declarations'];
        final otherBuf = StringBuffer();
        if (other is List) {
          for (final item in other) {
            otherBuf.write(' ${item.toString().toLowerCase()}');
          }
        }
        final otherText = otherBuf.toString();

        final qtyCombined = [
          exactVisibleField,
          valueField,
          evidenceField,
          unitField,
        ].join(' ');

        final hasNonStandardInQty =
            _nonStandardUnitPhrase.hasMatch(qtyCombined);
        final hasNonStandardElsewhere = !hasNonStandardInQty &&
            _nonStandardUnitPhrase.hasMatch(otherText);

        final hasNumberQtyInDeclaration =
            _numberQuantityPhrase.hasMatch(qtyCombined);
        final hasStandardWeightOrMeasure =
            RegExp(r'\b(g|kg|gm|gram|grams|mg|l|ml|litre|liter|litres|metre|meter|m|cm|mm)\b',
                    caseSensitive: false)
                .hasMatch(qtyCombined);

        String status;
        String reason;
        double conf;
        String? exactOut;

        if (hasNonStandardInQty) {
          status = 'REVIEW';
          final m =
              _nonStandardUnitPhrase.firstMatch(qtyCombined)?.group(0) ??
                  'non-standard unit';
          reason = 'A non-standard or tradition-based unit ("$m") was detected '
              'within or adjacent to the declared net quantity. Per Rule 13, '
              'the declaration shall use the standard units of weight, measure, '
              'or number prescribed by the Rules. Inspector to verify whether '
              'the unit is permissible for this commodity class and whether a '
              'standard-unit equivalent is also present.';
          conf = 0.75;
          exactOut = exactVisibleField.isEmpty ? null : exactVisibleField;
        } else if (hasNumberQtyInDeclaration && !hasStandardWeightOrMeasure) {
          status = 'REVIEW';
          final m = _numberQuantityPhrase
                  .firstMatch(qtyCombined)
                  ?.group(0) ??
              'number-based declaration';
          reason = 'The quantity declaration appears to be number-based ("$m") '
              'without a standard weight/measure unit. Per Rule 13, declaration '
              'by number is permissible only for the commodities to which the '
              'relevant schedule applies. Inspector to confirm commodity '
              'class-eligibility and whether a weight/measure declaration was '
              'also expected.';
          conf = 0.6;
          exactOut = exactVisibleField.isEmpty ? null : exactVisibleField;
        } else if (hasNonStandardElsewhere) {
          status = 'PASS';
          final m = _nonStandardUnitPhrase.firstMatch(otherText)?.group(0) ??
              'unit mention';
          reason = 'A potentially non-standard unit ("$m") was mentioned '
              'elsewhere on the package but NOT within the net quantity '
              'declaration itself. Rule 13 governs the declared quantity; '
              'informational mentions elsewhere are not a violation by '
              'themselves.';
          conf = 0.8;
        } else if (!_netQuantityPresent(netQty)) {
          status = 'PASS';
          reason = 'Net quantity was not clearly detected; non-standard-unit '
              'check is skipped for this rule pass. Presence/adequacy of the '
              'quantity declaration is addressed by the separate LM-003 check.';
          conf = 0.5;
        } else {
          status = 'PASS';
          reason = 'The declared net quantity appears to use a standard unit '
              '(weight, measure, or number) consistent with Rule 13. '
              'Inspector to confirm commodity-class appropriateness at final '
              'verification.';
          conf = 0.85;
        }
        checks.add(ComplianceCheckResult(
          ruleId: ruleId,
          ruleReference: ruleRef,
          field: fieldKey,
          requirement: requirement,
          status: status,
          reason: reason,
          confidence: conf,
          severity: severity,
          mandatory: mandatory,
          explanation: explanation,
          exactVisibleText: exactOut,
          evidenceDescription: reason,
        ));
        return;
      }

      final field = fieldMap[fieldKey];
      final confidence = _getConfidence(field);
      final exact = _getExactText(field);
      final evidence = _getEvidence(field);
      final sourceIdx = _getSourceIndex(field);

      bool present;
      if (fieldKey == 'net_quantity') {
        present = _netQuantityPresent(field);
      } else if (fieldKey == 'mrp') {
        present = _mrpPresent(field);
      } else {
        present = _getExtractedText(field) != null;
      }

      final status = _statusForPresence(present, confidence, mandatory);
      final reason = _reason(status, reqLabel, present, confidence);

      checks.add(ComplianceCheckResult(
        ruleId: ruleId,
        ruleReference: ruleRef,
        field: fieldKey,
        requirement: requirement,
        status: status,
        reason: reason,
        confidence: confidence,
        severity: severity,
        mandatory: mandatory,
        explanation: explanation,
        exactVisibleText: exact,
        evidenceDescription: evidence,
        sourceImageIndex: sourceIdx,
      ));
    });

    final passed = checks.where((c) => c.status == 'PASS').length;
    final failed = checks.where((c) => c.status == 'FAIL').length;
    final review = checks.where((c) => c.status == 'REVIEW').length;

    String overall;
    final hasMandatoryFail = checks.any(
      (c) => c.status == 'FAIL' && c.mandatory,
    );
    if (hasMandatoryFail) {
      overall = 'NON_COMPLIANT';
    } else if (review > 0 || failed > 0) {
      overall = 'MANUAL_REVIEW';
    } else {
      overall = 'COMPLIANT';
    }

    return RuleEngineEvaluation(
      extraction: extraction,
      checks: checks,
      summary: ComplianceSummary(passed: passed, failed: failed, review: review),
      overallStatus: overall,
      disclaimer: kDisclaimer,
      prototypeNotice: kPrototypeNotice,
    );
  }
}
