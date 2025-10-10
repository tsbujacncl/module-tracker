import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/customization_provider.dart';
import 'package:module_tracker/utils/date_utils.dart' as utils;
import 'package:module_tracker/utils/date_picker_utils.dart';
import 'package:module_tracker/widgets/gradient_header.dart';

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
  DateTime? _readingWeekEnd;
  bool _isLoading = false;

  bool get _isEditMode => widget.semesterToEdit != null;

  // Check if form is valid for submission
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _startDate != null &&
      _endDate != null;

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
      _readingWeekEnd = widget.semesterToEdit!.readingWeekEnd;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        // Ensure it's the start of the week based on user preference
        _startDate = firstDayOfWeek == 1
            ? utils.DateUtils.getMonday(picked)
            : utils.DateUtils.getSunday(picked);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate?.add(const Duration(days: 84)) ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        // Ensure it's the end of the week based on user preference
        _endDate = firstDayOfWeek == 1
            ? utils.DateUtils.getSunday(picked)
            : utils.DateUtils.getSaturday(picked);
      });
    }
  }

  Future<void> _selectExamPeriodStart() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _examPeriodStart ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        _examPeriodStart = picked;
      });
    }
  }

  Future<void> _selectExamPeriodEnd() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _examPeriodEnd ?? _examPeriodStart ?? _startDate ?? DateTime.now(),
      firstDate: _examPeriodStart ?? _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        _examPeriodEnd = picked;
      });
    }
  }

  Future<void> _selectReadingWeekStart() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _readingWeekStart ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        // Ensure it's the start of the week
        _readingWeekStart = firstDayOfWeek == 1
            ? utils.DateUtils.getMonday(picked)
            : utils.DateUtils.getSunday(picked);
      });
    }
  }

  Future<void> _selectReadingWeekEnd() async {
    final firstDayOfWeek = ref.read(customizationProvider).weekStartDay.weekdayNumber;
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _readingWeekEnd ?? _readingWeekStart?.add(const Duration(days: 6)) ?? DateTime.now(),
      firstDate: _readingWeekStart ?? _startDate ?? DateTime(2020),
      lastDate: _endDate ?? DateTime(2030),
      firstDayOfWeek: firstDayOfWeek,
    );

    if (picked != null) {
      setState(() {
        // Ensure it's the end of the week
        _readingWeekEnd = firstDayOfWeek == 1
            ? utils.DateUtils.getSunday(picked)
            : utils.DateUtils.getSaturday(picked);
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
          readingWeekEnd: _readingWeekEnd,
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
          readingWeekEnd: _readingWeekEnd,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final firstDayOfWeek = ref.watch(customizationProvider).weekStartDay.weekdayNumber;
    final weekStartLabel = firstDayOfWeek == 1 ? 'Monday' : 'Sunday';
    final weekEndLabel = firstDayOfWeek == 1 ? 'Sunday' : 'Saturday';

    return Scaffold(
      appBar: AppBar(
        title: GradientHeader(
          title: _isEditMode ? 'Edit Semester' : 'Create Semester',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Header Section
            Row(
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semester Information',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Set up your semester details to start tracking modules',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Semester Name Field
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Semester Name',
                hintText: 'e.g., 25/26 Semester 1',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
              ),
              onChanged: (value) {
                // Trigger rebuild to update button state
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a semester name';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Dates Section Header
            _buildSectionHeader(
              context,
              icon: Icons.calendar_month,
              title: 'Semester Duration',
              subtitle: 'Define the start and end of your semester',
              color: const Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 16),

            // Start & End Dates
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'Start Date',
                    subtitle: weekStartLabel,
                    date: _startDate,
                    onTap: _selectStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'End Date',
                    subtitle: weekEndLabel,
                    date: _endDate,
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),

            // Total Weeks Display
            if (_startDate != null && _endDate != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Total: $numberOfWeeks weeks',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Exam Period Section Header
            _buildSectionHeader(
              context,
              icon: Icons.assignment,
              title: 'Exam Period',
              subtitle: 'Optional: Set exam dates for this semester',
              color: const Color(0xFFF87171),
            ),
            const SizedBox(height: 16),

            // Exam Period Dates
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'Exam Start',
                    subtitle: 'first exam',
                    date: _examPeriodStart,
                    onTap: _selectExamPeriodStart,
                    onClear: _examPeriodStart != null
                        ? () => setState(() => _examPeriodStart = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'Exam End',
                    subtitle: 'last exam',
                    date: _examPeriodEnd,
                    onTap: _selectExamPeriodEnd,
                    onClear: _examPeriodEnd != null
                        ? () => setState(() => _examPeriodEnd = null)
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Reading Week Section Header
            _buildSectionHeader(
              context,
              icon: Icons.book_outlined,
              title: 'Reading Week',
              subtitle: 'Optional: Set reading week dates',
              color: const Color(0xFFA78BFA),
            ),
            const SizedBox(height: 16),

            // Reading Week Dates
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'Reading Week Start',
                    subtitle: weekStartLabel,
                    date: _readingWeekStart,
                    onTap: _selectReadingWeekStart,
                    onClear: _readingWeekStart != null
                        ? () => setState(() {
                            _readingWeekStart = null;
                            _readingWeekEnd = null;
                          })
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateCard(
                    context: context,
                    title: 'Reading Week End',
                    subtitle: weekEndLabel,
                    date: _readingWeekEnd,
                    onTap: _readingWeekStart != null ? _selectReadingWeekEnd : null,
                    onClear: _readingWeekEnd != null
                        ? () => setState(() => _readingWeekEnd = null)
                        : null,
                    isDisabled: _readingWeekStart == null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_isLoading || !_canSave) ? null : _saveSemester,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Update Semester' : 'Create Semester',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required DateTime? date,
    required VoidCallback? onTap,
    VoidCallback? onClear,
    bool isDisabled = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDisabled
              ? Colors.grey[300]!
              : (date != null ? Colors.grey[400]! : Colors.grey[300]!),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDisabled
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date != null
                          ? '${date.day}/${date.month}/${date.year}'
                          : 'Tap to select $subtitle',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? Colors.grey[400]
                            : (date != null
                                ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                : Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onClear != null && date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onClear,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: Colors.grey[600],
                )
              else
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
