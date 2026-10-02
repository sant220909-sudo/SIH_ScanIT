import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/screens/analysis_screen.dart';
import 'package:cyber_nova/screens/report_screen.dart';
import 'package:cyber_nova/services/inspection_db.dart';
import 'package:cyber_nova/services/api_service.dart';
import 'package:cyber_nova/services/inspection_session.dart';
import 'package:cyber_nova/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();
  bool _cameraAvailable = true;
  final List<ProductImage> _selectedImages = <ProductImage>[];
  List<RecentReport> _recentReports = const [];
  bool _loadingRecent = true;
  bool _recentIsBackend = false;

  @override
  void initState() {
    super.initState();
    _loadRecentReports();
  }

  Future<void> _loadRecentReports() async {
    if (!mounted) return;
    setState(() => _loadingRecent = true);
    try {
      final backend = await _api.listInspections(limit: 5);
      if (!mounted) return;
      setState(() {
        _recentReports = backend;
        _loadingRecent = false;
        _recentIsBackend = true;
      });
      return;
    } catch (_) {
      try {
        final rows = await InspectionDb.instance.listRecent(limit: 5);
        if (!mounted) return;
        setState(() {
          _recentReports = rows;
          _loadingRecent = false;
          _recentIsBackend = false;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingRecent = false;
          _recentIsBackend = false;
        });
      }
    }
  }

  Future<void> _openAnalysis(ScanRequest request) async {
    if (!mounted) return;
    await Navigator.pushNamed(context, '/analysis', arguments: request);
    if (mounted) _loadRecentReports();
  }

  void _addImage({
    required Uint8List bytes,
    required String filename,
    required ScanSource source,
  }) {
    setState(() {
      _selectedImages.add(
        ProductImage(
          bytes: bytes,
          filename: filename,
          source: source,
          index: _selectedImages.length + 1,
        ),
      );
    });
  }

  void _removeImageAt(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      for (var i = index; i < _selectedImages.length; i++) {
        final old = _selectedImages[i];
        _selectedImages[i] = ProductImage(
          bytes: old.bytes,
          filename: old.filename,
          source: old.source,
          index: i + 1,
        );
      }
    });
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 98,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _addImage(
        bytes: bytes,
        filename: file.name,
        source: ScanSource.gallery,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to select an image. Please try again.'),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 98,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _addImage(
        bytes: bytes,
        filename: file.name,
        source: ScanSource.camera,
      );
    } on PlatformException {
      setState(() => _cameraAvailable = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to access the camera.')),
      );
    } catch (_) {
      setState(() => _cameraAvailable = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to take a photo. Please try again.')),
      );
    }
  }

  Future<void> _showAddPhotoOptions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Another Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture or upload another side of the package.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cameraAvailable
                      ? () {
                          Navigator.pop(sheetCtx);
                          _takePhoto();
                        }
                      : null,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text('Scan Product from Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.passGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _pickFromGallery();
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Select Photo from Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _analyzeProduct() {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product image.'),
          backgroundColor: AppTheme.failRed,
        ),
      );
      return;
    }
    _openAnalysis(
      ScanRequest(
        source: _selectedImages.first.source,
        productImages: List.unmodifiable(_selectedImages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildScanCard(context),
              const SizedBox(height: 32),
              _buildRecentReports(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cyber Nova',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: -0.4,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SIH 2026',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Legal Metrology Compliance',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 22,
                letterSpacing: -0.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI-powered packaged product label inspection',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
        ),
      ],
    );
  }

  Widget _buildScanCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Scan Product Label',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Capture or upload product label images to check mandatory declarations and verify compliance with Legal Metrology rules.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.6,
                    fontSize: 14,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            context,
            icon: Icons.photo_camera_rounded,
            label: 'Scan Product from Camera',
            filled: true,
            color: AppTheme.passGreen,
            onPressed: _cameraAvailable ? _takePhoto : null,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            icon: Icons.photo_library_rounded,
            label: 'Select Photo from Gallery',
            filled: false,
            color: AppTheme.primaryColor,
            onPressed: _pickFromGallery,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Add multiple photos if different sides of the package contain different information.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontSize: 12,
                  ),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildThumbnailSection(context),
          ],
          const SizedBox(height: 24),
          if (_selectedImages.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddPhotoOptions,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: const Text('Add Another Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
          if (_selectedImages.isNotEmpty) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedImages.isNotEmpty ? _analyzeProduct : null,
              icon: const Icon(Icons.analytics_outlined, size: 20),
              label: const Text('Analyze Product'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: AppTheme.cardBorder,
                disabledForegroundColor: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool filled,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final content = Row(
      children: [
        Icon(icon, color: filled ? Colors.white : color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: filled
              ? BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildThumbnailSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos Added',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedImages.length}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _selectedImages.asMap().entries.map((entry) {
            final idx = entry.key;
            final img = entry.value;
            return SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      img.bytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${img.index}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _removeImageAt(idx),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppTheme.failRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _openRecentReport(RecentReport report) async {
    InspectionModel? full;
    if (_recentIsBackend || report.id.startsWith('CN-')) {
      try {
        full = await _api.getInspection(report.id);
      } catch (_) {
        full = null;
      }
    }
    full ??= await InspectionDb.instance.getFullInspection(report.id);
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load saved inspection.')),
      );
      return;
    }
    InspectionSession.instance.save(full);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportScreen()),
    );
    if (mounted) _loadRecentReports();
  }

  Widget _buildRecentReports(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Inspections',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: -0.2,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportScreen()),
                );
                if (mounted) _loadRecentReports();
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_loadingRecent)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_recentReports.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 28),
                const SizedBox(height: 8),
                Text(
                  'No inspections yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan a product label to save your first report.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._recentReports.asMap().entries.map((e) {
            final report = e.value;
            return Padding(
              padding: EdgeInsets.only(top: e.key == 0 ? 0 : 10),
              child: _buildRecentReportCard(context, report),
            );
          }),
      ],
    );
  }

  Widget _buildRecentReportCard(BuildContext context, RecentReport report) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRecentReport(report),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.id}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.productName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${report.formattedDate}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: report.status, showIcon: true),
            ],
          ),
        ),
      ),
    );
  }
}
