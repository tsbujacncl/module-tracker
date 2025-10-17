import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/semester_break.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
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
  final _creditsController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  _ExamPeriodInput? _examPeriod;
  bool _isLoading = false;
  List<_BreakInput> _breaks = [];

  // Track initial state for unsaved changes detection
  String _initialName = '';
  String _initialCredits = '';
  DateTime? _initialStartDate;
  DateTime? _initialEndDate;
  bool _initialHasExamPeriod = false;
  int _initialBreaks = 0;

  bool get _isEditMode => widget.semesterToEdit != null;

  // Check if form is valid for submission
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _creditsController.text.trim().isNotEmpty &&
      _startDate != null &&
      _endDate != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if editing
    if (_isEditMode) {
      _nameController.text = widget.semesterToEdit!.name;
      if (widget.semesterToEdit!.totalCredits != null) {
        _creditsController.text = widget.semesterToEdit!.totalCredits.toString();
      }
      _startDate = widget.semesterToEdit!.startDate;
      _endDate = widget.semesterToEdit!.endDate;

      // Convert exam period dates to _ExamPeriodInput
      if (widget.semesterToEdit!.examPeriodStart != null && widget.semesterToEdit!.examPeriodEnd != null) {
        _examPeriod = _ExamPeriodInput()
          ..startDate = widget.semesterToEdit!.examPeriodStart
          ..endDate = widget.semesterToEdit!.examPeriodEnd;
      }

      _breaks = widget.semesterToEdit!.breaks.map((b) => _BreakInput.fromSemesterBreak(b)).toList();
    }

    // Store initial state for unsaved changes detection
    _initialName = _nameController.text;
    _initialCredits = _creditsController.text;
    _initialStartDate = _startDate;
    _initialEndDate = _endDate;
    _initialHasExamPeriod = _examPeriod != null;
    _initialBreaks = _breaks.length;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      firstDayOfWeek: 1, // Monday
    );

    if (picked != null) {
      setState(() {
        // Ensure it's Monday
        _startDate = utils.DateUtils.getMonday(picked);
        // Auto-populate end date to next day if not already set
        if (_endDate == null) {
          _endDate = _startDate!.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate?.add(const Duration(days: 84)) ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      firstDayOfWeek: 1, // Monday
    );

    if (picked != null) {
      setState(() {
        // Ensure it's Sunday (end of week when Monday is start)
        _endDate = utils.DateUtils.getSunday(picked);
      });
    }
  }

  void _addExamPeriod() {
    setState(() {
      _examPeriod = _ExamPeriodInput();
    });
  }

  void _removeExamPeriod() {
    setState(() {
      _examPeriod = null;
    });
  }

  void _addBreak() {
    setState(() {
      _breaks.insert(0, _BreakInput());
    });
  }

  void _removeBreak(int index) {
    setState(() {
      _breaks.removeAt(index);
    });
  }

  int get numberOfWeeks {
    if (_startDate == null || _endDate == null) return 0;
    return utils.DateUtils.calculateWeeksBetween(_startDate!, _endDate!);
  }

  // Check if there are unsaved changes
  bool get _hasUnsavedChanges {
    return _nameController.text != _initialName ||
        _creditsController.text != _initialCredits ||
        _startDate != _initialStartDate ||
        _endDate != _initialEndDate ||
        (_examPeriod != null) != _initialHasExamPeriod ||
        _breaks.length != _initialBreaks;
  }

  // Show unsaved changes dialog
  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: GoogleFonts.inter(
            fontSize: 14,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: Text(
              'Discard',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _saveSemester();
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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
          totalCredits: _creditsController.text.trim().isNotEmpty ? int.tryParse(_creditsController.text.trim()) : null,
          startDate: _startDate!,
          endDate: _endDate!,
          numberOfWeeks: numberOfWeeks,
          examPeriodStart: _examPeriod?.startDate,
          examPeriodEnd: _examPeriod?.endDate,
          breaks: _breaks.map((b) => b.toSemesterBreak()).toList(),
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
          totalCredits: _creditsController.text.trim().isNotEmpty ? int.tryParse(_creditsController.text.trim()) : null,
          startDate: _startDate!,
          endDate: _endDate!,
          numberOfWeeks: numberOfWeeks,
          examPeriodStart: _examPeriod?.startDate,
          examPeriodEnd: _examPeriod?.endDate,
          createdAt: DateTime.now(),
          breaks: _breaks.map((b) => b.toSemesterBreak()).toList(),
        );

        final semesterId = await repository.createSemester(user.uid, semester).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Semester creation timed out. Please check your internet connection and Firestore security rules.');
          },
        );

        print('DEBUG SEMESTER: Semester created successfully!');

        if (mounted) {
          // Return the created semester ID so it can be auto-selected
          Navigator.pop(context, semesterId);
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

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: GradientHeader(
          title: _isEditMode ? 'Edit Semester' : 'Create Semester',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Semester Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Semester Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        // Weeks badge (only show when both dates selected)
                        if (_startDate != null && _endDate != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.event_note,
                                  size: 14,
                                  color: Color(0xFF0EA5E9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$numberOfWeeks weeks',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Semester Name + Credits
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 500;

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: TextFormField(
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
                                    setState(() {});
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a semester name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _creditsController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: 'Credits',
                                    hintText: '120',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final credits = int.tryParse(value);
                                    if (credits == null) {
                                      return 'Invalid';
                                    }
                                    if (credits <= 0) {
                                      return 'Must be > 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: constraints.maxWidth * 0.55,
                              child: TextFormField(
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
                                  setState(() {});
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a semester name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _creditsController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Credits',
                                  hintText: '120',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  final credits = int.tryParse(value);
                                  if (credits == null) {
                                    return 'Invalid';
                                  }
                                  if (credits <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Start & End Dates Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 500;

                        if (isMobile) {
                          return Column(
                            children: [
                              // Start Date
                              InkWell(
                                onTap: _selectStartDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _startDate != null
                                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                  : 'Tap to select',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _startDate != null
                                                    ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                                    : Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // End Date
                              InkWell(
                                onTap: _selectEndDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _endDate != null
                                                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                  : 'Tap to select',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _endDate != null
                                                    ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                                    : Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _selectStartDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _startDate != null
                                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                                  : 'Tap to select',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _startDate != null
                                                    ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                                    : Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _selectEndDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _endDate != null
                                                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                                  : 'Tap to select',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _endDate != null
                                                    ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                                    : Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Exam Period Section
            _examPeriod != null
                ? _ExamPeriodCard(
                    key: ObjectKey(_examPeriod),
                    examPeriodInput: _examPeriod!,
                    onRemove: _removeExamPeriod,
                    onChanged: () => setState(() {}),
                    semesterStartDate: _startDate,
                    semesterEndDate: _endDate,
                  )
                : Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: _addExamPeriod,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.assignment, color: const Color(0xFFF87171), size: 22),
                            const SizedBox(width: 12),
                            Text(
                              'Exam Period (Optional)',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 32),

            // Breaks Section
            if (_breaks.isEmpty)
              // Empty state - clickable card to add break
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: _addBreak,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_busy, color: const Color(0xFF10B981), size: 22),
                            const SizedBox(width: 12),
                            Text(
                              'Breaks (Optional)',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Reading Weeks, Easter Breaks etc.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Show breaks with header in first card
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _breaks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final breakItem = entry.value;
                  final isFirst = index == 0;

                  return _BreakCard(
                    key: ObjectKey(breakItem),
                    breakInput: breakItem,
                    onRemove: () => _removeBreak(index),
                    onChanged: () => setState(() {}),
                    onAddAnother: isFirst ? _addBreak : null,
                    semesterStartDate: _startDate,
                    semesterEndDate: _endDate,
                    showHeader: isFirst,
                  );
                }).toList(),
              ),

            const SizedBox(height: 40),

            // Action Button
            Center(
              child: FilledButton(
                onPressed: (_isLoading || !_canSave) ? null : _saveSemester,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(200, 56),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
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
            const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// Exam Period Input class
class _ExamPeriodInput {
  static int _counter = 0;
  final String id;
  DateTime? startDate;
  DateTime? endDate;

  _ExamPeriodInput() : id = 'exam_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}

// Exam Period Card widget
class _ExamPeriodCard extends StatefulWidget {
  final _ExamPeriodInput examPeriodInput;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final DateTime? semesterStartDate;
  final DateTime? semesterEndDate;

  const _ExamPeriodCard({
    super.key,
    required this.examPeriodInput,
    required this.onRemove,
    required this.onChanged,
    this.semesterStartDate,
    this.semesterEndDate,
  });

  @override
  State<_ExamPeriodCard> createState() => _ExamPeriodCardState();
}

class _ExamPeriodCardState extends State<_ExamPeriodCard> {
  Future<void> _selectStartDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: widget.examPeriodInput.startDate ?? widget.semesterStartDate ?? DateTime.now(),
      firstDate: widget.semesterStartDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      firstDayOfWeek: 1,
    );

    if (picked != null) {
      setState(() {
        widget.examPeriodInput.startDate = picked;
        // Auto-populate end date to next day if not already set
        if (widget.examPeriodInput.endDate == null) {
          widget.examPeriodInput.endDate = picked.add(const Duration(days: 1));
        }
        // Reset end date if it's before the new start date
        else if (widget.examPeriodInput.endDate!.isBefore(picked)) {
          widget.examPeriodInput.endDate = picked.add(const Duration(days: 1));
        }
      });
      widget.onChanged();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: widget.examPeriodInput.endDate ?? widget.examPeriodInput.startDate?.add(const Duration(days: 6)) ?? DateTime.now(),
      firstDate: widget.examPeriodInput.startDate ?? widget.semesterStartDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      firstDayOfWeek: 1,
    );

    if (picked != null) {
      setState(() {
        widget.examPeriodInput.endDate = picked;
      });
      widget.onChanged();
    }
  }

  String? get durationString {
    if (widget.examPeriodInput.startDate == null || widget.examPeriodInput.endDate == null) {
      return null;
    }
    final days = widget.examPeriodInput.endDate!.difference(widget.examPeriodInput.startDate!).inDays + 1;
    if (days < 7) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else {
      final weeks = (days / 7).round();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
  }

  bool get isOutsideSemester {
    if (widget.examPeriodInput.startDate == null || widget.semesterEndDate == null) {
      return false;
    }
    return widget.examPeriodInput.startDate!.isAfter(widget.semesterEndDate!);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with badges
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment, color: const Color(0xFFF87171), size: 22),
                const SizedBox(width: 12),
                Text(
                  'Exam Period',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                // Duration badge
                if (durationString != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_note,
                          size: 14,
                          color: Color(0xFFF87171),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          durationString!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (durationString != null && isOutsideSemester) const SizedBox(width: 8),
                // Outside semester badge
                if (isOutsideSemester)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFF0EA5E9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'After semester',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove exam period',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content: Date selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date selection
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.examPeriodInput.startDate != null
                                      ? '${widget.examPeriodInput.startDate!.day}/${widget.examPeriodInput.startDate!.month}/${widget.examPeriodInput.startDate!.year}'
                                      : 'Tap to select',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: widget.examPeriodInput.startDate != null
                                        ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                        : Colors.grey[500],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: widget.examPeriodInput.startDate != null ? _selectEndDate : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.examPeriodInput.startDate != null ? Colors.grey[300]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.examPeriodInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: widget.examPeriodInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.examPeriodInput.endDate != null
                                      ? '${widget.examPeriodInput.endDate!.day}/${widget.examPeriodInput.endDate!.month}/${widget.examPeriodInput.endDate!.year}'
                                      : (widget.examPeriodInput.startDate != null ? 'Tap to select' : 'Select start first'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: widget.examPeriodInput.endDate != null
                                        ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                        : Colors.grey[500],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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
      ),
    );
  }
}

// Break Input class
class _BreakInput {
  static int _counter = 0;
  final String id;
  String name = '';
  DateTime? startDate;
  DateTime? endDate;

  _BreakInput() : id = 'break_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  factory _BreakInput.fromSemesterBreak(SemesterBreak breakItem) {
    return _BreakInput()
      ..name = breakItem.name
      ..startDate = breakItem.startDate
      ..endDate = breakItem.endDate;
  }

  SemesterBreak toSemesterBreak() {
    return SemesterBreak(
      id: id,
      name: name,
      startDate: startDate!,
      endDate: endDate!,
    );
  }
}

// Break Card widget
class _BreakCard extends StatefulWidget {
  final _BreakInput breakInput;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback? onAddAnother;
  final DateTime? semesterStartDate;
  final DateTime? semesterEndDate;
  final bool showHeader;

  const _BreakCard({
    super.key,
    required this.breakInput,
    required this.onRemove,
    required this.onChanged,
    this.onAddAnother,
    this.semesterStartDate,
    this.semesterEndDate,
    this.showHeader = false,
  });

  @override
  State<_BreakCard> createState() => _BreakCardState();
}

class _BreakCardState extends State<_BreakCard> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.breakInput.name);
  }

  @override
  void didUpdateWidget(_BreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breakInput.name != oldWidget.breakInput.name) {
      _nameController.text = widget.breakInput.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: widget.breakInput.startDate ?? widget.semesterStartDate ?? DateTime.now(),
      firstDate: widget.semesterStartDate ?? DateTime(2020),
      lastDate: widget.semesterEndDate ?? DateTime(2030),
      firstDayOfWeek: 1,
    );

    if (picked != null) {
      setState(() {
        widget.breakInput.startDate = picked;
        // Auto-populate end date to next day if not already set
        if (widget.breakInput.endDate == null) {
          widget.breakInput.endDate = picked.add(const Duration(days: 1));
        }
        // Reset end date if it's before the new start date
        else if (widget.breakInput.endDate!.isBefore(picked)) {
          widget.breakInput.endDate = picked.add(const Duration(days: 1));
        }
      });
      widget.onChanged();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showCustomDatePicker(
      context: context,
      initialDate: widget.breakInput.endDate ?? widget.breakInput.startDate?.add(const Duration(days: 6)) ?? DateTime.now(),
      firstDate: widget.breakInput.startDate ?? widget.semesterStartDate ?? DateTime(2020),
      lastDate: widget.semesterEndDate ?? DateTime(2030),
      firstDayOfWeek: 1,
    );

    if (picked != null) {
      setState(() {
        widget.breakInput.endDate = picked;
      });
      widget.onChanged();
    }
  }

  String? get durationString {
    if (widget.breakInput.startDate == null || widget.breakInput.endDate == null) {
      return null;
    }
    final days = widget.breakInput.endDate!.difference(widget.breakInput.startDate!).inDays + 1;
    if (days < 7) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else {
      final weeks = (days / 7).round();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
  }

  String? get weekNumberInfo {
    if (widget.breakInput.startDate == null || widget.semesterStartDate == null) {
      return null;
    }

    final startWeek = utils.DateUtils.getWeekNumber(
      widget.breakInput.startDate!,
      widget.semesterStartDate!,
    );

    if (widget.breakInput.endDate != null) {
      final endWeek = utils.DateUtils.getWeekNumber(
        widget.breakInput.endDate!,
        widget.semesterStartDate!,
      );

      if (startWeek == endWeek) {
        return 'Week $startWeek';
      } else {
        return 'Weeks $startWeek-$endWeek';
      }
    }

    return 'Week $startWeek';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 500;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (only for first card)
                if (widget.showHeader) ...[
                  Row(
                    children: [
                      Icon(Icons.event_busy, color: const Color(0xFF10B981), size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Breaks (Optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (widget.onAddAnother != null)
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: widget.onAddAnother,
                          tooltip: 'Add another break',
                          color: Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Reading Weeks, Easter Breaks etc.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Break Name Field + Delete Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: isMobile ? constraints.maxWidth - 56 : constraints.maxWidth * 0.6,
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Break Name',
                          hintText: 'e.g., Reading Week, Easter Break',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                        ),
                        onChanged: (value) {
                          widget.breakInput.name = value;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: widget.onRemove,
                        tooltip: 'Remove break',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date selection
                if (isMobile)
                  Column(
                    children: [
                      InkWell(
                        onTap: _selectStartDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Date',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.breakInput.startDate != null
                                          ? '${widget.breakInput.startDate!.day}/${widget.breakInput.startDate!.month}/${widget.breakInput.startDate!.year}'
                                          : 'Tap to select',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: widget.breakInput.startDate != null
                                            ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                            : Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: widget.breakInput.startDate != null ? _selectEndDate : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.breakInput.startDate != null ? Colors.grey[300]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Date',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: widget.breakInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: widget.breakInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.breakInput.endDate != null
                                          ? '${widget.breakInput.endDate!.day}/${widget.breakInput.endDate!.month}/${widget.breakInput.endDate!.year}'
                                          : (widget.breakInput.startDate != null ? 'Tap to select' : 'Select start first'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: widget.breakInput.endDate != null
                                            ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                            : Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.breakInput.startDate != null
                                            ? '${widget.breakInput.startDate!.day}/${widget.breakInput.startDate!.month}/${widget.breakInput.startDate!.year}'
                                            : 'Tap to select',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: widget.breakInput.startDate != null
                                              ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                              : Colors.grey[500],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: widget.breakInput.startDate != null ? _selectEndDate : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.breakInput.startDate != null ? Colors.grey[300]! : Colors.grey[200]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: widget.breakInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: widget.breakInput.startDate != null ? Colors.grey[600] : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.breakInput.endDate != null
                                            ? '${widget.breakInput.endDate!.day}/${widget.breakInput.endDate!.month}/${widget.breakInput.endDate!.year}'
                                            : (widget.breakInput.startDate != null ? 'Tap to select' : 'Select start first'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: widget.breakInput.endDate != null
                                              ? (isDarkMode ? Colors.grey[200] : Colors.grey[900])
                                              : Colors.grey[500],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Badges at bottom (only if dates selected)
                if (durationString != null || weekNumberInfo != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Duration badge
                      if (durationString != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_note,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                durationString!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Week number badge
                      if (weekNumberInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                weekNumberInfo!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0EA5E9),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
