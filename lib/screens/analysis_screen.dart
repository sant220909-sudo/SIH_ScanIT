import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cyber_nova/config/app_config.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/services/api_service.dart';
import 'package:cyber_nova/services/inspection_session.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/widgets/information_card.dart';
import 'package:cyber_nova/widgets/inspection_check_card.dart';
import 'package:cyber_nova/widgets/legal_disclaimer.dart';
import 'package:cyber_nova/widgets/product_label_image.dart';
import 'package:cyber_nova/widgets/section_title.dart';

class ScanRequest {
  final ScanSource source;
  final List<ProductImage> productImages;
  final bool useSampleAsset;
  final bool sampleAssetMissing;

  const ScanRequest({
    required this.source,
    this.productImages = const [],
    this.useSampleAsset = false,
    this.sampleAssetMissing = false,
  });
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _api = ApiService();
  late InspectionModel _inspection;
  ScanRequest? _request;
  bool _started = false;
  bool _isAnalyzing = false;
  bool _analysisFailed = false;
  bool _backendUnavailable = false;
  String? _errorMessage;

  final List<bool> _sectionExpanded = <bool>[
    true,
    true,
    false,
    false,
    false,
    false,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _request = args is ScanRequest ? args : null;
    _inspection = InspectionModel.empty(
      productImages: _request?.productImages ?? const [],
      useSampleAsset: _request?.useSampleAsset ?? false,
      sampleAssetMissing: _request?.sampleAssetMissing ?? false,
    );
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final request = _request;
    if (request == null) {
      setState(() {
        _isAnalyzing = false;
        _analysisFailed = true;
        _errorMessage = 'Please add at least one product image.';
      });
      return;
    }
    if (request.sampleAssetMissing) {
      setState(() {
        _isAnalyzing = false;
        _analysisFailed = true;
        _inspection.sampleAssetMissing = true;
        _errorMessage = AppConfig.sampleMissingMessage;
      });
      return;
    }
    if (request.productImages.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _analysisFailed = true;
        _errorMessage = 'Please add at least one product image.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisFailed = false;
      _backendUnavailable = false;
      _errorMessage = null;
    });

