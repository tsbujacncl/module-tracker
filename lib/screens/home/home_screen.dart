import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/widgets/module_card.dart';
import 'package:module_tracker/widgets/week_navigation_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semestersAsync = ref.watch(semestersProvider);
    final semester = ref.watch(currentSemesterProvider);
    final modulesAsync = ref.watch(currentSemesterModulesProvider);
    final selectedWeek = ref.watch(selectedWeekNumberProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Settings screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
          ),
        ],
      ),
      body: semestersAsync.when(
        data: (semesters) {
          if (semesters.isEmpty) {
            // No semester setup yet
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Semester Setup',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first semester to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SemesterSetupScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Semester'),
                  ),
                ],
              ),
            );
          }

          // Semester exists, show modules
          return Column(
            children: [
              // Week navigation bar
              WeekNavigationBar(
                semester: semester!,
                currentWeek: selectedWeek,
                onWeekChanged: (week) {
                  ref.read(selectedWeekNumberProvider.notifier).state = week;
                },
              ),
              // Module list
              Expanded(
                child: modulesAsync.when(
                  data: (modules) {
                    if (modules.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.school,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Modules Yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first module to start tracking',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(currentSemesterModulesProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return ModuleCard(
                            module: module,
                            weekNumber: selectedWeek,
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Text('Error: $error'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
      floatingActionButton: semester != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModuleFormScreen(
                      semesterId: semester.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Module'),
            )
          : null,
    );
  }
}