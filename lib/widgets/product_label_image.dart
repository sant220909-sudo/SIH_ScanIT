import 'package:flutter/material.dart';
import 'package:cyber_nova/config/app_config.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class ProductLabelImage extends StatelessWidget {
  final InspectionModel inspection;
  final double height;

  const ProductLabelImage({
    super.key,
    required this.inspection,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (inspection.sampleAssetMissing) {
      return _placeholder(
        AppConfig.sampleMissingMessage,
        icon: Icons.image_not_supported_outlined,
      );
    }

    if (inspection.imageBytes != null && inspection.imageBytes!.isNotEmpty) {
      return Image.memory(
        inspection.imageBytes!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(
          'Unable to display the product image.',
        ),
      );
    }

    if (inspection.useSampleAsset) {
      return Image.asset(
        AppConfig.sampleAssetPath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(
          AppConfig.sampleMissingMessage,
        ),
      );
    }

    return _placeholder('Product label image');
  }

  Widget _placeholder(String message, {IconData icon = Icons.image_outlined}) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 44,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
