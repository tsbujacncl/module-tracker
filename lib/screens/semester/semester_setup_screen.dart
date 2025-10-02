import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;
import 'package:module_tracker/utils/date_picker_utils.dart';

class SemesterSetupScreen extends ConsumerStatefulWidget {
  const SemesterSetupScreen({super.key});

  @override
  ConsumerState<SemesterSetupScreen> createState() =>
      _SemesterSetupScreenState();
}

class _SemesterSetupScreenState extends ConsumerState<SemesterSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showMondayFirstDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        // Ensure it's a Monday
        _startDate = utils.DateUtils.getMonday(picked);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showMondayFirstDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate?.add(const Duration(days: 84)) ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        // Ensure it's a Sunday
        _endDate = utils.DateUtils.getSunday(picked);
      });
    }
  }

  int get numberOfWeeks {
    if (_startDate == null || _endDate == null) return 0;
    return utils.DateUtils.calculateWeeksBetween(_startDate!, _endDate!);
  }

  Future<void> _createSemester() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not logged in');

      print('DEBUG SEMESTER: Creating semester for user: ${user.uid}');
      print('DEBUG SEMESTER: User email: ${user.email}');
      print('DEBUG SEMESTER: User is anonymous: ${user.isAnonymous}');
      print('DEBUG SEMESTER: Auth provider: ${user.providerData.map((p) => p.providerId).join(", ")}');

      final repository = ref.read(firestoreRepositoryProvider);
      final semester = Semester(
        id: '',
        name: _nameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        numberOfWeeks: numberOfWeeks,
        examPeriodStart: null,
        examPeriodEnd: null,
        readingWeekStart: null,
        readingWeekEnd: null,
        createdAt: DateTime.now(),
      );

      print('DEBUG SEMESTER: Calling createSemester...');

      // Add timeout to prevent hanging
      await repository.createSemester(user.uid, semester).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Semester creation timed out. Please check your internet connection and Firestore security rules.');
        },
      );

      print('DEBUG SEMESTER: Semester created successfully!');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semester created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('DEBUG SEMESTER: Error creating semester - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Semester'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
            Text(
              'Semester Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your semester details to start tracking modules',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Semester Name',
                hintText: 'e.g., Semester 1 2024/25',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a semester name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Start Date (Monday)'),
              subtitle: Text(
                _startDate != null
                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectStartDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('End Date (Sunday)'),
              subtitle: Text(
                _endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectEndDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 24),
            if (_startDate != null && _endDate != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Total Weeks',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$numberOfWeeks',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _createSemester,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Semester'),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}