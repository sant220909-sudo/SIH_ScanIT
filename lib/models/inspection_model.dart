import 'dart:convert';
import 'dart:typed_data';

import 'package:cyber_nova/utils/app_theme.dart';

enum ScanSource { camera, gallery }

class ProductImage {
  final Uint8List bytes;
  final String filename;
  final ScanSource source;
  final int index;

  ProductImage({
    required this.bytes,
    required this.filename,
    required this.source,
    required this.index,
  });

  String get label => 'Photo $index';
}

class ExtractedField {
  final String id;
  final String fieldName;
  String value;
  final double confidence;
  final String? exactVisibleText;
  final String? evidenceDescription;
  final int? sourceImageIndex;
  final String? sourceImageLabel;
  final bool isManuallyEdited;

  ExtractedField({
    required this.id,
    required this.fieldName,
    required this.value,
    required this.confidence,
    this.exactVisibleText,
    this.evidenceDescription,
    this.sourceImageIndex,
    this.sourceImageLabel,
    this.isManuallyEdited = false,
  });

  ExtractedField copyWith({
    String? value,
    bool? isManuallyEdited,
  }) {
    return ExtractedField(
      id: id,
      fieldName: fieldName,
      value: value ?? this.value,
      confidence: confidence,
      exactVisibleText: exactVisibleText,
      evidenceDescription: evidenceDescription,
      sourceImageIndex: sourceImageIndex,
      sourceImageLabel: sourceImageLabel,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
    );
  }
}

class ComplianceCheck {
  final String id;
  final String ruleName;
  final String description;
  final String ruleReference;
  final String field;
  final bool mandatory;
  final double confidence;
  final String? exactVisibleText;
  final String? evidenceDescription;
  final String? explanation;
  final int? sourceImageIndex;
  final String? sourceImageLabel;
  String reason;
  ComplianceStatus status;
  bool isChecked;
  bool inspectorReviewed;

  ComplianceCheck({
    required this.id,
    required this.ruleName,
    required this.description,
    required this.status,
    this.ruleReference = '',
    this.field = '',
    this.mandatory = true,
    this.confidence = 0,
    this.exactVisibleText,
    this.evidenceDescription,
    this.explanation,
    this.sourceImageIndex,
    this.sourceImageLabel,
    this.reason = '',
    this.isChecked = true,
    this.inspectorReviewed = false,
  });

  ComplianceCheck copyWith({
    ComplianceStatus? status,
    bool? isChecked,
    String? reason,
    bool? inspectorReviewed,
  }) {
    return ComplianceCheck(
      id: id,
      ruleName: ruleName,
      description: description,
      ruleReference: ruleReference,
      field: field,
      mandatory: mandatory,
      confidence: confidence,
      exactVisibleText: exactVisibleText,
      evidenceDescription: evidenceDescription,
      explanation: explanation,
      sourceImageIndex: sourceImageIndex,
      sourceImageLabel: sourceImageLabel,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      isChecked: isChecked ?? this.isChecked,
      inspectorReviewed: inspectorReviewed ?? this.inspectorReviewed,
    );
  }
}

class Violation {
  final String id;
  final String title;
  final String requirement;
  final String status;
  final String evidenceNote;
  final String? ruleReference;
  final String? sourceImageLabel;

  Violation({
    required this.id,
    required this.title,
    required this.requirement,
    required this.status,
    required this.evidenceNote,
    this.ruleReference,
    this.sourceImageLabel,
  });
}

class ProductInfo {
  String productName;
  String commonName;
  String manufacturer;
  String packer;
  String importer;
  String address;
  String netQuantity;
  String unit;
  String mrp;
  String currency;
  String packingDate;
  String bestBefore;
  String consumerCare;
  String countryOfOrigin;
  String batchNumber;
  String unitSalePrice;
  String dimensionsSize;
  String languageOfDeclarations;
  String languageUsed;
  String email;
  String phone;

