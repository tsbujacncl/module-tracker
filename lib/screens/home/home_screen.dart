import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
import 'package:module_tracker/screens/grades/grades_screen.dart';
import 'package:module_tracker/screens/settings/settings_screen.dart';
import 'package:module_tracker/screens/semester/semester_archive_screen.dart';
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
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
    final selectedSemester = ref.watch(selectedSemesterProvider);
    final selectedWeek = ref.watch(selectedWeekNumberProvider);

    print(
      'DEBUG HOME: Building HomeScreen, semesters state: ${semestersAsync.runtimeType}',
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile =
        screenWidth < 600; // Increased threshold to catch more devices
    print('DEBUG: Screen width: $screenWidth, isMobile: $isMobile');

    // Dynamic scaling based on screen width - balanced approach
    final scaleFactor = screenWidth < 360
        ? 0.8  // Very small screens: reduce slightly
        : screenWidth < 380
            ? 0.9  // Small screens (e.g., iPhone SE): moderate reduction
            : screenWidth < 420
                ? 0.95 // Medium-small screens: slight reduction
                : 1.0; // Normal and larger screens: full size

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: kToolbarHeight * 1.1, // 10% taller (not too much)
              flexibleSpace: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      // Logo on left - balanced size
                      GestureDetector(
                        onTap: () {
                          ref.read(selectedWeekStartDateProvider.notifier).state =
                              ref.read(currentWeekStartDateProvider);
                        },
                        child: Container(
                          width: 40 * scaleFactor,
                          height: 40 * scaleFactor,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(9 * scaleFactor),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: 23 * scaleFactor,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Title next to logo - dynamically sized
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF0EA5E9),
                              Color(0xFF06B6D4),
                              Color(0xFF10B981),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Module Tracker',
                            style: GoogleFonts.poppins(
                              fontSize: 19 * scaleFactor,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      // 4 Icons on right - balanced size
                      _buildScaledActionIcon(
                        context,
                        Icons.add_rounded,
                        const Color(0xFF10B981),
                        scaleFactor,
                        onTap: () => _showAddMenu(context),
                      ),
                      SizedBox(width: 5),
                      _buildScaledActionIcon(
                        context,
                        Icons.archive_outlined,
                        const Color(0xFFF59E0B),
                        scaleFactor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SemesterArchiveScreen(),
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      _buildScaledActionIcon(
                        context,
                        Icons.assessment_outlined,
                        const Color(0xFF8B5CF6),
                        scaleFactor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AssignmentsScreen(),
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      _buildScaledActionIcon(
                        context,
                        Icons.settings_outlined,
                        const Color(0xFF0EA5E9),
                        scaleFactor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: kToolbarHeight,
              flexibleSpace: SafeArea(
                child: Stack(
                  children: [
                    // Main layout matching calendar structure
                    Row(
                      children: [
                        // Match calendar structure: 32px + 5 columns
                        const SizedBox(width: 32),
                        const Expanded(child: SizedBox.shrink()), // Mon
                        const Expanded(child: SizedBox.shrink()), // Tue
                        Expanded(
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF0EA5E9),
                                  Color(0xFF06B6D4),
                                  Color(0xFF10B981),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Module Tracker',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ), // Wed - centered
                        const Expanded(child: SizedBox.shrink()), // Thu
                        const Expanded(child: SizedBox.shrink()), // Fri
                      ],
                    ),
                    // Logo on left
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedWeekStartDateProvider.notifier).state =
                                ref.read(currentWeekStartDateProvider);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'module',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                size: 20,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'New Module',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'semester',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'New Semester',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (String value) {
                    if (value == 'module') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModuleFormScreen(),
                        ),
                      );
                    } else if (value == 'semester') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SemesterSetupScreen(),
                        ),
                      );
                    }
                  },
                ),
                SizedBox(width: 2),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
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
                SizedBox(width: 2),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.grade_outlined,
                      size: 18,
                      color: Color(0xFF0EA5E9),
                    ),
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
                SizedBox(width: 2),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.archive_outlined,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
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
                SizedBox(width: 2),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: Color(0xFF0EA5E9),
                    ),
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
                SizedBox(width: 4),
              ],
            ),
      body: semestersAsync.when(
        data: (semesters) {
          print(
            'DEBUG HOME: Semesters data received - count: ${semesters.length}',
          );
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

          // Show calendar even if no semester - will just show empty state
          final modulesAsync = selectedSemester != null
              ? ref.watch(selectedSemesterModulesProvider)
              : const AsyncValue.data(<Module>[]);
          final tasksAsync = selectedSemester != null
              ? ref.watch(allSelectedSemesterTasksProvider)
              : const AsyncValue.data(<String, List<RecurringTask>>{});

          return modulesAsync.when(
            data: (modules) {
              return tasksAsync.when(
                data: (tasksByModule) {
                  // Fetch assessments for all modules
                  final assessmentsByModule = <String, List<Assessment>>{};
                  for (final module in modules) {
                    final assessmentsAsync = ref.watch(
                      assessmentsProvider(module.id),
                    );
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
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 8 : 10,
                      ),
                      children: [
                        // Week navigation bar (always shown)
                        _WeekNavigationWrapper(
                          semester: selectedSemester,
                          selectedWeek: selectedWeek,
                          selectedDate: ref.watch(
                            selectedWeekStartDateProvider,
                          ),
                          onWeekChanged: (newWeek) {
                            final currentDate = ref.read(
                              selectedWeekStartDateProvider,
                            );
                            final weekDiff = newWeek - selectedWeek;
                            final newDate = currentDate.add(
                              Duration(days: weekDiff * 7),
                            );
                            ref
                                    .read(
                                      selectedWeekStartDateProvider.notifier,
                                    )
                                    .state =
                                newDate;
                          },
                          onTodayPressed: () {
                            ref
                                .read(selectedWeekStartDateProvider.notifier)
                                .state = ref.read(
                              currentWeekStartDateProvider,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Weekly Calendar - always show
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isMobileOrTablet = screenWidth < 1024; // Enable swipe on mobile/tablet only

                            if (isMobileOrTablet) {
                              return _SwipeableCalendar(
                                semester: selectedSemester,
                                currentWeek: selectedWeek,
                                modules: modules,
                                tasksByModule: tasksByModule,
                                assessmentsByModule: assessmentsByModule,
                                weekStartDate: ref.watch(selectedWeekStartDateProvider),
                                onWeekChanged: (newDate) {
                                  ref.read(selectedWeekStartDateProvider.notifier).state = newDate;
                                },
                              );
                            }

                            return WeeklyCalendar(
                              semester: selectedSemester,
                              currentWeek: selectedWeek,
                              modules: modules,
                              tasksByModule: tasksByModule,
                              assessmentsByModule: assessmentsByModule,
                              weekStartDate: ref.watch(selectedWeekStartDateProvider),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Module Cards Section
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final titleScale = screenWidth < 400
                                ? 0.75
                                : screenWidth < 600
                                ? 0.9
                                : 1.0;
                            return Text(
                              'This Week\'s Tasks',
                              style: GoogleFonts.poppins(
                                fontSize: 20 * titleScale,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.color,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Sort modules by code alphabetically/numerically
                        Builder(
                          builder: (context) {
                            final sortedModules = [...modules]
                              ..sort((a, b) => a.code.compareTo(b.code));
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final isMobile = screenWidth < 600;
                            final horizontalPadding = screenWidth < 400
                                ? 1.0
                                : 4.0;

                            // On mobile, stack vertically. On desktop, use horizontal row
                            if (isMobile) {
                              return Column(
                                children: sortedModules.map((module) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ModuleCard(
                                        module: module,
                                        weekNumber: selectedWeek,
                                        totalModules: sortedModules.length,
                                        isMobileStacked: true,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            } else {
                              // Horizontal row for desktop
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: sortedModules.map((module) {
                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: horizontalPadding,
                                        ),
                                        child: ModuleCard(
                                          module: module,
                                          weekNumber: selectedWeek,
                                          totalModules: sortedModules.length,
                                          isMobileStacked: false,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const AppLoadingIndicator(message: 'Loading tasks...'),
                error: (error, stack) => AppErrorState(
                  message: error.toString(),
                  onRetry: () {
                    ref.invalidate(allCurrentSemesterTasksProvider);
                  },
                ),
              );
            },
            loading: () =>
                const AppLoadingIndicator(message: 'Loading modules...'),
            error: (error, stack) => AppErrorState(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(currentSemesterModulesProvider);
              },
            ),
          );
        },
        loading: () =>
            const AppLoadingIndicator(message: 'Loading semester...'),
        error: (error, stack) => AppErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(semestersProvider);
          },
        ),
      ),
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildScaledActionIcon(
    BuildContext context,
    IconData icon,
    Color color,
    double scaleFactor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7 * scaleFactor),
      child: Container(
        padding: EdgeInsets.all(6.5 * scaleFactor),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7 * scaleFactor),
        ),
        child: Icon(icon, size: 20 * scaleFactor, color: color),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'module',
          child: Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 20,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              Text(
                'New Module',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'semester',
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: Color(0xFF0EA5E9),
              ),
              const SizedBox(width: 12),
              Text(
                'New Semester',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'module') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ModuleFormScreen()),
        );
      } else if (value == 'semester') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SemesterSetupScreen()),
        );
      }
    });
  }
}

class _WeekNavigationWrapper extends StatelessWidget {
  final Semester? semester;
  final int selectedWeek;
  final DateTime selectedDate;
  final Function(int) onWeekChanged;
  final VoidCallback onTodayPressed;

  const _WeekNavigationWrapper({
    required this.semester,
    required this.selectedWeek,
    required this.selectedDate,
    required this.onWeekChanged,
    required this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (semester != null) {
      return WeekNavigationBar(
        semester: semester!,
        currentWeek: selectedWeek,
        onWeekChanged: onWeekChanged,
        onTodayPressed: onTodayPressed,
      );
    }

    // No semester - show simplified navigation
    final weekStart = selectedDate;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        children: [
          // Match calendar structure: 32px + 5 columns
          Row(
            children: [
              const SizedBox(width: 16), // Adjust for padding + match 32px time column
              const Expanded(child: SizedBox.shrink()), // Mon
              const Expanded(child: SizedBox.shrink()), // Tue
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'No Active Semester',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ), // Wed - aligned with Module Tracker
              const Expanded(child: SizedBox.shrink()), // Thu
              const Expanded(child: SizedBox.shrink()), // Fri
            ],
          ),
          // Navigation controls overlaid
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onWeekChanged(selectedWeek - 1),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onWeekChanged(selectedWeek + 1),
            ),
          ),
        ],
      ),
    );
  }
}

