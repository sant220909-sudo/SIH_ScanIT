import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/services/inspection_session.dart';
import 'package:cyber_nova/services/inspection_db.dart';
import 'package:cyber_nova/services/api_service.dart';
import 'package:cyber_nova/services/pdf_report_service.dart';
import 'package:cyber_nova/widgets/status_badge.dart';
import 'package:cyber_nova/widgets/section_title.dart';
import 'package:cyber_nova/widgets/legal_disclaimer.dart';
import 'package:cyber_nova/widgets/product_label_image.dart';

String _formatDate(DateTime dt) {
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

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late InspectionModel _inspection;
  bool _hasInspection = false;
  List<RecentReport> _history = const [];
  bool _historyLoading = true;
  String? _historyError;
  bool _historyIsBackend = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    final current = InspectionSession.instance.current;
    _hasInspection = current != null;
    _inspection = current ?? InspectionModel.empty();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    List<RecentReport>? fromBackend;
    try {
      fromBackend = await _api.listInspections(limit: 25);
      if (!mounted) return;
      setState(() {
        _history = fromBackend ?? const [];
        _historyLoading = false;
        _historyIsBackend = true;
        _historyError = null;
      });
      return;
    } catch (e) {
      try {
        final rows = await InspectionDb.instance.listRecent(limit: 25);
        if (!mounted) return;
        setState(() {
          _history = rows;
          _historyLoading = false;
          _historyIsBackend = false;
          _historyError =
              'Unable to load inspection history from the backend. Showing local-only reports. Please check the backend connection.';
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _historyLoading = false;
          _historyIsBackend = false;
          _historyError =
              'Unable to load inspection history. Please check the backend connection.';
        });
      }
    }
  }

  Future<void> _openHistoryItem(RecentReport row) async {
    InspectionModel? full;
    String? loadError;
    if (_historyIsBackend || row.id.startsWith('CN-')) {
      try {
        full = await _api.getInspection(row.id);
      } catch (e) {
        loadError = e.toString();
        full = null;
      }
    }
    full ??= await InspectionDb.instance.getFullInspection(row.id);
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load inspection. ${loadError ?? ''}')),
      );
      return;
    }
    final inspection = full;
    InspectionSession.instance.save(inspection);
    setState(() {
      _inspection = inspection;
      _hasInspection = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded report ${inspection.reportId}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveInspectionToDb() async {
    if (!_hasInspection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inspection to save.')),
      );
      return;
    }
    try {
      _inspection.rebuildViolations();
      String finalId = _inspection.reportId;
      bool savedBackend = false;
      try {
        finalId = await _api.saveInspection(_inspection);
        savedBackend = true;
        try {
          await InspectionDb.instance.saveInspection(_inspection);
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('backend save failed, using local only: $e');
        await InspectionDb.instance.saveInspection(_inspection);
      }
      if (!mounted) return;
      final snackMsg = savedBackend
          ? 'Saved report $finalId to backend history'
          : 'Saved report $finalId locally (backend unavailable)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                savedBackend ? Icons.check_circle : Icons.cloud_off_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(snackMsg)),
            ],
          ),
          backgroundColor: savedBackend ? AppTheme.passGreen : AppTheme.reviewOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _inspection.overallStatus;
    final statusLabel = _inspection.overallStatusLabel;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inspection Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _hasInspection
                ? () => PdfReportService().preview(_inspection)
                : null,
            tooltip: 'Print',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportHeader(context),
                  const SizedBox(height: 24),
                  _buildProductImageWithEvidence(context),
                  const SizedBox(height: 24),
                  _buildProductInfo(context),
                  const SizedBox(height: 24),
                  _buildComplianceSummary(context, status, statusLabel),
                  const SizedBox(height: 24),
                  _buildComplianceChecks(context),
                  const SizedBox(height: 24),
                  _buildManualVerification(context),
                  const SizedBox(height: 24),
                  if (_inspection.violations.isNotEmpty)
                    _buildViolationsSection(context),
                  const SizedBox(height: 24),
                  _buildInspectorVerification(context, status, statusLabel),
                  const SizedBox(height: 24),
                  _buildInspectionHistory(context),
                  const SizedBox(height: 16),
                  const LegalDisclaimerNote(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildReportHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: const [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CYBER NOVA',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Legal Metrology Inspection Report',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report ID',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.4,
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _inspection.reportId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
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
                    Text(
                      'Inspection Date',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.4,
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(_inspection.inspectionDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.4,
                      fontSize: 11,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _inspection.productInfo.productName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageWithEvidence(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Product Label Evidence',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ProductLabelImage(inspection: _inspection, height: 200),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final v = value.trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.3,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    v,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(BuildContext context) {
    final info = _inspection.productInfo;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Product Information'),
          const SizedBox(height: 4),
          _infoRow(
            context: context,
            label: 'Product Name',
            value: info.productName,
            icon: Icons.label_outline,
          ),
          _infoRow(
            context: context,
            label: 'Common Name',
            value: info.commonName,
            icon: Icons.category_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Manufacturer',
            value: info.manufacturer,
            icon: Icons.apartment_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Packer',
            value: info.packer,
            icon: Icons.inventory_2_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Importer',
            value: info.importer,
            icon: Icons.flight_takeoff_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Address',
            value: info.address,
            icon: Icons.location_on_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Net Quantity',
            value: info.netQuantity,
            icon: Icons.line_weight_outlined,
          ),
          _infoRow(
            context: context,
            label: 'MRP',
            value: info.mrp,
            icon: Icons.sell_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Unit Sale Price',
            value: info.unitSalePrice,
            icon: Icons.price_change_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Dimensions / Size',
            value: info.dimensionsSize,
            icon: Icons.straighten_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Packing Date',
            value: info.packingDate,
            icon: Icons.calendar_today_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Best Before / Use By',
            value: info.bestBefore,
            icon: Icons.event_available_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Consumer Care',
            value: info.consumerCare,
            icon: Icons.contact_support_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Country of Origin',
            value: info.countryOfOrigin,
            icon: Icons.public_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Batch Number',
            value: info.batchNumber,
            icon: Icons.tag_outlined,
          ),
          _infoRow(
            context: context,
            label: 'Language Used',
            value: info.languageUsed,
            icon: Icons.translate_outlined,
          ),
        ],
      ),
    );
  }

  String _statusLabel(ComplianceStatus s) {
    switch (s) {
      case ComplianceStatus.pass:
        return 'COMPLIANT';
      case ComplianceStatus.fail:
        return 'NON-COMPLIANT';
      case ComplianceStatus.review:
        return 'MANUAL REVIEW';
    }
  }

  Widget _buildInspectionHistory(BuildContext context) {
    final errorWidget = (_historyError != null && !_historyLoading)
        ? [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.reviewOrangeLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.reviewOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: AppTheme.reviewOrange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _historyError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.reviewOrange,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        : const <Widget>[];
    final list = _historyLoading || _history.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  _historyLoading
                      ? 'Loading history...'
                      : 'No previous inspections saved.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ]
        : _history.map((row) {
            final s = row.status;
            final statusLabel = _statusLabel(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openHistoryItem(row),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            s.icon,
                            size: 20,
                            color: s.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                row.productName.isEmpty
                                    ? 'Product label inspection'
                                    : row.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(row.date),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(
                              status: s,
                              showIcon: false,
                              large: false,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Inspection History',
            subtitle:
                'Tap an inspection to reopen the report and regenerate its PDF.',
          ),
          const SizedBox(height: 8),
          ...errorWidget,
          ...list,
        ],
      ),
    );
  }

  Widget _buildComplianceSummary(
    BuildContext context,
    ComplianceStatus status,
    String statusLabel,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Compliance Summary'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: status.lightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: status.color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    status.icon,
                    color: status.color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Status',
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCounter(
                  context,
                  AppTheme.passGreen,
                  AppTheme.passGreenLight,
                  'Passed',
                  _inspection.passedCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCounter(
                  context,
                  AppTheme.reviewOrange,
                  AppTheme.reviewOrangeLight,
                  'Review',
                  _inspection.reviewCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCounter(
                  context,
                  AppTheme.failRed,
                  AppTheme.failRedLight,
                  'Failed',
                  _inspection.failedCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCounter(
    BuildContext context,
    Color color,
    Color bgColor,
    String label,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceChecks(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Compliance Checks'),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Rule / Requirement',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Status',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppTheme.dividerColor),
                            ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            check.ruleName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: StatusBadge(
                              status: check.status,
                              showIcon: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.failRed.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.failRedLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dangerous_outlined,
                  color: AppTheme.failRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Violations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        letterSpacing: -0.2,
                        color: AppTheme.failRed,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._inspection.violations.asMap().entries.map((e) {
            final violation = e.value;
            return Padding(
              padding: EdgeInsets.only(top: e.key == 0 ? 0 : 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.failRedLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.failRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cancel,
                          color: AppTheme.failRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            violation.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.failRed,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBlock(
                      context: context,
                      label: 'Requirement',
                      value: violation.requirement,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBlock(
                      context: context,
                      label: 'Status',
                      value: violation.status,
                      valueColor: AppTheme.failRed,
                      valueBold: true,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBlock(
                      context: context,
                      label: 'Evidence',
                      value: violation.evidenceNote,
                      icon: Icons.photo_size_select_actual_outlined,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoBlock({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
    bool valueBold = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                style: valueBold
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: valueColor ?? AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        )
                    : Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: valueColor ?? AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualVerification(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Manual Verification'),
          Text(
            '${_inspection.complianceChecks.where((c) => c.isChecked).length}/${_inspection.complianceChecks.length} checks confirmed by the operator.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          ..._inspection.complianceChecks.map(
            (check) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    check.isChecked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: check.isChecked
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(check.ruleName)),
                  StatusBadge(status: check.status, showIcon: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorVerification(
    BuildContext context,
    ComplianceStatus status,
    String statusLabel,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Inspector Verification'),
          const SizedBox(height: 8),
          _buildVerificationStep(
            context,
            title: 'AI Analysis Completed',
            subtitle: '${_inspection.extractedFields.length} fields extracted via OCR',
            completed: true,
          ),
          const SizedBox(height: 10),
          _buildVerificationStep(
            context,
            title: 'Manual Verification Completed',
            subtitle:
                '${_inspection.complianceChecks.where((c) => c.isChecked).length}/${_inspection.complianceChecks.length} compliance checks verified',
            completed: true,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Decision',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: status.lightColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool completed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? AppTheme.passGreenLight : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: completed ? AppTheme.passGreen : AppTheme.cardBorder,
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : Icons.hourglass_empty,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: completed
                            ? AppTheme.passGreen
                            : AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
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
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppTheme.cardBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_outlined, size: 16),
                      label: const Text('Back', overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasInspection ? _saveInspectionToDb : null,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text(
                        'Save Report',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _hasInspection
                      ? () {
                          InspectionSession.instance.save(_inspection);
                          Navigator.pushNamed(context, '/pdf-preview');
                        }
                      : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppTheme.failRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
