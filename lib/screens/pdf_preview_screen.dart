import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/data/dummy_data.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/services/inspection_session.dart';
import 'package:cyber_nova/services/pdf_report_service.dart';
import 'package:cyber_nova/widgets/product_label_image.dart';
import 'package:cyber_nova/widgets/legal_disclaimer.dart';

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late InspectionModel _inspection;
  bool _isGenerating = false;
  bool _isGenerated = false;
  final PdfReportService _pdf = PdfReportService();

  @override
  void initState() {
    super.initState();
    _inspection =
        InspectionSession.instance.current ?? InspectionModel.empty();
  }

  Future<void> _onGeneratePdf() async {
    setState(() {
      _isGenerating = true;
    });
    try {
      await _pdf.preview(_inspection);
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _isGenerated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('PDF report generated successfully'),
            ],
          ),
          backgroundColor: AppTheme.passGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate the PDF. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _inspection.overallStatus;
    final statusLabel = _inspection.overallStatusLabel;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Report Preview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in_outlined, color: Colors.white70),
            onPressed: () {},
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_outlined, color: Colors.white70),
            onPressed: () {},
            tooltip: 'Zoom Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(36),
                          child: _buildDocumentContent(context, status, statusLabel),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildPageIndicator(context),
              ],
            ),
          ),
          _buildBottomButtons(context),
          if (_isGenerating) _buildGeneratingOverlay(context),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(
    BuildContext context,
    ComplianceStatus status,
    String statusLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocHeader(context),
        const SizedBox(height: 28),
        _buildDocDivider(),
        const SizedBox(height: 20),
        _buildDocReportMeta(context),
        const SizedBox(height: 24),
        _buildDocProductImage(context),
        const SizedBox(height: 24),
        _buildDocSectionTitle(context, 'Product Information'),
        const SizedBox(height: 10),
        _buildDocProductInfo(context),
        const SizedBox(height: 24),
        _buildDocSectionTitle(context, 'Compliance Summary'),
        const SizedBox(height: 10),
        _buildDocSummary(context, status, statusLabel),
        const SizedBox(height: 24),
        _buildDocSectionTitle(context, 'Compliance Checks'),
        const SizedBox(height: 10),
        _buildDocChecksTable(context),
        const SizedBox(height: 24),
        if (_inspection.violations.isNotEmpty) ...[
          _buildDocSectionTitle(context, 'Violations'),
          const SizedBox(height: 10),
          _buildDocViolations(context),
          const SizedBox(height: 24),
        ],
        _buildDocSectionTitle(context, 'Final Decision'),
        const SizedBox(height: 10),
        _buildDocDecision(context, status, statusLabel),
        const SizedBox(height: 16),
        const LegalDisclaimerNote(),
      ],
    );
  }

  Widget _buildDocHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CYBER NOVA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'LEGAL METROLOGY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Text(
                    'INSPECTION REPORT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocDivider() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
            AppTheme.primaryColor.withOpacity(0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildDocReportMeta(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REPORT ID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _inspection.reportId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DummyData.formattedDate(_inspection.inspectionDate),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocProductImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ProductLabelImage(inspection: _inspection, height: 140),
    );
  }

  Widget _buildDocSectionTitle(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        border: Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 3),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildDocProductInfo(BuildContext context) {
    final info = _inspection.productInfo;
    final items = [
      ('Product Name', info.productName),
      ('Manufacturer / Packer', info.manufacturer),
      ('Address', info.address),
      ('Net Quantity', info.netQuantity),
      ('MRP', info.mrp),
      ('Date of Packing', info.packingDate),
      ('Consumer Care', info.consumerCare),
      ('Country of Origin', info.countryOfOrigin),
      ('Batch Number', info.batchNumber),
      ('Unit Sale Price', info.unitSalePrice),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppTheme.dividerColor),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    e.value.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocSummary(
    BuildContext context,
    ComplianceStatus status,
    String statusLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FINAL STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDocCounter(
                    'Passed', '${_inspection.passedCount}', AppTheme.passGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDocCounter('Review',
                    '${_inspection.reviewCount}', AppTheme.reviewOrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDocCounter(
                    'Failed', '${_inspection.failedCount}', AppTheme.failRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocCounter(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocChecksTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Rule / Requirement',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._inspection.complianceChecks.asMap().entries.map((e) {
            final check = e.value;
            final isLast = e.key == _inspection.complianceChecks.length - 1;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppTheme.dividerColor),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      check.ruleName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        check.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: check.status.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocViolations(BuildContext context) {
    return Column(
      children: _inspection.violations.asMap().entries.map((e) {
        final violation = e.value;
        return Padding(
          padding: EdgeInsets.only(top: e.key == 0 ? 0 : 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.failRedLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.failRed.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cancel,
                        color: AppTheme.failRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        violation.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.failRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Requirement:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  violation.requirement,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Evidence:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  violation.evidenceNote,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocDecision(
    BuildContext context,
    ComplianceStatus status,
    String statusLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FINAL DECISION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: status.color,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: status.color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              status.icon,
              color: status.color,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 90),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Page 1 of 1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          14 + MediaQuery.of(context).padding.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _pdf.share(_inspection);
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to share the PDF. Please try again.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share Report'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _onGeneratePdf,
                  icon: Icon(
                    _isGenerated
                        ? Icons.check
                        : Icons.download_for_offline_outlined,
                    size: 20,
                  ),
                  label: Text(_isGenerated ? 'PDF Generated' : 'Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _isGenerated
                        ? AppTheme.passGreen
                        : AppTheme.failRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 50),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.failRed),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Generating PDF...',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Compiling report document',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
