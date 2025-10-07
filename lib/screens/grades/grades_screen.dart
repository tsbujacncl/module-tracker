import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/screens/grades/module_grade_card.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(currentSemesterModulesProvider);
    final semesterAverage = ref.watch(semesterAverageProvider);
    final overallAverage = ref.watch(overallAverageProvider);
    final totalCredits = ref.watch(totalCreditsEarnedProvider);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
          ).createShader(bounds),
          child: Text(
            'Grades',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: modulesAsync.when(
        data: (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.grade_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No modules yet',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add modules to track your grades',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Semester summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B5CF6),
                        const Color(0xFF7C3AED),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Semester Overview',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryItem(
                            label: 'Semester',
                            value: '${semesterAverage.toStringAsFixed(1)}%',
                            icon: Icons.school,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _SummaryItem(
                            label: 'Overall',
                            value: '${overallAverage.toStringAsFixed(1)}%',
                            icon: Icons.trending_up,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _SummaryItem(
                            label: 'Credits',
                            value: '$totalCredits/360',
                            icon: Icons.star,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Module grades list
                Text(
                  'Module Grades',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...modules.map((module) {
                  final moduleGrade = ref.watch(moduleGradeProvider(module.id));
                  final gradeStatus = ref.watch(moduleGradeStatusProvider(module.id));

                  if (moduleGrade == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ModuleGradeCard(
                      module: module,
                      moduleGrade: moduleGrade,
                      gradeStatus: gradeStatus,
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading grades: $error'),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}
