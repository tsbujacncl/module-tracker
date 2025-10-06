import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;
import 'package:module_tracker/utils/date_picker_utils.dart';

class SemesterSetupScreen extends ConsumerStatefulWidget {
  final Semester? semesterToEdit;

  const SemesterSetupScreen({super.key, this.semesterToEdit});

  @override
  ConsumerState<SemesterSetupScreen> createState() =>
      _SemesterSetupScreenState();
}

class _SemesterSetupScreenState extends ConsumerState<SemesterSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _examPeriodStart;
  DateTime? _examPeriodEnd;
  DateTime? _readingWeekStart;
  bool _isLoading = false;

  bool get _isEditMode => widget.semesterToEdit != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if editing
    if (_isEditMode) {
      _nameController.text = widget.semesterToEdit!.name;
      _startDate = widget.semesterToEdit!.startDate;
      _endDate = widget.semesterToEdit!.endDate;
      _examPeriodStart = widget.semesterToEdit!.examPeriodStart;
      _examPeriodEnd = widget.semesterToEdit!.examPeriodEnd;
      _readingWeekStart = widget.semesterToEdit!.readingWeekStart;
    }
  }

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

  Future<void> _selectExamPeriodStart() async {
    final picked = await showMondayFirstDatePicker(
      context: context,
      initialDate: _examPeriodStart ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _examPeriodStart = picked;
      });
    }
  }

  Future<void> _selectExamPeriodEnd() async {
    final picked = await showMondayFirstDatePicker(
      context: context,
      initialDate: _examPeriodEnd ?? _examPeriodStart ?? _startDate ?? DateTime.now(),
      firstDate: _examPeriodStart ?? _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _examPeriodEnd = picked;
      });
    }
  }

  Future<void> _selectReadingWeekStart() async {
    final picked = await showMondayFirstDatePicker(
      context: context,
      initialDate: _readingWeekStart ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        // Ensure it's a Monday
        _readingWeekStart = utils.DateUtils.getMonday(picked);
      });
    }
  }

  int get numberOfWeeks {
    if (_startDate == null || _endDate == null) return 0;
    return utils.DateUtils.calculateWeeksBetween(_startDate!, _endDate!);
  }

  Future<void> _saveSemester() async {
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

      final repository = ref.read(firestoreRepositoryProvider);

      if (_isEditMode) {
        // Update existing semester
        print('DEBUG SEMESTER: Updating semester ${widget.semesterToEdit!.id}');

        final updatedSemester = widget.semesterToEdit!.copyWith(
          name: _nameController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          numberOfWeeks: numberOfWeeks,
          examPeriodStart: _examPeriodStart,
          examPeriodEnd: _examPeriodEnd,
          readingWeekStart: _readingWeekStart,
          readingWeekEnd: _readingWeekStart != null
              ? _readingWeekStart!.add(const Duration(days: 6)) // Auto-calculate Sunday
              : null,
        );

        await repository.updateSemester(
          user.uid,
          widget.semesterToEdit!.id,
          updatedSemester.toFirestore(),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Semester update timed out. Please check your internet connection.');
          },
        );

        print('DEBUG SEMESTER: Semester updated successfully!');

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semester updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new semester
        print('DEBUG SEMESTER: Creating semester for user: ${user.uid}');

        final semester = Semester(
          id: '',
          name: _nameController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          numberOfWeeks: numberOfWeeks,
          examPeriodStart: _examPeriodStart,
          examPeriodEnd: _examPeriodEnd,
          readingWeekStart: _readingWeekStart,
          readingWeekEnd: _readingWeekStart != null
              ? _readingWeekStart!.add(const Duration(days: 6)) // Auto-calculate Sunday
              : null,
          createdAt: DateTime.now(),
        );

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
      }
    } catch (e) {
      print('DEBUG SEMESTER: Error saving semester - $e');
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
        title: Text(_isEditMode ? 'Edit Semester' : 'Create Semester'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              textCapitalization: TextCapitalization.sentences,
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
            const SizedBox(height: 32),
            Text(
              'Exam Period (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set the exam period dates for this semester',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Exam Period Start'),
              subtitle: Text(
                _examPeriodStart != null
                    ? '${_examPeriodStart!.day}/${_examPeriodStart!.month}/${_examPeriodStart!.year}'
                    : 'Not selected',
              ),
              trailing: _examPeriodStart != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _examPeriodStart = null;
                            });
                          },
                        ),
                      ],
                    )
                  : const Icon(Icons.calendar_today),
              onTap: _selectExamPeriodStart,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Exam Period End'),
              subtitle: Text(
                _examPeriodEnd != null
                    ? '${_examPeriodEnd!.day}/${_examPeriodEnd!.month}/${_examPeriodEnd!.year}'
                    : 'Not selected',
              ),
              trailing: _examPeriodEnd != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _examPeriodEnd = null;
                            });
                          },
                        ),
                      ],
                    )
                  : const Icon(Icons.calendar_today),
              onTap: _selectExamPeriodEnd,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Reading Week (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the Monday that reading week starts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Reading Week Start (Monday)'),
              subtitle: Text(
                _readingWeekStart != null
                    ? '${_readingWeekStart!.day}/${_readingWeekStart!.month}/${_readingWeekStart!.year} - ${_readingWeekStart!.add(const Duration(days: 6)).day}/${_readingWeekStart!.add(const Duration(days: 6)).month}/${_readingWeekStart!.add(const Duration(days: 6)).year}'
                    : 'Not selected',
              ),
              trailing: _readingWeekStart != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _readingWeekStart = null;
                            });
                          },
                        ),
                      ],
                    )
                  : const Icon(Icons.calendar_today),
              onTap: _selectReadingWeekStart,
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
              onPressed: _isLoading ? null : _saveSemester,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditMode ? 'Update Semester' : 'Create Semester'),
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}