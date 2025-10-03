import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class WhatIfCalculator extends ConsumerStatefulWidget {
  final Module module;
  final ModuleGrade moduleGrade;

  const WhatIfCalculator({
    super.key,
    required this.module,
    required this.moduleGrade,
  });

  @override
  ConsumerState<WhatIfCalculator> createState() => _WhatIfCalculatorState();
}

class _WhatIfCalculatorState extends ConsumerState<WhatIfCalculator> {
  late TextEditingController _targetGradeController;
  double? _requiredGrade;

  @override
  void initState() {
    super.initState();
    _targetGradeController = TextEditingController(text: '70.0');
    _calculateRequiredGrade();
  }

  @override
  void dispose() {
    _targetGradeController.dispose();
    super.dispose();
  }

  void _calculateRequiredGrade() {
    final targetGrade = double.tryParse(_targetGradeController.text);
    if (targetGrade == null) {
      setState(() => _requiredGrade = null);
      return;
    }

    final assessmentsAsync = ref.read(assessmentsProvider(widget.module.id));
    final assessments = assessmentsAsync.value ?? [];

    final required = GradeCalculator.calculateRequiredGrade(
      assessments,
      targetGrade,
    );

    setState(() => _requiredGrade = required);
  }

  Color _getResultColor() {
    if (_requiredGrade == null) return Colors.grey;
    if (_requiredGrade! <= 50) return const Color(0xFF10B981); // Green - Easy
    if (_requiredGrade! <= 70) return const Color(0xFF3B82F6); // Blue - Moderate
    if (_requiredGrade! <= 85) return const Color(0xFFF59E0B); // Orange - Challenging
    if (_requiredGrade! <= 100) return const Color(0xFFEF4444); // Red - Difficult
    return const Color(0xFF7F1D1D); // Dark red - Impossible
  }

  String _getResultMessage() {
    if (_requiredGrade == null) return '';
    if (_requiredGrade! <= 50) {
      return 'Very achievable! You\'re doing great.';
    } else if (_requiredGrade! <= 70) {
      return 'Achievable with steady effort.';
    } else if (_requiredGrade! <= 85) {
      return 'Challenging but possible.';
    } else if (_requiredGrade! <= 100) {
      return 'Very challenging. You\'ll need to excel.';
    } else {
      return 'Target not achievable. Consider adjusting your goal.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppBorderRadius.xl),
          topRight: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What-If Calculator',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.module.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDarkMode
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Current status
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFF8FAFC))
                  ,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(
                  label: 'Current',
                  value: '${widget.moduleGrade.currentGrade.toStringAsFixed(1)}%',
                ),
                _InfoItem(
                  label: 'Completed',
                  value:
                      '${widget.moduleGrade.completedAssessments}/${widget.moduleGrade.totalAssessments}',
                ),
                _InfoItem(
                  label: 'Remaining',
                  value: '${(100 - widget.moduleGrade.currentWeightage).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Target grade input
          Text(
            'Target Final Grade',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _targetGradeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter target grade (e.g., 70)',
              suffixText: '%',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFF8FAFC),
            ),
            onChanged: (_) => _calculateRequiredGrade(),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Result
          if (_requiredGrade != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: _getResultColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: Border.all(
                  color: _getResultColor().withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Required Average',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _getResultColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_requiredGrade!.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _getResultColor(),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _getResultMessage(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _getResultColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Scenarios
            Text(
              'Common Scenarios',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScenarioButton(
              label: 'First Class (70%)',
              value: '70',
              onTap: () {
                _targetGradeController.text = '70';
                _calculateRequiredGrade();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _ScenarioButton(
              label: 'Upper Second (60%)',
              value: '60',
              onTap: () {
                _targetGradeController.text = '60';
                _calculateRequiredGrade();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _ScenarioButton(
              label: 'Pass (40%)',
              value: '40',
              onTap: () {
                _targetGradeController.text = '40';
                _calculateRequiredGrade();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ScenarioButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF475569)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: isDarkMode
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