  ProductInfo({
    required this.productName,
    required this.manufacturer,
    required this.address,
    required this.netQuantity,
    required this.mrp,
    required this.packingDate,
    required this.consumerCare,
    required this.countryOfOrigin,
    this.commonName = '',
    this.packer = '',
    this.importer = '',
    this.bestBefore = '',
    this.currency = '',
    this.unit = '',
    this.batchNumber = '',
    this.unitSalePrice = '',
    this.dimensionsSize = '',
    this.languageOfDeclarations = '',
    this.languageUsed = '',
    this.email = '',
    this.phone = '',
  });
}

class InspectionModel {
  final String reportId;
  final DateTime inspectionDate;
  final String productImageUrl;
  final List<ProductImage> productImages;
  bool useSampleAsset;
  bool sampleAssetMissing;
  ProductInfo productInfo;
  List<ExtractedField> extractedFields;
  List<ComplianceCheck> complianceChecks;
  List<Violation> violations;
  bool aiAnalysisComplete;
  bool manualVerificationComplete;
  String backendOverallStatus;
  String disclaimer;
  String prototypeNotice;
  String? misleadingQuantityFindings;
  String? nonStandardUnitFindings;

  Uint8List? get imageBytes =>
      productImages.isNotEmpty ? productImages.first.bytes : null;

  int get imageCount => productImages.length;

  List<Uint8List?>? get allImages => productImages.isEmpty
      ? null
      : productImages.map((pi) => pi.bytes).toList();

  InspectionModel({
    required this.reportId,
    required this.inspectionDate,
    required this.productImageUrl,
    required this.productInfo,
    required this.extractedFields,
    required this.complianceChecks,
    required this.violations,
    List<ProductImage>? productImages,
    Uint8List? legacyImageBytes,
    this.useSampleAsset = false,
    this.sampleAssetMissing = false,
    this.aiAnalysisComplete = false,
    this.manualVerificationComplete = false,
    this.backendOverallStatus = '',
    this.disclaimer = '',
    this.prototypeNotice = '',
    this.misleadingQuantityFindings,
    this.nonStandardUnitFindings,
  }) : productImages = productImages ??
            (legacyImageBytes != null
                ? [
                    ProductImage(
                      bytes: legacyImageBytes,
                      filename: 'product_image.jpg',
                      source: ScanSource.gallery,
                      index: 1,
                    ),
                  ]
                : const []);

  factory InspectionModel.empty({
    List<ProductImage>? productImages,
    Uint8List? imageBytes,
    bool useSampleAsset = false,
    bool sampleAssetMissing = false,
  }) {
    return InspectionModel(
      reportId: 'CN-PENDING',
      inspectionDate: DateTime.now(),
      productImageUrl: '',
      productImages: productImages,
      legacyImageBytes: imageBytes,
      useSampleAsset: useSampleAsset,
      sampleAssetMissing: sampleAssetMissing,
      productInfo: ProductInfo(
        productName: '',
        manufacturer: '',
        address: '',
        netQuantity: '',
        mrp: '',
        packingDate: '',
        consumerCare: '',
        countryOfOrigin: '',
      ),
      extractedFields: const [],
      complianceChecks: const [],
      violations: const [],
    );
  }

