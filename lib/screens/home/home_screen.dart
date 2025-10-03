import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart' show AssignmentsScreen;
import 'package:module_tracker/screens/grades/grades_screen.dart';
import 'package:module_tracker/screens/settings/settings_screen.dart';
import 'package:module_tracker/screens/semester/semester_archive_screen.dart';
import 'package:module_tracker/widgets/module_card.dart';
import 'package:module_tracker/widgets/week_navigation_bar.dart';
import 'package:module_tracker/widgets/weekly_calendar.dart';
import 'package:module_tracker/widgets/shared/empty_state.dart';
import 'package:module_tracker/widgets/shared/app_loading_indicator.dart';
import 'package:module_tracker/widgets/shared/app_error_state.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);
    final selectedWeek = ref.watch(selectedWeekNumberProvider);

    print('DEBUG HOME: Building HomeScreen, semesters state: ${semestersAsync.runtimeType}');

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
          ).createShader(bounds),
          child: Text(
            'Module Tracker',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF10B981)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModuleFormScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assessment_outlined, size: 20, color: Color(0xFF8B5CF6)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AssignmentsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grade_outlined, size: 20, color: Color(0xFF0EA5E9)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GradesScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_outlined, size: 20, color: Color(0xFFF59E0B)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SemesterArchiveScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_outlined, size: 20, color: Color(0xFF0EA5E9)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: semestersAsync.when(
          data: (semesters) {
            print('DEBUG HOME: Semesters data received - count: ${semesters.length}');
            if (semesters.isEmpty) {
              print('DEBUG HOME: No semesters found, showing empty state');
              // No semester setup yet - show add module button
              return EmptyState(
                icon: Icons.school_rounded,
                title: 'No Modules Yet',
                message: 'Add your first module to get started',
                actionText: 'Add Module',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ModuleFormScreen(),
                    ),
                  );
                },
              );
            }

          // Semester exists, show calendar and modules
          print('DEBUG HOME: Semester found: ${semesters.first.name}, ID: ${semesters.first.id}');
          final semester = semesters.first;
          final modulesAsync = ref.watch(currentSemesterModulesProvider);
          final tasksAsync = ref.watch(allCurrentSemesterTasksProvider);

          return modulesAsync.when(
            data: (modules) {
              print('DEBUG HOME: Modules data received - count: ${modules.length}');
              if (modules.isEmpty) {
                print('DEBUG HOME: No modules found for semester, showing empty state');
                return const EmptyStateCompact(
                  icon: Icons.school,
                  title: 'No Modules Yet',
                  message: 'Add your first module to start tracking',
                );
              }

              return tasksAsync.when(
                data: (tasksByModule) {
                  // Fetch assessments for all modules
                  final assessmentsByModule = <String, List<Assessment>>{};
                  for (final module in modules) {
                    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
                    assessmentsAsync.whenData((assessments) {
                      assessmentsByModule[module.id] = assessments;
                    });
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(currentSemesterModulesProvider);
                      ref.invalidate(allCurrentSemesterTasksProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Week navigation bar
                        WeekNavigationBar(
                          semester: semester,
                          currentWeek: selectedWeek,
                          onWeekChanged: (week) {
                            ref.read(selectedWeekNumberProvider.notifier).state = week;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Weekly Calendar
                        WeeklyCalendar(
                          semester: semester,
                          currentWeek: selectedWeek,
                          modules: modules,
                          tasksByModule: tasksByModule,
                          assessmentsByModule: assessmentsByModule,
                        ),
                        const SizedBox(height: 24),
                        // Module Cards Section
                        Text(
                          'This Week\'s Tasks',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Sort modules by code alphabetically/numerically
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: () {
                              final sortedModules = [...modules]
                                ..sort((a, b) => a.code.compareTo(b.code));
                              return sortedModules.map((module) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ModuleCard(
                                      module: module,
                                      weekNumber: selectedWeek,
                                    ),
                                  ),
                                );
                              }).toList();
                            }(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const AppLoadingIndicator(
                  message: 'Loading tasks...',
                ),
                error: (error, stack) => AppErrorState(
                  message: error.toString(),
                  onRetry: () {
                    ref.invalidate(allCurrentSemesterTasksProvider);
                  },
                ),
              );
            },
            loading: () => const AppLoadingIndicator(
              message: 'Loading modules...',
            ),
            error: (error, stack) => AppErrorState(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(currentSemesterModulesProvider);
              },
            ),
          );
          },
          loading: () => const AppLoadingIndicator(
            message: 'Loading semester...',
          ),
          error: (error, stack) => AppErrorState(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(semestersProvider);
            },
          ),
        ),
    );
  }
}