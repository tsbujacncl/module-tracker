import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
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
import 'package:module_tracker/utils/birthday_helper.dart';
import 'package:module_tracker/widgets/weekly_completion_dialog.dart';
import 'package:module_tracker/widgets/hover_scale_widget.dart';
import 'package:module_tracker/utils/responsive_text_utils.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Show birthday celebration after first frame if it's user's birthday
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShowBirthdayCelebration(ref)) {
        _showBirthdayCelebration();
      }
    });
  }

  /// Get responsive horizontal padding with smooth scaling from 1080p desktop to 4K
  /// Creates comfortable reading width on large displays (52% content on 4K)
  ///
  /// Mobile (<600px): 8px each side (~1-3% margins)
  /// Tablet (600-900px): smoothly 8px → 32px (~1-5% margins)
  /// Desktop (900-1080px): smoothly 32px → 84.2px (~3-7.8% margins) [baseline]
  /// Desktop to 4K (1080-3840px): linear interpolation 84.2px → 921.6px (~7.8-24% margins)
  /// 4K+ (>3840px): Cap at 24% of screen width (~24% margins, 52% content)
  double _getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 8.0;
    } else if (width < 900) {
      // Smooth interpolation from 8 to 32 between 600-900px
      final progress = (width - 600) / 300; // 0.0 to 1.0
      return 8.0 + (24.0 * progress); // 8 + 24 = 32
    } else if (width < 1080) {
      // Smooth interpolation from 32 to 84.2 between 900-1080px (desktop baseline)
      final progress = (width - 900) / 180; // 0.0 to 1.0
      return 32.0 + (52.2 * progress); // 32 + 52.2 = 84.2
    } else if (width < 3840) {
      // Linear interpolation from 84.2 to 921.6 between 1080-3840px (desktop to 4K)
      final progress = (width - 1080) / 2760; // 0.0 to 1.0
      return 84.2 + (837.4 * progress); // 84.2 + 837.4 = 921.6 (24% of 3840)
    } else {
      // Cap at 24% of screen width for 4K+ displays
      return width * 0.24;
    }
  }

  void _showBirthdayCelebration() {
    final userName = ref.read(userPreferencesProvider).userName ?? 'there';
    markBirthdayCelebrationShown(ref);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WeeklyCompletionDialog(
        userName: userName,
        isBirthdayCelebration: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semestersAsync = ref.watch(semestersProvider);
    final selectedSemester = ref.watch(selectedSemesterProvider);
    final selectedWeek = ref.watch(selectedWeekNumberProvider);

    // Trigger auto-archive check for completed semesters
    ref.watch(autoArchiveCompletedSemestersProvider);

    print(
      'DEBUG HOME: Building HomeScreen, semesters state: ${semestersAsync.runtimeType}',
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile =
        screenWidth < 600; // Increased threshold to catch more devices
    print('DEBUG: Screen width: $screenWidth, isMobile: $isMobile');

    // Dynamic scaling based on screen width - balanced approach
    final scaleFactor = screenWidth < 360
        ? 0.8 // Very small screens: reduce slightly
        : screenWidth < 380
        ? 0.9 // Small screens (e.g., iPhone SE): moderate reduction
        : screenWidth < 420
        ? 0.95 // Medium-small screens: slight reduction
        : 1.0; // Normal and larger screens: full size

    final appBarHorizontalPadding = _getHorizontalPadding(context);

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: kToolbarHeight * 1.1, // 10% taller (not too much)
              flexibleSpace: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: appBarHorizontalPadding,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      // Logo on left - balanced size with Elastic bounce (no movement)
                      UniversalInteractiveWidget(
                        style: InteractiveStyle.elastic,
                        color: Colors.transparent,
                        onTap: () {
                          ref
                              .read(selectedWeekStartDateProvider.notifier)
                              .state = ref.read(
                            currentWeekStartDateProvider,
                          );
                        },
                        child: Container(
                          width: 40 * scaleFactor,
                          height: 40 * scaleFactor,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(
                              9 * scaleFactor,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0EA5E9,
                                ).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isTodayBirthday(ref)
                                ? Transform.translate(
                                    offset: const Offset(0, -2),
                                    child: Text(
                                      '🎂',
                                      style: TextStyle(
                                        fontSize: 21 * scaleFactor,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.school_rounded,
                                    size: 21 * scaleFactor,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      // Title next to logo - dynamically sized
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
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
                                  fontSize: ResponsiveText.getTitleFontSize(screenWidth) * scaleFactor,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * scaleFactor),
                      // 4 Icons on right - balanced size with Elastic animation
                      ExcludeSemantics(
                        child: UniversalInteractiveWidget(
                          style: InteractiveStyle.elastic,
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          onTap: () => _showAddMenu(context),
                          child: Container(
                            padding: EdgeInsets.all(8 * scaleFactor),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                7 * scaleFactor,
                              ),
                              border: Border.all(
                                width: 0,
                                color: Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 22 * scaleFactor,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 3),
                      UniversalInteractiveWidget(
                        style: InteractiveStyle.elastic,
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AssignmentsScreen(),
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(8 * scaleFactor),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              7 * scaleFactor,
                            ),
                            border: Border.all(
                              width: 0,
                              color: Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            Icons.assessment_outlined,
                            size: 22 * scaleFactor,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      SizedBox(width: 3),
                      UniversalInteractiveWidget(
                        style: InteractiveStyle.elastic,
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SemesterArchiveScreen(),
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(8 * scaleFactor),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              7 * scaleFactor,
                            ),
                            border: Border.all(
                              width: 0,
                              color: Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            Icons.archive_outlined,
                            size: 22 * scaleFactor,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      SizedBox(width: 3),
                      UniversalInteractiveWidget(
                        style: InteractiveStyle.elastic,
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(8 * scaleFactor),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0EA5E9,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              7 * scaleFactor,
                            ),
                            border: Border.all(
                              width: 0,
                              color: Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            Icons.settings_outlined,
                            size: 22 * scaleFactor,
                            color: const Color(0xFF0EA5E9),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive title font size using utility
                    final double titleFontSize = ResponsiveText.getTitleFontSize(screenWidth);

                    return Stack(
                      children: [
                        // Title centered across full AppBar width
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: appBarHorizontalPadding + 60, // Space for logo (48px + 12px margin)
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFF0EA5E9),
                                        Color(0xFF06B6D4),
                                        Color(0xFF10B981),
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  'Module Tracker',
                                  style: GoogleFonts.poppins(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Logo on left with Elastic bounce (no movement)
                        Positioned(
                          left: appBarHorizontalPadding,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: ElasticBounceWidget(
                              backgroundColor: Colors.transparent,
                              onTap: () {
                                ref
                                    .read(
                                      selectedWeekStartDateProvider.notifier,
                                    )
                                    .state = ref.read(
                                  currentWeekStartDateProvider,
                                );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF06B6D4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0EA5E9,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isTodayBirthday(ref)
                                      ? Transform.translate(
                                          offset: const Offset(0, -2),
                                          child: const Text(
                                            '🎂',
                                            style: TextStyle(fontSize: 28),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.school_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                // Custom add button with manual menu - no grey square!
                Builder(
                  builder: (BuildContext context) {
                    return ElasticBounceWidget(
                      backgroundColor: const Color(
                        0xFF10B981,
                      ).withValues(alpha: 0.1),
                      onTap: () {
                        final RenderBox button =
                            context.findRenderObject() as RenderBox;
                        final RenderBox overlay =
                            Navigator.of(
                                  context,
                                ).overlay!.context.findRenderObject()
                                as RenderBox;
                        final buttonPosition = button.localToGlobal(
                          Offset.zero,
                          ancestor: overlay,
                        );

                        showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            buttonPosition.dx,
                            buttonPosition.dy + button.size.height,
                            overlay.size.width -
                                buttonPosition.dx -
                                button.size.width,
                            overlay.size.height -
                                buttonPosition.dy -
                                button.size.height,
                          ),
                          items: <PopupMenuEntry<String>>[
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
                        ).then((String? value) {
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
                                builder: (context) =>
                                    const SemesterSetupScreen(),
                              ),
                            );
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElasticBounceWidget(
                  backgroundColor: const Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssignmentsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      size: 22,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElasticBounceWidget(
                  backgroundColor: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SemesterArchiveScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.archive_outlined,
                      size: 22,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElasticBounceWidget(
                  backgroundColor: const Color(
                    0xFF0EA5E9,
                  ).withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                ),
                SizedBox(width: appBarHorizontalPadding),
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

                  final isDraggingCheckbox = ref.watch(
                    isDraggingCheckboxProvider,
                  );

                  final horizontalPadding = _getHorizontalPadding(context);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(currentSemesterModulesProvider);
                      ref.invalidate(allCurrentSemesterTasksProvider);
                    },
                    child: ListView(
                      physics: isDraggingCheckbox
                          ? const NeverScrollableScrollPhysics()
                          : const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 8,
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
                        const SizedBox(height: 2),
                        // Weekly Calendar - always show
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            // Disable swipe on web/desktop (regardless of screen size)
                            final enableSwipe = !kIsWeb && screenWidth < 1024;

                            if (enableSwipe) {
                              return _SwipeableCalendar(
                                semester: selectedSemester,
                                currentWeek: selectedWeek,
                                modules: modules,
                                tasksByModule: tasksByModule,
                                assessmentsByModule: assessmentsByModule,
                                weekStartDate: ref.watch(
                                  selectedWeekStartDateProvider,
                                ),
                                onWeekChanged: (newDate) {
                                  ref
                                          .read(
                                            selectedWeekStartDateProvider
                                                .notifier,
                                          )
                                          .state =
                                      newDate;
                                },
                              );
                            }

                            return WeeklyCalendar(
                              semester: selectedSemester,
                              currentWeek: selectedWeek,
                              modules: modules,
                              tasksByModule: tasksByModule,
                              assessmentsByModule: assessmentsByModule,
                              weekStartDate: ref.watch(
                                selectedWeekStartDateProvider,
                              ),
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
                            final isMobile = screenWidth < 600;

                            final title = Text(
                              'This Week\'s Tasks',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveText.getSectionHeaderFontSize(screenWidth) * titleScale,
                                fontWeight: ResponsiveText.getSectionHeaderFontWeight(screenWidth),
                                color: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.color,
                              ),
                            );

                            // Title consistent on all screen sizes
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: title,
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
                            // Single gap size for both horizontal and vertical spacing
                            // Increased by 20% from original 8px (4px * 2) to 9.6px
                            final cardGap = screenWidth < 400
                                ? 2.4  // 1.2px * 2 = 2.4px total gap
                                : 9.6; // 4.8px * 2 = 9.6px total gap

                            // 3-tier responsive layout: Small (1 col), Medium (2 cols), Large (4 cols)
                            if (screenWidth < 600) {
                              // Small screens: 1 column vertical stack
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
                            } else if (screenWidth < 1000) {
                              // Medium screens: 2 columns (2x2 grid) with equal heights per row
                              // Split modules into pairs for rows
                              final rows = <Widget>[];
                              for (int i = 0; i < sortedModules.length; i += 2) {
                                final modulesInRow = sortedModules.skip(i).take(2).toList();

                                // Add vertical gap BEFORE adding the row (except for first row)
                                if (i > 0) {
                                  rows.add(SizedBox(height: cardGap));
                                }

                                // Build row children with gap between cards
                                final rowChildren = <Widget>[
                                  Expanded(
                                    child: ModuleCard(
                                      module: modulesInRow[0],
                                      weekNumber: selectedWeek,
                                      totalModules: sortedModules.length,
                                      isMobileStacked: false,
                                    ),
                                  ),
                                ];

                                if (modulesInRow.length > 1) {
                                  // Add horizontal gap between cards
                                  rowChildren.add(SizedBox(width: cardGap));
                                  rowChildren.add(
                                    Expanded(
                                      child: ModuleCard(
                                        module: modulesInRow[1],
                                        weekNumber: selectedWeek,
                                        totalModules: sortedModules.length,
                                        isMobileStacked: false,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Empty space for odd number of modules
                                  rowChildren.add(SizedBox(width: cardGap));
                                  rowChildren.add(Expanded(child: SizedBox.shrink()));
                                }

                                rows.add(
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: rowChildren,
                                    ),
                                  ),
                                );
                              }

                              return Column(children: rows);
                            } else {
                              // Large screens: 4 columns horizontal row
                              final cardWidgets = <Widget>[];
                              for (int i = 0; i < sortedModules.length; i++) {
                                if (i > 0) {
                                  // Add gap between cards (not before first card)
                                  cardWidgets.add(SizedBox(width: cardGap));
                                }
                                cardWidgets.add(
                                  Expanded(
                                    child: ModuleCard(
                                      module: sortedModules[i],
                                      weekNumber: selectedWeek,
                                      totalModules: sortedModules.length,
                                      isMobileStacked: false,
                                    ),
                                  ),
                                );
                              }

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: cardWidgets,
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
              const SizedBox(
                width: 16,
              ), // Adjust for padding + match 32px time column
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

class _SwipeableCalendarState extends State<_SwipeableCalendar>
    with SingleTickerProviderStateMixin {
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
    _animation =
        Tween<double>(begin: 0, end: 0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          )
          ..addListener(() {
            setState(() {
              _dragOffset = _animation.value;
            });
          })
          ..addStatusListener((status) {
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
      // Calculate available width for day columns (same as WeeklyCalendar)
      final screenWidth = MediaQuery.of(context).size.width;

      // Account for ListView horizontal padding (same as WeeklyCalendar receives)
      final double horizontalPadding;
      if (screenWidth < 600) {
        horizontalPadding = 8.0;
      } else if (screenWidth < 900) {
        final progress = (screenWidth - 600) / 300;
        horizontalPadding = 8.0 + (24.0 * progress);
      } else if (screenWidth < 1200) {
        final progress = (screenWidth - 900) / 300;
        horizontalPadding = 32.0 + (28.0 * progress);
      } else {
        final progress = ((screenWidth - 1200) / 400).clamp(0.0, 1.0);
        horizontalPadding = 60.0 + (40.0 * progress);
      }

      final constraintsWidth = screenWidth - 2 * horizontalPadding;

      final double marginSize;
      if (constraintsWidth < 400) {
        marginSize = 16.0;
      } else if (constraintsWidth >= 500) {
        marginSize = 30.0;
      } else {
        marginSize = 20.0;
      }
      final timeColumnWidth = marginSize;
      final rightMargin = marginSize;
      final availableForDays = constraintsWidth - timeColumnWidth - rightMargin;

      // Limit drag to available day columns width
      _dragOffset = _dragOffset.clamp(-availableForDays, availableForDays);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isAnimating) return;

    // Calculate available width for day columns (same as WeeklyCalendar)
    final screenWidth = MediaQuery.of(context).size.width;

    // Account for ListView horizontal padding (same as WeeklyCalendar receives)
    final double horizontalPadding;
    if (screenWidth < 600) {
      horizontalPadding = 8.0;
    } else if (screenWidth < 900) {
      final progress = (screenWidth - 600) / 300;
      horizontalPadding = 8.0 + (24.0 * progress);
    } else if (screenWidth < 1200) {
      final progress = (screenWidth - 900) / 300;
      horizontalPadding = 32.0 + (28.0 * progress);
    } else {
      final progress = ((screenWidth - 1200) / 400).clamp(0.0, 1.0);
      horizontalPadding = 60.0 + (40.0 * progress);
    }

    final constraintsWidth = screenWidth - 2 * horizontalPadding;

    final double marginSize;
    if (constraintsWidth < 400) {
      marginSize = 16.0;
    } else if (constraintsWidth >= 500) {
      marginSize = 30.0;
    } else {
      marginSize = 20.0;
    }
    final timeColumnWidth = marginSize;
    final rightMargin = marginSize;
    final availableForDays = constraintsWidth - timeColumnWidth - rightMargin;

    final threshold = availableForDays * 0.25; // 25% threshold

    // Check if we should snap to next/previous week
    if (_dragOffset.abs() > threshold) {
      // Commit the swipe - capture direction before animation
      _isAnimating = true;
      final isSwipingRight = _dragOffset > 0;
      final targetOffset = _dragOffset > 0
          ? availableForDays
          : -availableForDays;

      _animation =
          Tween<double>(
            begin: _dragOffset,
            end: targetOffset.toDouble(),
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          );

      _animationController.forward(from: 0).then((_) {
        // Update the week
        if (isSwipingRight) {
          // Swiped left-to-right → go to previous week
          widget.onWeekChanged(
            widget.weekStartDate.subtract(const Duration(days: 7)),
          );
        } else {
          // Swiped right-to-left → go to next week
          widget.onWeekChanged(
            widget.weekStartDate.add(const Duration(days: 7)),
          );
        }
      });
    } else {
      // Snap back to current week
      _isAnimating = true;
      _animation = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The calendar widget (full)
        WeeklyCalendar(
          semester: widget.semester,
          currentWeek: widget.currentWeek,
          modules: widget.modules,
          tasksByModule: widget.tasksByModule,
          assessmentsByModule: widget.assessmentsByModule,
          weekStartDate: widget.weekStartDate,
          dragOffset: _dragOffset,
          isSwipeable: true,
        ),
        // Positioned gesture detector - excludes legend at bottom
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 65, // Exclude bottom ~65px for legend (Lecture, Lab/Tutorial, Assignment)
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
          ),
        ),
      ],
    );
  }
}