  factory InspectionModel.fromApi(
    Map<String, dynamic> json, {
    List<ProductImage>? productImages,
    Uint8List? imageBytes,
    bool useSampleAsset = false,
  }) {
    final extraction = Map<String, dynamic>.from(
      json['extraction'] as Map? ?? {},
    );
    final fields = _fieldsFromExtraction(extraction);
    final product = _productFromFields(fields);
    final checks = _checksFromApi(json['checks']);
    final violations = checks
        .where((c) =>
            c.status == ComplianceStatus.fail ||
            c.status == ComplianceStatus.review)
        .map(
          (c) => Violation(
            id: c.id,
            title: c.ruleName,
            requirement: c.description,
            status: c.status == ComplianceStatus.fail
                ? 'NON-COMPLIANT'
                : 'REVIEW',
            evidenceNote: _evidenceLine(c),
            ruleReference:
                c.ruleReference.isEmpty ? null : c.ruleReference,
            sourceImageLabel: c.sourceImageLabel,
          ),
        )
        .toList();

    return InspectionModel(
      reportId: (json['inspection_id'] as String?) ?? 'CN-UNKNOWN',
      inspectionDate: DateTime.now(),
      productImageUrl: '',
      productImages: productImages,
      legacyImageBytes: imageBytes,
      useSampleAsset: useSampleAsset,
      productInfo: product,
      extractedFields: fields,
      complianceChecks: checks,
      violations: violations,
      aiAnalysisComplete: true,
      backendOverallStatus: (json['overall_status'] as String?) ?? '',
      disclaimer: (json['disclaimer'] as String?) ?? '',
      prototypeNotice: (json['prototype_notice'] as String?) ?? '',
    );
  }

