import 'package:flutter/material.dart';
import 'package:cyber_nova/utils/app_theme.dart';
import 'package:cyber_nova/models/inspection_model.dart';

class InformationCard extends StatefulWidget {
  final ExtractedField field;
  final ValueChanged<String>? onChanged;

  const InformationCard({
    super.key,
    required this.field,
    this.onChanged,
  });

  @override
  State<InformationCard> createState() => _InformationCardState();
}

class _InformationCardState extends State<InformationCard> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.field.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant InformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.value != widget.field.value && !_isEditing) {
      _controller.text = widget.field.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confidenceColor = widget.field.confidence >= 85
        ? AppTheme.passGreen
        : widget.field.confidence >= 60
            ? AppTheme.reviewOrange
            : AppTheme.failRed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.field.fieldName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_isEditing) {
                      _isEditing = false;
                      widget.onChanged?.call(_controller.text);
                    } else {
                      _isEditing = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _focusNode.requestFocus();
                      });
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _isEditing ? Icons.check : Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isEditing)
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            )
          else
            Text(
              widget.field.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 12,
                      color: confidenceColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Confidence: ${widget.field.confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: confidenceColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
