import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/screens/module/tabs/weekly_tasks_tab.dart';
import 'package:module_tracker/screens/module/tabs/assessments_tab.dart';
import 'package:module_tracker/screens/module/tabs/overview_tab.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class ModuleDetailScreen extends ConsumerStatefulWidget {
  final Module module;

  const ModuleDetailScreen({
    super.key,
    required this.module,
  });

  @override
  ConsumerState<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends ConsumerState<ModuleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moduleGrade = ref.watch(moduleGradeProvider(widget.module.id));
    final gradeStatus = ref.watch(moduleGradeStatusProvider(widget.module.id));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with module info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getStatusColor(gradeStatus),
                      _getStatusColor(gradeStatus).withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.module.name,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            if (widget.module.code.isNotEmpty) ...[
                              Text(
                                widget.module.code,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Text(
                              '${widget.module.credits} Credits',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModuleFormScreen(
                        existingModule: widget.module,
                        semesterId: widget.module.semesterId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _showDeleteDialog(context),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              ),
            ],
          ),
          // Statistics cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _StatisticsCards(
                module: widget.module,
                moduleGrade: moduleGrade,
                gradeStatus: gradeStatus,
              ),
            ),
          ),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                unselectedLabelColor: isDarkMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                indicatorColor: _getStatusColor(gradeStatus),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Tasks'),
                  Tab(text: 'Assessments'),
                  Tab(text: 'Overview'),
                ],
              ),
            ),
          ),
          // Tab content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                WeeklyTasksTab(module: widget.module),
                AssessmentsTab(module: widget.module),
                OverviewTab(module: widget.module),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(GradeStatus status) {
    switch (status) {
      case GradeStatus.exceeding:
        return const Color(0xFF10B981);
      case GradeStatus.onTrack:
        return const Color(0xFF3B82F6);
      case GradeStatus.nearlyThere:
        return const Color(0xFFF59E0B);
      case GradeStatus.atRisk:
        return const Color(0xFFEF4444);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Module'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${widget.module.name}"?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All tasks, assessments, and grades will be permanently deleted.',
                        style: TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              try {
                await repository.deleteModule(user.uid, widget.module.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  // Also pop the module detail screen since the module is deleted
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Module deleted successfully'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting module: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _StatisticsCards extends ConsumerWidget {
  final Module module;
  final ModuleGrade? moduleGrade;
  final GradeStatus gradeStatus;

  const _StatisticsCards({
    required this.module,
    required this.moduleGrade,
    required this.gradeStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWeek = ref.watch(selectedWeekNumberProvider);
    final completionsAsync = ref.watch(
      taskCompletionsProvider((moduleId: module.id, weekNumber: selectedWeek)),
    );
    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return completionsAsync.when(
      data: (completions) {
        final completedThisWeek = completions.where((c) => c.status == TaskStatus.complete).length;

        return assessmentsAsync.when(
          data: (assessments) {
            final completedAssessments = assessments.where((a) => a.markEarned != null).length;
            final upcomingDeadlines = assessments
                .where((a) => a.dueDate != null && a.dueDate!.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.task_alt,
                        label: 'Tasks This Week',
                        value: '$completedThisWeek',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.assignment_turned_in,
                        label: 'Assessments',
                        value: '$completedAssessments/${assessments.length}',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.grade,
                        label: 'Current Grade',
                        value: moduleGrade != null
                            ? '${moduleGrade!.currentGrade.toStringAsFixed(1)}%'
                            : 'N/A',
                        color: _getStatusColor(gradeStatus),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.event,
                        label: 'Next Deadline',
                        value: upcomingDeadlines.isNotEmpty
                            ? '${upcomingDeadlines.first.dueDate!.day}/${upcomingDeadlines.first.dueDate!.month}'
                            : 'None',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getStatusColor(GradeStatus status) {
    switch (status) {
      case GradeStatus.exceeding:
        return const Color(0xFF10B981);
      case GradeStatus.onTrack:
        return const Color(0xFF3B82F6);
      case GradeStatus.nearlyThere:
        return const Color(0xFFF59E0B);
      case GradeStatus.atRisk:
        return const Color(0xFFEF4444);
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
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
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