  factory InspectionModel.fromBackendJson(
    Map<String, dynamic> json,
  ) {
    final full = json['full'] as Map<String, dynamic>? ??
        json['full_json'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final String reportId =
        (json['report_id'] as String?) ??
        (full['reportId'] as String?) ??
        'CN-UNKNOWN';
    final String overallStatus =
        (json['overall_status'] as String?) ??
        (full['backendOverallStatus'] as String?) ??
        '';
    final String inspDateStr =
        (json['inspection_date'] as String?) ??
        (full['inspectionDate'] as String?) ??
        '';
    final inspDate = DateTime.tryParse(inspDateStr) ?? DateTime.now();
    Uint8List? imageBytes;
    final imgB64 = json['image_bytes_base64'] as String?;
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imgB64);
      } catch (_) {
        imageBytes = null;
      }
    }
    final productName =
        (json['product_name'] as String?) ??
        (full['productInfo'] is Map ? (((full['productInfo'] as Map)['productName'] as String?) ?? '') : '');
    final decoded = full;
    return InspectionModel.fromJsonDb(
      decoded,
      fallbackProductName: productName,
      fallbackImageBytes: imageBytes,
      fallbackOverall: overallStatus,
    ).copyWith(
      reportId: reportId,
      inspectionDate: inspDate,
      backendOverallStatus: overallStatus,
    );
  }

  InspectionModel copyWith({
    String? reportId,
    DateTime? inspectionDate,
    ProductInfo? productInfo,
    List<ExtractedField>? extractedFields,
    List<ComplianceCheck>? complianceChecks,
    List<Violation>? violations,
    List<ProductImage>? productImages,
    bool? aiAnalysisComplete,
    bool? manualVerificationComplete,
    String? backendOverallStatus,
    String? disclaimer,
    String? prototypeNotice,
    String? misleadingQuantityFindings,
    String? nonStandardUnitFindings,
  }) {
    return InspectionModel(
      reportId: reportId ?? this.reportId,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      productImageUrl: productImageUrl,
      productInfo: productInfo ?? this.productInfo,
      extractedFields: extractedFields ?? this.extractedFields,
      complianceChecks: complianceChecks ?? this.complianceChecks,
      violations: violations ?? this.violations,
      productImages: productImages ?? this.productImages,
      useSampleAsset: useSampleAsset,
      sampleAssetMissing: sampleAssetMissing,
      aiAnalysisComplete: aiAnalysisComplete ?? this.aiAnalysisComplete,
      manualVerificationComplete: manualVerificationComplete ?? this.manualVerificationComplete,
      backendOverallStatus: backendOverallStatus ?? this.backendOverallStatus,
      disclaimer: disclaimer ?? this.disclaimer,
      prototypeNotice: prototypeNotice ?? this.prototypeNotice,
      misleadingQuantityFindings: misleadingQuantityFindings ?? this.misleadingQuantityFindings,
      nonStandardUnitFindings: nonStandardUnitFindings ?? this.nonStandardUnitFindings,
    );
  }

  Map<String, dynamic> toJsonForBackend() {
    final summary = <String, dynamic>{
      'passed': passedCount,
      'failed': failedCount,
      'review': reviewCount,
      'overall': backendOverallStatus.isEmpty ? overallStatusLabel : backendOverallStatus,
    };
    final productInfoMap = <String, dynamic>{
      'productName': productInfo.productName,
      'commonName': productInfo.commonName,
      'manufacturer': productInfo.manufacturer,
      'packer': productInfo.packer,
      'importer': productInfo.importer,
      'address': productInfo.address,
      'netQuantity': productInfo.netQuantity,
      'unit': productInfo.unit,
      'mrp': productInfo.mrp,
      'currency': productInfo.currency,
      'packingDate': productInfo.packingDate,
      'bestBefore': productInfo.bestBefore,
      'consumerCare': productInfo.consumerCare,
      'countryOfOrigin': productInfo.countryOfOrigin,
      'batchNumber': productInfo.batchNumber,
      'unitSalePrice': productInfo.unitSalePrice,
      'dimensionsSize': productInfo.dimensionsSize,
      'languageOfDeclarations': productInfo.languageOfDeclarations,
      'languageUsed': productInfo.languageUsed,
      'email': productInfo.email,
      'phone': productInfo.phone,
    };
    final full = <String, dynamic>{
      'reportId': reportId,
      'inspectionDate': inspectionDate.toIso8601String(),
      'productInfo': productInfoMap,
      'extractedFields': extractedFields
          .map((f) => {
                'id': f.id,
                'fieldName': f.fieldName,
                'value': f.value,
                'confidence': f.confidence,
                'exactVisibleText': f.exactVisibleText,
                'evidenceDescription': f.evidenceDescription,
              })
          .toList(),
      'complianceChecks': complianceChecks
          .map((c) => {
                'id': c.id,
                'ruleName': c.ruleName,
                'description': c.description,
                'ruleReference': c.ruleReference,
                'field': c.field,
                'mandatory': c.mandatory,
                'confidence': c.confidence,
                'exactVisibleText': c.exactVisibleText,
                'evidenceDescription': c.evidenceDescription,
                'reason': c.reason,
                'status': c.status.name,
                'isChecked': c.isChecked,
              })
          .toList(),
      'violations': violations
          .map((v) => {
                'id': v.id,
                'title': v.title,
                'requirement': v.requirement,
                'status': v.status,
                'evidenceNote': v.evidenceNote,
              })
          .toList(),
      'backendOverallStatus': backendOverallStatus,
      'disclaimer': disclaimer,
      'prototypeNotice': prototypeNotice,
      'aiAnalysisComplete': aiAnalysisComplete,
      'manualVerificationComplete': manualVerificationComplete,
      'misleadingQuantityFindings': misleadingQuantityFindings,
      'nonStandardUnitFindings': nonStandardUnitFindings,
    };
    return <String, dynamic>{
      'report_id': reportId,
      'product_name': productInfo.productName.isEmpty
          ? '(unnamed product)'
          : productInfo.productName,
      'overall_status': backendOverallStatus.isEmpty
          ? overallStatusLabel
          : backendOverallStatus,
      'inspection_date': inspectionDate.toIso8601String(),
      'summary': summary,
      'full': full,
      'image_count': imageCount,
    };
  }

  factory InspectionModel.fromJsonDb(
    Map<String, dynamic> json, {
    required String fallbackProductName,
    Uint8List? fallbackImageBytes,
    String fallbackOverall = 'MANUAL_REVIEW',
  }) {
    final productInfoJson = json['productInfo'] as Map<String, dynamic>? ?? {};
    final productInfo = ProductInfo(
      productName: (productInfoJson['productName'] as String?) ??
          fallbackProductName,
      commonName: (productInfoJson['commonName'] as String?) ?? '',
      manufacturer: (productInfoJson['manufacturer'] as String?) ?? '',
      packer: (productInfoJson['packer'] as String?) ?? '',
      importer: (productInfoJson['importer'] as String?) ?? '',
      address: (productInfoJson['address'] as String?) ?? '',
      netQuantity: (productInfoJson['netQuantity'] as String?) ?? '',
      unit: (productInfoJson['unit'] as String?) ?? '',
      mrp: (productInfoJson['mrp'] as String?) ?? '',
      currency: (productInfoJson['currency'] as String?) ?? '',
      packingDate: (productInfoJson['packingDate'] as String?) ?? '',
      bestBefore: (productInfoJson['bestBefore'] as String?) ?? '',
      consumerCare: (productInfoJson['consumerCare'] as String?) ?? '',
      email: (productInfoJson['email'] as String?) ?? '',
      phone: (productInfoJson['phone'] as String?) ?? '',
      countryOfOrigin: (productInfoJson['countryOfOrigin'] as String?) ?? '',
      batchNumber: (productInfoJson['batchNumber'] as String?) ?? '',
      unitSalePrice: (productInfoJson['unitSalePrice'] as String?) ?? '',
      dimensionsSize: (productInfoJson['dimensionsSize'] as String?) ?? '',
      languageOfDeclarations:
          (productInfoJson['languageOfDeclarations'] as String?) ?? '',
      languageUsed: (productInfoJson['languageUsed'] as String?) ?? '',
    );

    final extList = json['extractedFields'] as List? ?? [];
    final extractedFields = extList.whereType<Map>().map((item) {
      final m = Map<String, dynamic>.from(item);
      return ExtractedField(
        id: (m['id'] as String?) ?? 'fld',
        fieldName: (m['fieldName'] as String?) ?? '',
        value: (m['value'] as String?) ?? '',
        confidence: ((m['confidence'] as num?) ?? 0).toDouble(),
        exactVisibleText: (m['exactVisibleText'] as String?),
        evidenceDescription: (m['evidenceDescription'] as String?),
      );
    }).toList();

    final ccList = json['complianceChecks'] as List? ?? [];
    final complianceChecks = ccList.whereType<Map>().map((item) {
      final m = Map<String, dynamic>.from(item);
      final statusStr = (m['status'] as String?) ?? 'review';
      ComplianceStatus s;
      switch (statusStr) {
        case 'pass':
          s = ComplianceStatus.pass;
          break;
        case 'fail':
          s = ComplianceStatus.fail;
          break;
        default:
          s = ComplianceStatus.review;
      }
      return ComplianceCheck(
        id: (m['id'] as String?) ?? 'chk',
        ruleName: (m['ruleName'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        ruleReference: (m['ruleReference'] as String?) ?? '',
        field: (m['field'] as String?) ?? '',
        mandatory: m['mandatory'] == true,
        confidence: ((m['confidence'] as num?) ?? 0).toDouble(),
        exactVisibleText: (m['exactVisibleText'] as String?),
        evidenceDescription: (m['evidenceDescription'] as String?),
        reason: (m['reason'] as String?) ?? '',
        status: s,
        isChecked: m['isChecked'] != false,
      );
    }).toList();

    final vList = json['violations'] as List? ?? [];
    final violations = vList.whereType<Map>().map((item) {
      final m = Map<String, dynamic>.from(item);
      return Violation(
        id: (m['id'] as String?) ?? 'v',
        title: (m['title'] as String?) ?? '',
        requirement: (m['requirement'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'REVIEW',
        evidenceNote: (m['evidenceNote'] as String?) ?? '',
      );
    }).toList();

    final inspDateStr = json['inspectionDate'] as String?;
    final inspDate = inspDateStr != null
        ? DateTime.tryParse(inspDateStr) ?? DateTime.now()
        : DateTime.now();

    return InspectionModel(
      reportId: (json['reportId'] as String?) ?? 'CN-RESTORED',
      inspectionDate: inspDate,
      productImageUrl: '',
      productImages: const [],
      legacyImageBytes: fallbackImageBytes,
      productInfo: productInfo,
      extractedFields: extractedFields,
      complianceChecks: complianceChecks,
      violations: violations,
      aiAnalysisComplete: json['aiAnalysisComplete'] == true,
      manualVerificationComplete:
          json['manualVerificationComplete'] == true,
      backendOverallStatus:
          (json['backendOverallStatus'] as String?) ?? fallbackOverall,
      disclaimer: (json['disclaimer'] as String?) ?? '',
      prototypeNotice: (json['prototypeNotice'] as String?) ?? '',
      misleadingQuantityFindings:
          (json['misleadingQuantityFindings'] as String?),
      nonStandardUnitFindings:
          (json['nonStandardUnitFindings'] as String?),
    );
  }

  void syncProductInfoFromFields() {
    productInfo.productName = _fieldValue('product_name');
    productInfo.commonName = _fieldValue('common_name');
    productInfo.manufacturer = _fieldValue('manufacturer');
    productInfo.packer = _fieldValue('packer');
    productInfo.importer = _fieldValue('importer');
    productInfo.address = _fieldValue('address');
    productInfo.netQuantity = _fieldValue('net_quantity');
    productInfo.mrp = _fieldValue('mrp');
    productInfo.unit = _fieldValue('unit');
    productInfo.currency = _fieldValue('currency');
    productInfo.packingDate = _fieldValue('packing_date');
    productInfo.bestBefore = _fieldValue('best_before');
    productInfo.consumerCare = _fieldValue('consumer_care');
    productInfo.email = _fieldValue('email');
    productInfo.phone = _fieldValue('phone');
    productInfo.countryOfOrigin = _fieldValue('country_of_origin');
    productInfo.batchNumber = _fieldValue('batch_number');
    productInfo.unitSalePrice = _fieldValue('unit_sale_price');
    productInfo.dimensionsSize = _fieldValue('dimensions_size');
    productInfo.languageOfDeclarations =
        _fieldValue('language_of_declarations');
    productInfo.languageUsed = _fieldValue('language_used');
  }

  void rebuildViolations() {
    violations = complianceChecks
        .where((c) =>
            c.status == ComplianceStatus.fail ||
            c.status == ComplianceStatus.review)
        .map(
          (c) => Violation(
            id: c.id,
            title: c.ruleName,
            requirement: c.description,
            status: c.status == ComplianceStatus.fail
                ? 'NON-COMPLIANT'
                : 'REVIEW',
            evidenceNote: _evidenceLine(c),
            ruleReference:
                c.ruleReference.isEmpty ? null : c.ruleReference,
            sourceImageLabel: c.sourceImageLabel,
          ),
        )
        .toList();
  }

  String _fieldValue(String id) {
    final match = extractedFields.where((f) => f.id == id);
    if (match.isEmpty) return '';
    return match.first.value;
  }

  ComplianceStatus get overallStatus {
    var hasFail = false;
    var hasReview = false;
    for (final check in complianceChecks) {
      if (!check.isChecked) {
        hasReview = true;
        continue;
      }
      if (check.status == ComplianceStatus.fail && check.mandatory) {
        hasFail = true;
      } else if (check.status == ComplianceStatus.fail) {
        hasReview = true;
      }
      if (check.status == ComplianceStatus.review) hasReview = true;
    }
    if (hasFail) return ComplianceStatus.fail;
    if (hasReview) return ComplianceStatus.review;
    return ComplianceStatus.pass;
  }

  String get overallStatusLabel {
    switch (overallStatus) {
      case ComplianceStatus.pass:
        return 'COMPLIANT';
      case ComplianceStatus.fail:
        return 'NON-COMPLIANT';
      case ComplianceStatus.review:
        return 'MANUAL REVIEW';
    }
  }

  int get passedCount =>
      complianceChecks.where((c) => c.status == ComplianceStatus.pass).length;

  int get failedCount =>
      complianceChecks.where((c) => c.status == ComplianceStatus.fail).length;

  int get reviewCount =>
      complianceChecks
          .where((c) => c.status == ComplianceStatus.review)
          .length;

  bool get hasDetectedFields => extractedFields.any((f) {
        final value = f.value.trim();
        return value.isNotEmpty && value.toLowerCase() != 'not detected';
      });

  int get verifiedCheckCount =>
      complianceChecks.where((c) => c.isChecked).length;

  int get inspectorReviewedCount =>
      complianceChecks.where((c) => c.inspectorReviewed).length;
}

class RecentReport {
  final String id;
  final String productName;
  final ComplianceStatus status;
  final DateTime date;

  RecentReport({
    required this.id,
    required this.productName,
    required this.status,
    required this.date,
  });

  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')} ${_monthShort(date.month)} ${date.year}';
  }

  String _monthShort(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }

  String get statusLabel {
    switch (status) {
      case ComplianceStatus.pass:
        return 'COMPLIANT';
      case ComplianceStatus.fail:
        return 'NON-COMPLIANT';
      case ComplianceStatus.review:
        return 'MANUAL REVIEW';
    }
  }
}

List<ExtractedField> _fieldsFromExtraction(Map<String, dynamic> extraction) {
  final extraKeys = extraction['source_image_indexes'] as Map? ?? {};

  String displayValue(String key) {
    final raw = extraction[key];
    if (raw is! Map) return 'Not detected';
    if (key == 'net_quantity') {
      final value = raw['value'];
      final unit = raw['unit'];
      if (value == null && (unit == null || '$unit'.isEmpty)) {
        return 'Not detected';
      }
      return '${value ?? ''} ${unit ?? ''}'.trim();
    }
    if (key == 'mrp') {
      final value = raw['value'];
      final currency = (raw['currency'] as String?) ?? 'INR';
      if (value == null) return 'Not detected';
      if (currency.toUpperCase() == 'INR') {
        return '₹$value';
      }
      return '$currency $value';
    }
    final value = raw['value'];
    if (value == null || '$value'.trim().isEmpty) return 'Not detected';
    return '$value';
  }

  double confidence(String key) {
    final raw = extraction[key];
    if (raw is! Map) return 0;
    final value = raw['confidence'];
    if (value is num) return value.toDouble() * 100;
    return 0;
  }

  String? exact(String key) {
    final raw = extraction[key];
    if (raw is! Map) return null;
    return raw['exact_visible_text'] as String?;
  }

  String? evidence(String key) {
    final raw = extraction[key];
    if (raw is! Map) return null;
    return raw['evidence_description'] as String?;
  }

  int? sourceIndex(String key) {
    final raw = extraction[key];
    if (raw is Map) {
      final idx = raw['source_image_index'];
      if (idx is int) return idx;
    }
    final extraIdx = extraKeys[key];
    if (extraIdx is int) return extraIdx;
    return null;
  }

  ExtractedField field(String id, String name) {
    final idx = sourceIndex(id);
    return ExtractedField(
      id: id,
      fieldName: name,
      value: displayValue(id),
      confidence: confidence(id),
      exactVisibleText: exact(id),
      evidenceDescription: evidence(id),
      sourceImageIndex: idx,
      sourceImageLabel: idx == null ? null : 'Photo $idx',
    );
  }

  return [
    field('product_name', 'Product Name'),
    field('common_name', 'Common Name'),
    field('manufacturer', 'Manufacturer'),
    field('packer', 'Packer'),
    field('importer', 'Importer'),
    field('address', 'Address'),
    field('net_quantity', 'Net Quantity'),
    field('mrp', 'MRP'),
    field('currency', 'Currency'),
    field('dimensions_size', 'Dimensions / Size'),
    field('packing_date', 'Packing Date'),
    field('best_before', 'Best Before / Use By'),
    field('consumer_care', 'Consumer Care'),
    field('country_of_origin', 'Country of Origin'),
    field('batch_number', 'Batch Number'),
    field('unit_sale_price', 'Unit Sale Price'),
    field('language_used', 'Language Used'),
    field('language_of_declarations', 'Language of Declarations'),
  ];
}

ProductInfo _productFromFields(List<ExtractedField> fields) {
  String value(String id) {
    final match = fields.where((f) => f.id == id);
    return match.isEmpty ? '' : match.first.value;
  }

  return ProductInfo(
    productName: value('product_name'),
    commonName: value('common_name'),
    manufacturer: value('manufacturer'),
    packer: value('packer'),
    importer: value('importer'),
    address: value('address'),
    netQuantity: value('net_quantity'),
    mrp: value('mrp'),
    currency: value('currency'),
    unit: value('unit'),
    packingDate: value('packing_date'),
    bestBefore: value('best_before'),
    consumerCare: value('consumer_care'),
    email: value('email'),
    phone: value('phone'),
    countryOfOrigin: value('country_of_origin'),
    batchNumber: value('batch_number'),
    unitSalePrice: value('unit_sale_price'),
    dimensionsSize: value('dimensions_size'),
    languageOfDeclarations: value('language_of_declarations'),
    languageUsed: value('language_used'),
  );
}

List<ComplianceCheck> _checksFromApi(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((item) {
    final int? srcIdx = item['source_image_index'] is int
        ? item['source_image_index'] as int
        : null;
    return ComplianceCheck(
      id: (item['rule_id'] as String?) ?? uniqueFallback(item),
      ruleName: _titleFromField(item['field'] as String? ?? ''),
      description: (item['requirement'] as String?) ?? '',
      ruleReference: (item['rule_reference'] as String?) ?? '',
      field: (item['field'] as String?) ?? '',
      mandatory: item['mandatory'] == true,
      confidence: ((item['confidence'] as num?) ?? 0).toDouble() * 100,
      exactVisibleText: item['exact_visible_text'] as String?,
      evidenceDescription: item['evidence_description'] as String?,
      explanation: item['explanation'] as String?,
      sourceImageIndex: srcIdx,
      sourceImageLabel: srcIdx == null ? null : 'Photo $srcIdx',
      reason: (item['reason'] as String?) ?? '',
      status: _statusFromApi(item['status'] as String?),
      isChecked: true,
    );
  }).toList();
}

String uniqueFallback(Map item) => 'rule-${item.hashCode}';

String _titleFromField(String field) {
  switch (field) {
    case 'product_name':
      return 'Product Name';
    case 'manufacturer_party':
      return 'Manufacturer Details';
    case 'net_quantity':
      return 'Net Quantity';
    case 'mrp':
      return 'MRP';
    case 'consumer_care':
      return 'Consumer Care';
    case 'country_of_origin':
      return 'Country of Origin';
    case 'packing_date':
      return 'Packing Date';
    case 'best_before':
      return 'Best Before / Use By';
    case 'language_of_declarations':
      return 'Language of Declarations';
    case 'quantity_expression':
      return 'Misleading Quantity Expression';
    case 'unit_sale_price':
      return 'Unit Sale Price';
    case 'batch_number':
      return 'Batch Number';
    case 'packer':
      return 'Packer';
    case 'importer':
      return 'Importer';
    default:
      return field.replaceAll('_', ' ');
  }
}

ComplianceStatus _statusFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'PASS':
      return ComplianceStatus.pass;
    case 'FAIL':
      return ComplianceStatus.fail;
    default:
      return ComplianceStatus.review;
  }
}

String _evidenceLine(ComplianceCheck check) {
  final visible = (check.exactVisibleText ?? '').trim();
  if (visible.isNotEmpty) {
    return '"$visible" — detected from product label.';
  }
  final desc = (check.evidenceDescription ?? '').trim();
  if (desc.isNotEmpty) return desc;
  return 'Detected from product label.';
}
