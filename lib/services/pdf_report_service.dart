import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class PdfReportService {
  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[dt.month - 1];
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d $m $y · $hh:$mm';
  }

  Future<Uint8List> build(InspectionModel inspection) async {
    final fontRegularBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final fontBoldBytes = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final notoRegular = pw.Font.ttf(fontRegularBytes);
    final notoBold = pw.Font.ttf(fontBoldBytes);

    TextStyleFn baseStyle = ({
      double fontSize = 11,
      PdfColor? color,
      bool bold = false,
      double? letterSpacing,
    }) =>
        pw.TextStyle(
          font: bold ? notoBold : notoRegular,
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
        );

    final doc = pw.Document();
    final status = inspection.overallStatus;
    final statusColor = switch (status) {
      ComplianceStatus.pass => PdfColor.fromInt(0xFF2E7D32),
      ComplianceStatus.fail => PdfColor.fromInt(0xFFC62828),
      ComplianceStatus.review => PdfColor.fromInt(0xFFEF6C00),
    };

    pw.MemoryImage? photo;
    if (inspection.imageBytes != null && inspection.imageBytes!.isNotEmpty) {
      try {
        photo = pw.MemoryImage(inspection.imageBytes!);
      } catch (_) {
        photo = null;
      }
    }

    List<pw.MemoryImage> extraPhotos = [];
    if (inspection.allImages != null) {
      for (final bytes in inspection.allImages!.skip(1)) {
        try {
          if (bytes != null && bytes.isNotEmpty) {
            extraPhotos.add(pw.MemoryImage(bytes));
          }
        } catch (_) {}
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0B3D91),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CYBER NOVA',
                    style: baseStyle(fontSize: 18, bold: true, color: PdfColor.fromInt(0xFF0B3D91)),
                  ),
                  pw.Text(
                    'LEGAL METROLOGY INSPECTION REPORT',
                    style: baseStyle(fontSize: 10, letterSpacing: 1.1),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Report ID: ${inspection.reportId}', style: baseStyle()),
                    pw.SizedBox(height: 4),
                    pw.Text('Date: ${_formatDate(inspection.inspectionDate)}', style: baseStyle()),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor(0.08, statusColor.red, statusColor.green, statusColor.blue),
                  border: pw.Border.all(color: statusColor, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  inspection.overallStatusLabel,
                  style: baseStyle(fontSize: 12, bold: true, color: statusColor),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          if (photo != null)
            pw.Container(
              height: 180,
              width: double.infinity,
              child: pw.Image(photo, fit: pw.BoxFit.cover),
            ),
          if (extraPhotos.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extraPhotos
                  .map((img) => pw.SizedBox(
                        height: 90,
                        width: 130,
                        child: pw.Image(img, fit: pw.BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 16),
          _sectionHeading('Product Information', baseStyle),
          _kv('Product Name', inspection.productInfo.productName, baseStyle),
          if (inspection.productInfo.commonName.isNotEmpty)
            _kv('Common Name', inspection.productInfo.commonName, baseStyle),
          if (inspection.productInfo.manufacturer.isNotEmpty)
            _kv('Manufacturer', inspection.productInfo.manufacturer, baseStyle),
          if (inspection.productInfo.packer.isNotEmpty)
            _kv('Packer', inspection.productInfo.packer, baseStyle),
          if (inspection.productInfo.importer.isNotEmpty)
            _kv('Importer', inspection.productInfo.importer, baseStyle),
          if (inspection.productInfo.address.isNotEmpty)
            _kv('Address', inspection.productInfo.address, baseStyle),
          pw.SizedBox(height: 12),
          _sectionHeading('Quantity & Pricing', baseStyle),
          if (inspection.productInfo.netQuantity.isNotEmpty)
            _kv('Net Quantity', inspection.productInfo.netQuantity, baseStyle),
          if (inspection.productInfo.mrp.isNotEmpty)
            _kv('MRP', inspection.productInfo.mrp, baseStyle),
          if (inspection.productInfo.currency.isNotEmpty)
            _kv('Currency', inspection.productInfo.currency, baseStyle),
          if (inspection.productInfo.unitSalePrice.isNotEmpty)
            _kv('Unit Sale Price', inspection.productInfo.unitSalePrice, baseStyle),
          if (inspection.productInfo.dimensionsSize.isNotEmpty)
            _kv('Dimensions / Size', inspection.productInfo.dimensionsSize, baseStyle),
          pw.SizedBox(height: 12),
          _sectionHeading('Dates & Validity', baseStyle),
          if (inspection.productInfo.packingDate.isNotEmpty)
            _kv('Packing Date', inspection.productInfo.packingDate, baseStyle),
          if (inspection.productInfo.bestBefore.isNotEmpty)
            _kv('Best Before / Use By', inspection.productInfo.bestBefore, baseStyle),
          pw.SizedBox(height: 12),
          _sectionHeading('Consumer Information', baseStyle),
          if (inspection.productInfo.consumerCare.isNotEmpty)
            _kv('Consumer Care', inspection.productInfo.consumerCare, baseStyle),
          if (inspection.productInfo.countryOfOrigin.isNotEmpty)
            _kv('Country of Origin', inspection.productInfo.countryOfOrigin, baseStyle),
          pw.SizedBox(height: 12),
          _sectionHeading('Identification & Declarations', baseStyle),
          if (inspection.productInfo.batchNumber.isNotEmpty)
            _kv('Batch Number', inspection.productInfo.batchNumber, baseStyle),
          if (inspection.productInfo.languageOfDeclarations.isNotEmpty)
            _kv('Language of Declarations', inspection.productInfo.languageOfDeclarations, baseStyle)
          else if (inspection.productInfo.languageUsed.isNotEmpty)
            _kv('Language of Declarations', inspection.productInfo.languageUsed, baseStyle),
          pw.SizedBox(height: 14),
          _sectionHeading('Compliance Summary', baseStyle),
          pw.Text(
            inspection.overallStatusLabel,
            style: baseStyle(fontSize: 16, bold: true, color: statusColor),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Passed: ${inspection.passedCount}   Failed: ${inspection.failedCount}   Review: ${inspection.reviewCount}',
            style: baseStyle(),
          ),
          if (inspection.complianceChecks.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionHeading('Compliance Checks', baseStyle),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
              headerStyle: baseStyle(bold: true, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF0B3D91)),
              cellStyle: baseStyle(),
              cellAlignment: pw.Alignment.topLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              headers: const ['Rule', 'Field', 'Status', 'Reason'],
              columnWidths: {
                0: const pw.FixedColumnWidth(90),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FlexColumnWidth(),
              },
              data: inspection.complianceChecks.map((c) {
                return [
                  c.ruleName,
                  c.field.isEmpty ? '-' : c.field,
                  c.status.name.toUpperCase(),
                  c.reason.isEmpty ? (c.description.length > 140 ? '${c.description.substring(0, 140)}…' : c.description)
                      : (c.reason.length > 200 ? '${c.reason.substring(0, 200)}…' : c.reason),
                ];
              }).toList(),
            ),
          ],
          if (inspection.misleadingQuantityFindings?.isNotEmpty ?? false) ...[
            pw.SizedBox(height: 12),
            _sectionHeading('Misleading / Vague Quantity Findings', baseStyle),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                inspection.misleadingQuantityFindings!,
                style: baseStyle(),
              ),
            ),
          ],
          if (inspection.nonStandardUnitFindings?.isNotEmpty ?? false) ...[
            pw.SizedBox(height: 12),
            _sectionHeading('Non-Standard Declarations / Units', baseStyle),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                inspection.nonStandardUnitFindings!,
                style: baseStyle(),
              ),
            ),
          ],
          if (inspection.violations.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionHeading('Violations / Review Items', baseStyle),
            ...inspection.violations.map(
              (v) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(v.title, style: baseStyle(bold: true)),
                    pw.SizedBox(height: 2),
                    pw.Text(v.requirement, style: baseStyle()),
                    if (v.evidenceNote.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('Evidence: ${v.evidenceNote}', style: baseStyle()),
                    ],
                  ],
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          _sectionHeading('Manual Verification', baseStyle),
          pw.Text(
            '${inspection.complianceChecks.where((c) => c.isChecked).length}/${inspection.complianceChecks.length} items verified by the operator.',
            style: baseStyle(),
          ),
          pw.SizedBox(height: 12),
          _sectionHeading('Final Decision', baseStyle),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor(0.06, statusColor.red, statusColor.green, statusColor.blue),
              border: pw.Border.all(color: statusColor, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              inspection.overallStatusLabel,
              style: baseStyle(fontSize: 16, bold: true, color: statusColor),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            inspection.disclaimer.isNotEmpty
                ? inspection.disclaimer
                : 'AI-assisted preliminary inspection. Final compliance determination requires verification against applicable Legal Metrology rules and authorized inspection procedures. This report does not constitute a legal certification.',
            style: baseStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> preview(InspectionModel inspection) async {
    try {
      final bytes = await build(inspection);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> share(InspectionModel inspection) async {
    final bytes = await build(inspection);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${inspection.reportId}.pdf',
    );
  }

  pw.Widget _sectionHeading(String text, TextStyleFn base) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 14,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0B3D91),
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(text, style: base(fontSize: 13, bold: true)),
        ],
      ),
    );
  }

  pw.Widget _kv(String label, String value, TextStyleFn base) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: base(bold: true)),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? 'Not detected' : value, style: base()),
          ),
        ],
      ),
    );
  }
}

typedef TextStyleFn = pw.TextStyle Function({
  double fontSize,
  PdfColor? color,
  bool bold,
  double? letterSpacing,
});
