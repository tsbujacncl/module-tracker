import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/widgets/module_share_dialog.dart';

class ModuleSelectionDialog extends ConsumerStatefulWidget {
  final Module? preSelectedModule;
  final String semesterId;
  final Set<String>? initialSelectedModuleIds;

  const ModuleSelectionDialog({
    super.key,
    this.preSelectedModule,
    required this.semesterId,
    this.initialSelectedModuleIds,
  });

  @override
  ConsumerState<ModuleSelectionDialog> createState() => _ModuleSelectionDialogState();
}

class _ModuleSelectionDialogState extends ConsumerState<ModuleSelectionDialog> {
  Set<String> _selectedModuleIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    // Use initial selected modules if provided, otherwise pre-select the clicked module (if provided)
    if (widget.initialSelectedModuleIds != null) {
      _selectedModuleIds = Set.from(widget.initialSelectedModuleIds!);
    } else if (widget.preSelectedModule != null) {
      _selectedModuleIds.add(widget.preSelectedModule!.id);
    }
  }

  void _toggleModule(String moduleId, int totalModules) {
    setState(() {
      if (_selectedModuleIds.contains(moduleId)) {
        _selectedModuleIds.remove(moduleId);
      } else {
        _selectedModuleIds.add(moduleId);
      }
      _selectAll = _selectedModuleIds.length == totalModules;
    });
  }

  void _toggleSelectAll(List<Module> allModules) {
    setState(() {
      if (_selectAll) {
        // Deselect all
        _selectedModuleIds.clear();
      } else {
        // Select all
        _selectedModuleIds = allModules.map((m) => m.id).toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  Future<void> _continueToShare(List<Module> allModules) async {
    if (_selectedModuleIds.isEmpty) return;

    // Get selected modules
    final selectedModules = allModules
        .where((m) => _selectedModuleIds.contains(m.id))
        .toList();

    // Fetch assessments and tasks for each selected module
    final assessmentsByModule = <String, List<Assessment>>{};
    final tasksByModule = <String, List<RecurringTask>>{};

    for (final module in selectedModules) {
      final assessmentsAsync = ref.read(assessmentsProvider(module.id));
      final tasksAsync = ref.read(recurringTasksProvider(module.id));

      await assessmentsAsync.when(
        data: (assessments) async {
          assessmentsByModule[module.id] = assessments;
        },
        loading: () async {},
        error: (_, __) async {},
      );

      await tasksAsync.when(
        data: (tasks) async {
          tasksByModule[module.id] = tasks;
        },
        loading: () async {},
        error: (_, __) async {},
      );
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Close this dialog
    if (!mounted) return;
    Navigator.pop(context);

    // Open share dialog with selected modules
    showDialog(
      context: context,
      builder: (context) => ModuleShareDialog(
        modules: selectedModules,
        assessmentsByModule: assessmentsByModule,
        tasksByModule: tasksByModule,
        userId: user.uid,
        semesterId: widget.semesterId,
        preSelectedModule: widget.preSelectedModule,
        selectedModuleIds: _selectedModuleIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(modulesForSemesterProvider(widget.semesterId));

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: modulesAsync.when(
          data: (allModules) {
            // Sort modules alphabetically
            final sortedModules = [...allModules]
              ..sort((a, b) => a.code.compareTo(b.code));

            // Calculate totals
            int totalAssessments = 0;
            int totalTasks = 0;

            for (final moduleId in _selectedModuleIds) {
              final assessmentsAsync = ref.watch(assessmentsProvider(moduleId));
              final tasksAsync = ref.watch(recurringTasksProvider(moduleId));

              assessmentsAsync.whenData((assessments) {
                totalAssessments += assessments.length;
              });

              tasksAsync.whenData((tasks) {
                totalTasks += tasks.length;
              });
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.share_rounded,
                              color: Color(0xFF0EA5E9),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select Modules to Share',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Module List
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sortedModules.length,
                      itemBuilder: (context, index) {
                        final module = sortedModules[index];
                        final isSelected = _selectedModuleIds.contains(module.id);

                        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
                        final tasksAsync = ref.watch(recurringTasksProvider(module.id));

                        return assessmentsAsync.when(
                          data: (assessments) {
                            return tasksAsync.when(
                              data: (tasks) {
                                return InkWell(
                                  onTap: () => _toggleModule(module.id, sortedModules.length),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF0EA5E9).withValues(alpha: 0.05)
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (_) => _toggleModule(
                                            module.id,
                                            sortedModules.length,
                                          ),
                                          activeColor: const Color(0xFF0EA5E9),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${module.code} - ${module.name}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '• ${assessments.length} assessment${assessments.length != 1 ? 's' : ''}, ${tasks.length} task${tasks.length != 1 ? 's' : ''}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => _buildLoadingRow(module, isSelected),
                              error: (_, __) => _buildLoadingRow(module, isSelected),
                            );
                          },
                          loading: () => _buildLoadingRow(module, isSelected),
                          error: (_, __) => _buildLoadingRow(module, isSelected),
                        );
                      },
                    ),
                  ),
                ),

                // Footer with summary and actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Select All (if more than 1 module)
                      if (sortedModules.length > 1) ...[
                        InkWell(
                          onTap: () => _toggleSelectAll(sortedModules),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selectAll,
                                onChanged: (_) => _toggleSelectAll(sortedModules),
                                activeColor: const Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Select All (${sortedModules.length} modules)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total: ${_selectedModuleIds.length} module${_selectedModuleIds.length != 1 ? 's' : ''}, $totalAssessments assessment${totalAssessments != 1 ? 's' : ''}, $totalTasks task${totalTasks != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _selectedModuleIds.isEmpty
                                  ? null
                                  : () => _continueToShare(sortedModules),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                disabledBackgroundColor: const Color(0xFFE2E8F0),
                                disabledForegroundColor: const Color(0xFF94A3B8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue to Share',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Error loading modules: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingRow(Module module, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF0EA5E9).withValues(alpha: 0.05)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: null,
            activeColor: const Color(0xFF0EA5E9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${module.code} - ${module.name}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loading...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