// Swipeable Calendar Widget with real-time drag feedback
class _SwipeableCalendar extends StatefulWidget {
  final Semester? semester;
  final int currentWeek;
  final List<Module> modules;
  final Map<String, List<RecurringTask>> tasksByModule;
  final Map<String, List<Assessment>> assessmentsByModule;
  final DateTime weekStartDate;
  final Function(DateTime) onWeekChanged;

  const _SwipeableCalendar({
    required this.semester,
    required this.currentWeek,
    required this.modules,
    required this.tasksByModule,
    required this.assessmentsByModule,
    required this.weekStartDate,
    required this.onWeekChanged,
  });

  @override
  State<_SwipeableCalendar> createState() => _SwipeableCalendarState();
}

class _SwipeableCalendarState extends State<_SwipeableCalendar> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isAnimating = false;
            _dragOffset = 0.0;
          });
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.delta.dx;
      // Limit drag to screen width
      final screenWidth = MediaQuery.of(context).size.width;
      _dragOffset = _dragOffset.clamp(-screenWidth.toDouble(), screenWidth.toDouble());
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.25; // 25% threshold

    // Check if we should snap to next/previous week
    if (_dragOffset.abs() > threshold) {
      // Commit the swipe - capture direction before animation
      _isAnimating = true;
      final isSwipingRight = _dragOffset > 0;
      final targetOffset = _dragOffset > 0 ? screenWidth : -screenWidth;

      _animation = Tween<double>(
        begin: _dragOffset,
        end: targetOffset.toDouble(),
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
      );

      _animationController.forward(from: 0).then((_) {
        // Update the week
        if (isSwipingRight) {
          // Swiped left-to-right → go to previous week
          widget.onWeekChanged(widget.weekStartDate.subtract(const Duration(days: 7)));
        } else {
          // Swiped right-to-left → go to next week
          widget.onWeekChanged(widget.weekStartDate.add(const Duration(days: 7)));
        }
      });
    } else {
      // Snap back to current week
      _isAnimating = true;
      _animation = Tween<double>(
        begin: _dragOffset,
        end: 0,
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
      );
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: WeeklyCalendar(
        semester: widget.semester,
        currentWeek: widget.currentWeek,
        modules: widget.modules,
        tasksByModule: widget.tasksByModule,
        assessmentsByModule: widget.assessmentsByModule,
        weekStartDate: widget.weekStartDate,
        dragOffset: _dragOffset,
        isSwipeable: true,
      ),
    );
  }
}
