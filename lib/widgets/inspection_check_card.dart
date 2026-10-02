import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/widgets/status_badge.dart';

class InspectionCheckCard extends StatelessWidget {
  final ComplianceCheck check;
  final bool isChecked;
  final ValueChanged<bool?>? onCheckboxChanged;
  final VoidCallback? onStatusTap;
  final ValueChanged<ComplianceStatus>? onStatusSelected;

  const InspectionCheckCard({
    super.key,
    required this.check,
    required this.isChecked,
    this.onCheckboxChanged,
    this.onStatusTap,
    this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onStatusTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isChecked,
                        onChanged: onCheckboxChanged,
                        activeColor: AppTheme.primaryColor,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check.ruleName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                          ),
                          if (check.ruleReference.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              check.ruleReference,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.15,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            check.description,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge(status: check.status, showIcon: true),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip('PASS', ComplianceStatus.pass, AppTheme.passGreen),
                _statusChip('FAIL', ComplianceStatus.fail, AppTheme.failRed),
                _statusChip(
                  'REVIEW',
                  ComplianceStatus.review,
                  AppTheme.reviewOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, ComplianceStatus status, Color color) {
    final selected = check.status == status;
    return InkWell(
      onTap: () => onStatusSelected?.call(status),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
