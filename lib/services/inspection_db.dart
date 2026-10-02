import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class InspectionDb {
  static final InspectionDb instance = InspectionDb._init();
  InspectionDb._init();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'cyber_nova_inspections.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        overall_status TEXT NOT NULL,
        inspection_date INTEGER NOT NULL,
        summary_json TEXT NOT NULL,
        full_json TEXT NOT NULL,
        image_bytes_blob BLOB,
        image_count INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_inspections_date ON inspections(inspection_date DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE inspections ADD COLUMN image_count INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {}
    }
  }

  Future<int> saveInspection(InspectionModel model) async {
    final db = await database;

    final summary = <String, dynamic>{
      'passed': model.passedCount,
      'failed': model.failedCount,
      'review': model.reviewCount,
      'overall': model.backendOverallStatus.isEmpty
          ? model.overallStatusLabel
          : model.backendOverallStatus,
    };

    final full = <String, dynamic>{
      'reportId': model.reportId,
      'inspectionDate': model.inspectionDate.toIso8601String(),
      'productInfo': {
        'productName': model.productInfo.productName,
        'commonName': model.productInfo.commonName,
        'manufacturer': model.productInfo.manufacturer,
        'packer': model.productInfo.packer,
        'importer': model.productInfo.importer,
        'address': model.productInfo.address,
        'netQuantity': model.productInfo.netQuantity,
        'unit': model.productInfo.unit,
        'mrp': model.productInfo.mrp,
        'currency': model.productInfo.currency,
        'packingDate': model.productInfo.packingDate,
        'bestBefore': model.productInfo.bestBefore,
        'consumerCare': model.productInfo.consumerCare,
        'countryOfOrigin': model.productInfo.countryOfOrigin,
        'batchNumber': model.productInfo.batchNumber,
        'unitSalePrice': model.productInfo.unitSalePrice,
        'dimensionsSize': model.productInfo.dimensionsSize,
        'languageOfDeclarations': model.productInfo.languageOfDeclarations,
        'languageUsed': model.productInfo.languageUsed,
        'email': model.productInfo.email,
        'phone': model.productInfo.phone,
      },
      'extractedFields': model.extractedFields
          .map((f) => {
                'id': f.id,
                'fieldName': f.fieldName,
                'value': f.value,
                'confidence': f.confidence,
                'exactVisibleText': f.exactVisibleText,
                'evidenceDescription': f.evidenceDescription,
              })
          .toList(),
      'complianceChecks': model.complianceChecks
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
      'violations': model.violations
          .map((v) => {
                'id': v.id,
                'title': v.title,
                'requirement': v.requirement,
                'status': v.status,
                'evidenceNote': v.evidenceNote,
              })
          .toList(),
      'backendOverallStatus': model.backendOverallStatus,
      'disclaimer': model.disclaimer,
      'prototypeNotice': model.prototypeNotice,
      'aiAnalysisComplete': model.aiAnalysisComplete,
      'manualVerificationComplete': model.manualVerificationComplete,
      'misleadingQuantityFindings': model.misleadingQuantityFindings,
      'nonStandardUnitFindings': model.nonStandardUnitFindings,
    };

    final overallStatus = model.backendOverallStatus.isEmpty
        ? model.overallStatusLabel
        : model.backendOverallStatus;

    return await db.insert(
      'inspections',
      {
        'report_id': model.reportId,
        'product_name': model.productInfo.productName.isEmpty
            ? '(unnamed product)'
            : model.productInfo.productName,
        'overall_status': overallStatus,
        'inspection_date': model.inspectionDate.millisecondsSinceEpoch,
        'summary_json': jsonEncode(summary),
        'full_json': jsonEncode(full),
        'image_bytes_blob': model.imageBytes,
        'image_count': model.imageCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecentReport>> listRecent({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'inspections',
      orderBy: 'inspection_date DESC',
      limit: limit,
    );
    return rows.map((r) {
      final overall = (r['overall_status'] as String? ?? '').toUpperCase();
      ComplianceStatus status;
      if (overall.contains('NON_COMPLIANT') || overall == 'FAIL') {
        status = ComplianceStatus.fail;
      } else if (overall.contains('MANUAL') || overall == 'REVIEW') {
        status = ComplianceStatus.review;
      } else {
        status = ComplianceStatus.pass;
      }
      return RecentReport(
        id: r['report_id'] as String? ?? 'row-${r['id']}',
        productName: r['product_name'] as String? ?? '(unnamed product)',
        status: status,
        date: DateTime.fromMillisecondsSinceEpoch(
          r['inspection_date'] as int? ?? 0,
        ),
      );
    }).toList();
  }

  Future<List<RecentReport>> listInspections({int limit = 25}) =>
      listRecent(limit: limit);

  Future<InspectionModel?> getFullInspection(String reportId) async {
    final db = await database;
    final rows = await db.query(
      'inspections',
      where: 'report_id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final fullJson = row['full_json'] as String?;
    if (fullJson == null) return null;
    try {
      final decoded = jsonDecode(fullJson) as Map<String, dynamic>;
      final productName =
          row['product_name'] as String? ?? '(unnamed product)';
      final imageBytes = row['image_bytes_blob'] as Uint8List?;
      final overallStatus =
          row['overall_status'] as String? ?? 'MANUAL_REVIEW';
      return InspectionModel.fromJsonDb(
        decoded,
        fallbackProductName: productName,
        fallbackImageBytes: imageBytes,
        fallbackOverall: overallStatus,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> deleteAll() async {
    final db = await database;
    return await db.delete('inspections');
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }
}