    try {
      final result = await _api.scanLabelMulti(
        productImages: request.productImages,
        useSampleAsset: request.useSampleAsset,
      );
      if (!mounted) return;
      setState(() {
        _inspection = result;
        _isAnalyzing = false;
        InspectionSession.instance.save(_inspection);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisFailed = true;
        _backendUnavailable = error.backendUnavailable;
        _errorMessage = error.backendUnavailable
            ? 'Unable to connect to the inspection service. Please try again.'
            : (error.userMessage.isEmpty
                ? 'AI analysis could not be completed. Please try again.'
                : error.userMessage);
      });
    }
  }

  void _onFieldChanged(String fieldId, String newValue) {
    setState(() {
      final idx =
          _inspection.extractedFields.indexWhere((f) => f.id == fieldId);
      if (idx != -1) {
        _inspection.extractedFields[idx] =
            _inspection.extractedFields[idx].copyWith(value: newValue);
        _inspection.syncProductInfoFromFields();
        InspectionSession.instance.save(_inspection);
      }
    });
  }

  void _onCheckboxChanged(String checkId, bool? value) {
    setState(() {
      final idx =
          _inspection.complianceChecks.indexWhere((c) => c.id == checkId);
      if (idx != -1) {
        _inspection.complianceChecks[idx] =
            _inspection.complianceChecks[idx].copyWith(
          isChecked: value ?? false,
          status: (value ?? false)
              ? _inspection.complianceChecks[idx].status
              : ComplianceStatus.review,
        );
        _inspection.rebuildViolations();
        InspectionSession.instance.save(_inspection);
      }
    });
  }

  void _onCheckStatusTap(String checkId) {
    setState(() {
      final idx =
          _inspection.complianceChecks.indexWhere((c) => c.id == checkId);
      if (idx != -1) {
        final current = _inspection.complianceChecks[idx].status;
        ComplianceStatus next;
        switch (current) {
          case ComplianceStatus.pass:
            next = ComplianceStatus.review;
            break;
          case ComplianceStatus.review:
            next = ComplianceStatus.fail;
            break;
          case ComplianceStatus.fail:
            next = ComplianceStatus.pass;
            break;
        }
        _setCheckStatus(idx, next);
      }
    });
  }

  void _onStatusSelected(String checkId, ComplianceStatus status) {
    setState(() {
      final idx =
          _inspection.complianceChecks.indexWhere((c) => c.id == checkId);
      if (idx != -1) {
        _setCheckStatus(idx, status);
      }
    });
  }

  void _setCheckStatus(int idx, ComplianceStatus next) {
    _inspection.complianceChecks[idx] =
        _inspection.complianceChecks[idx].copyWith(
      status: next,
      isChecked: true,
    );
    _inspection.rebuildViolations();
    InspectionSession.instance.save(_inspection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Label Analysis'),
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
                  _buildProductImage(context),
                  const SizedBox(height: 20),
                  if (_analysisFailed) _buildErrorCard(context),
                  if (!_analysisFailed) ...[
                    _buildAnalysisStatusHeader(context),
                    const SizedBox(height: 24),
                    if (_inspection.aiAnalysisComplete) ...[
                      _buildExtractedInformation(context),
                      const SizedBox(height: 28),
                      _buildManualVerification(context),
                      const SizedBox(height: 28),
                      _buildOverallCompliance(context),
                      const SizedBox(height: 16),
                      const LegalDisclaimerNote(),
                    ],
                  ],
                ],
              ),
            ),
          ),
          _buildBottomButton(context),
          if (_isAnalyzing) _buildAnalysisOverlay(),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.failRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _backendUnavailable
                ? 'Service unavailable'
                : 'Analysis failed',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.failRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                'AI analysis could not be completed. Please try again.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _runAnalysis,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            ProductLabelImage(inspection: _inspection, height: 220),
            Positioned(
              top: 12,
              right: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_outline,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _inspection.imageCount > 1
                              ? 'Product Labels'
                              : 'Product Label',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_inspection.imageCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '${_inspection.imageCount} Photos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  Widget _buildAnalysisStatusHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _isAnalyzing ? Colors.amber : AppTheme.passGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _isAnalyzing ? 'AI Analysis In Progress...' : 'AI Analysis Complete',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color:
                    _isAnalyzing ? Colors.amber.shade800 : AppTheme.passGreen,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
        const Spacer(),
        if (!_isAnalyzing && _inspection.aiAnalysisComplete)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.passGreenLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_inspection.extractedFields.length} fields extracted',
              style: const TextStyle(
                color: AppTheme.passGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  ExtractedField? _fieldById(String id) {
    final idx = _inspection.extractedFields.indexWhere((f) => f.id == id);
    if (idx == -1) return null;
    final f = _inspection.extractedFields[idx];
    if (f.value.trim().isEmpty && (f.exactVisibleText ?? '').trim().isEmpty) {
      return null;
    }
    return f;
  }

  List<Widget> _fieldCards(List<String> ids) {
    final out = <Widget>[];
    for (final id in ids) {
      final f = _fieldById(id);
      if (f == null) continue;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InformationCard(
            field: f,
            onChanged: (val) => _onFieldChanged(f.id, val),
          ),
        ),
      );
    }
    return out;
  }

  Widget _complianceFindingCard({
    required String title,
    required ComplianceCheck? check,
    required String fallbackPass,
  }) {
    String status;
    String body;
    String? exact;
    Color chipColor;
    Color chipText;
    if (check == null) {
      status = 'PASS';
      body = fallbackPass;
      exact = null;
      chipColor = AppTheme.passGreenLight;
      chipText = AppTheme.passGreen;
    } else {
      status = check.status.name.toUpperCase();
      body = check.reason.isNotEmpty ? check.reason : check.description;
      exact = (check.exactVisibleText ?? '').trim().isNotEmpty
          ? check.exactVisibleText
          : null;
      switch (check.status) {
        case ComplianceStatus.pass:
          chipColor = AppTheme.passGreenLight;
          chipText = AppTheme.passGreen;
          break;
        case ComplianceStatus.fail:
          chipColor = AppTheme.failRedLight;
          chipText = AppTheme.failRed;
          break;
        case ComplianceStatus.review:
          chipColor = AppTheme.reviewAmberLight;
          chipText = AppTheme.reviewAmber;
          break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: chipText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (exact != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.cardBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '"$exact"',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required int index,
    required String title,
    required List<Widget> children,
    IconData? trailingIcon,
  }) {
    if (children.isEmpty && trailingIcon == null) {
      return const SizedBox.shrink();
    }
    final expanded = _sectionExpanded[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _sectionExpanded[index] = !_sectionExpanded[index];
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          Icon(
                            trailingIcon,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: expanded ? 0.5 : 0.0,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedInformation(BuildContext context) {
    final misleadingCheck = _inspection.complianceChecks
        .where((c) => c.id == 'LM-009')
        .firstOrNull;
    final nonStandardCheck = _inspection.complianceChecks
        .where((c) => c.id == 'LM-012')
        .firstOrNull;

    final productCards = _fieldCards([
      'product_name',
      'common_name',
      'manufacturer',
      'packer',
      'importer',
      'address',
    ]);
    final qtyCards = _fieldCards([
      'net_quantity',
      'mrp',
      'currency',
      'unit_sale_price',
      'dimensions_size',
    ]);
    final dateCards = _fieldCards([
      'packing_date',
      'best_before',
    ]);
    final consumerCards = _fieldCards([
      'consumer_care',
      'country_of_origin',
    ]);
    final idCards = _fieldCards([
      'batch_number',
      'language_used',
      'language_of_declarations',
    ]);
    final complianceChildren = <Widget>[
      _complianceFindingCard(
        title: 'Misleading / Vague Quantity Expressions',
        check: misleadingCheck,
        fallbackPass:
            'No prohibited qualifying words were detected adjacent to the net quantity declaration.',
      ),
      _complianceFindingCard(
        title: 'Non-Standard Declarations / Units',
        check: nonStandardCheck,
        fallbackPass:
            'Net quantity declaration appears to use a standard weight/measure/number unit consistent with Rule 13.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Extracted Information',
          subtitle:
              'AI-extracted label data grouped by section. Tap any card to edit.',
        ),
        const SizedBox(height: 8),
        _buildSection(
          index: 0,
          title: 'PRODUCT INFORMATION',
          children: productCards,
          trailingIcon: productCards.isEmpty ? null : Icons.info_outline,
        ),
        _buildSection(
          index: 1,
          title: 'QUANTITY & PRICING',
          children: qtyCards,
          trailingIcon: qtyCards.isEmpty ? null : Icons.price_change_outlined,
        ),
        _buildSection(
          index: 2,
          title: 'DATES & VALIDITY',
          children: dateCards,
          trailingIcon: dateCards.isEmpty ? null : Icons.calendar_month_outlined,
        ),
        _buildSection(
          index: 3,
          title: 'CONSUMER INFORMATION',
          children: consumerCards,
          trailingIcon: consumerCards.isEmpty ? null : Icons.contact_support_outlined,
        ),
        _buildSection(
          index: 4,
          title: 'IDENTIFICATION & DECLARATIONS',
          children: idCards,
          trailingIcon: idCards.isEmpty ? null : Icons.badge_outlined,
        ),
        _buildSection(
          index: 5,
          title: 'COMPLIANCE FINDINGS',
          children: complianceChildren,
          trailingIcon: Icons.verified_user_outlined,
        ),
      ],
    );
  }

  Widget _buildManualVerification(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Manual Verification',
          subtitle:
              'Review the AI results before submitting the inspection.',
        ),
        ..._inspection.complianceChecks.asMap().entries.map((e) {
          final check = e.value;
          return Padding(
            padding: EdgeInsets.only(top: e.key == 0 ? 0 : 10),
            child: InspectionCheckCard(
              check: check,
              isChecked: check.isChecked,
              onCheckboxChanged: (val) => _onCheckboxChanged(check.id, val),
              onStatusTap: () => _onCheckStatusTap(check.id),
              onStatusSelected: (status) =>
                  _onStatusSelected(check.id, status),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOverallCompliance(BuildContext context) {
    final status = _inspection.overallStatus;
    final statusLabel = _inspection.overallStatusLabel;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Compliance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: status.lightColor,
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
                      statusLabel,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: status.color,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                                fontSize: 26,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${_inspection.complianceChecks.where((c) => c.isChecked).length} verified checks',
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
          const SizedBox(height: 16),
          const Divider(height: 1),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
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

  Widget _buildBottomButton(BuildContext context) {
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isAnalyzing ||
                      !_inspection.aiAnalysisComplete ||
                      _analysisFailed)
                  ? null
                  : () {
                      setState(() {
                        _inspection.manualVerificationComplete = true;
                      });
                      InspectionSession.instance.save(_inspection);
                      Navigator.pushNamed(context, '/report');
                    },
              icon: const Icon(Icons.assignment_outlined, size: 20),
              label: const Text('Generate Inspection Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: AppTheme.cardBorder,
                disabledForegroundColor: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Analyzing Labels...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _request != null && _request!.productImages.length > 1
                    ? 'Processing ${_request!.productImages.length} product photos through Cyber Nova AI pipeline'
                    : 'Processing product photo through Cyber Nova AI pipeline',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
