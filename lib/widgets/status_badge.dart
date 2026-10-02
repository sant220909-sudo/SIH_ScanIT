import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ComplianceStatus status;
  final bool showIcon;
  final bool large;

  const StatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.large = false,
  });

  factory StatusBadge.fromLabel({
    Key? key,
    required String label,
    bool showIcon = true,
    bool large = false,
  }) {
    ComplianceStatus status;
    switch (label.toUpperCase()) {
      case 'PASS':
      case 'COMPLIANT':
        status = ComplianceStatus.pass;
        break;
      case 'FAIL':
      case 'NON-COMPLIANT':
        status = ComplianceStatus.fail;
        break;
      case 'REVIEW':
      case 'MANUAL REVIEW':
      default:
        status = ComplianceStatus.review;
    }
    return StatusBadge(
      key: key,
      status: status,
      showIcon: showIcon,
      large: large,
    );
  }

  String get _displayLabel {
    switch (status) {
      case ComplianceStatus.pass:
        return 'PASS';
      case ComplianceStatus.fail:
        return 'FAIL';
      case ComplianceStatus.review:
        return 'MANUAL REVIEW';
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        large ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final fontSize = large ? 15.0 : 12.0;
    final iconSize = large ? 20.0 : 14.0;
    final radius = large ? 10.0 : 6.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: status.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              status.icon,
              color: status.color,
              size: iconSize,
            ),
            SizedBox(width: large ? 8 : 5),
          ],
          Text(
            _displayLabel,
            style: TextStyle(
              color: status.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
