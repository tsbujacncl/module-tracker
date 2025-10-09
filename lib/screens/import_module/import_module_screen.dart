import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/shared_module.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/services/module_share_service.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';

class ImportModuleScreen extends ConsumerStatefulWidget {
  const ImportModuleScreen({super.key});

  @override
  ConsumerState<ImportModuleScreen> createState() => _ImportModuleScreenState();
}

class _ImportModuleScreenState extends ConsumerState<ImportModuleScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ModuleShareService _shareService = ModuleShareService();

  bool _isLoading = false;
  bool _isImporting = false;
  SharedModule? _previewModule;
  SharedModuleBundle? _previewBundle;
  String? _error;
  bool _isBundle = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _error = 'Please enter a share code';
        _previewModule = null;
        _previewBundle = null;
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _error = 'Share code must be 6 characters';
        _previewModule = null;
        _previewBundle = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _previewModule = null;
      _previewBundle = null;
    });

    try {
      // Check if it's a bundle or single module
      final isBundle = await _shareService.isBundle(code);

      if (!mounted) return;

      if (isBundle) {
        // Load bundle
        final bundle = await _shareService.getSharedBundle(code);

        if (!mounted) return;

        if (bundle == null) {
          setState(() {
            _error = 'Share code not found or expired';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _previewBundle = bundle;
          _isBundle = true;
          _isLoading = false;
        });
      } else {
        // Load single module
        final sharedModule = await _shareService.getSharedModule(code);

        if (!mounted) return;

        if (sharedModule == null) {
          setState(() {
            _error = 'Share code not found or expired';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _previewModule = sharedModule;
          _isBundle = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load shared content: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _importModule() async {
    if (_previewModule == null) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final repository = ref.read(firestoreRepositoryProvider);
      final currentSemester = ref.read(currentSemesterProvider);
      final user = ref.read(currentUserProvider);

      if (user == null) {
        throw Exception('User not logged in');
      }

      if (currentSemester == null) {
        throw Exception('No active semester found. Please create a semester first.');
      }

      // Parse color from hex string
      int colorValue;
      try {
        final hexColor = _previewModule!.moduleColor.replaceAll('#', '');
        colorValue = int.parse('FF$hexColor', radix: 16);
      } catch (e) {
        colorValue = 0xFF3B82F6; // Default blue
      }

      // Create new module
      final newModule = Module(
        id: '', // Firestore will generate
        userId: user.uid,
        semesterId: currentSemester.id,
        code: _previewModule!.moduleCode,
        name: _previewModule!.moduleName,
        colorValue: colorValue,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final moduleId = await repository.createModule(user.uid, newModule);

      // Import assessments
      for (final sharedAssessment in _previewModule!.assessments) {
        final assessment = Assessment(
          id: '', // Firestore will generate
          moduleId: moduleId,
          name: sharedAssessment.name,
          type: AssessmentType.coursework, // Default type
          weighting: sharedAssessment.weight,
          dueDate: sharedAssessment.dueDate,
          description: sharedAssessment.description.isEmpty ? null : sharedAssessment.description,
          score: null, // User will fill in later
          markEarned: null, // User will fill in later
        );
        await repository.createAssessment(user.uid, moduleId, assessment);
      }

      // Import recurring tasks
      for (final sharedTask in _previewModule!.tasks) {
        final task = RecurringTask(
          id: '', // Firestore will generate
          moduleId: moduleId,
          type: RecurringTaskType.custom, // Default type for imported tasks
          name: sharedTask.name,
          dayOfWeek: sharedTask.dayOfWeek,
          time: sharedTask.time,
        );
        await repository.createRecurringTask(user.uid, moduleId, task);
      }

      // Increment import count
      await _shareService.incrementImportCount(_previewModule!.id);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Module imported successfully!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      // Go back to home screen
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to import module: ${e.toString()}';
        _isImporting = false;
      });
    }
  }

  Future<void> _importBundle() async {
    if (_previewBundle == null) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final repository = ref.read(firestoreRepositoryProvider);
      final currentSemester = ref.read(currentSemesterProvider);
      final user = ref.read(currentUserProvider);

      if (user == null) {
        throw Exception('User not logged in');
      }

      if (currentSemester == null) {
        throw Exception('No active semester found. Please create a semester first.');
      }

      // Import each module in the bundle
      for (final sharedModule in _previewBundle!.modules) {
        // Parse color from hex string
        int colorValue;
        try {
          final hexColor = sharedModule.moduleColor.replaceAll('#', '');
          colorValue = int.parse('FF$hexColor', radix: 16);
        } catch (e) {
          colorValue = 0xFF3B82F6; // Default blue
        }

        // Create new module
        final newModule = Module(
          id: '', // Firestore will generate
          userId: user.uid,
          semesterId: currentSemester.id,
          code: sharedModule.moduleCode,
          name: sharedModule.moduleName,
          colorValue: colorValue,
          credits: sharedModule.credits,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final moduleId = await repository.createModule(user.uid, newModule);

        // Import assessments for this module
        for (final sharedAssessment in sharedModule.assessments) {
          final assessment = Assessment(
            id: '', // Firestore will generate
            moduleId: moduleId,
            name: sharedAssessment.name,
            type: AssessmentType.coursework, // Default type
            weighting: sharedAssessment.weight,
            dueDate: sharedAssessment.dueDate,
            description: sharedAssessment.description.isEmpty ? null : sharedAssessment.description,
            score: null, // User will fill in later
            markEarned: null, // User will fill in later
          );
          await repository.createAssessment(user.uid, moduleId, assessment);
        }

        // Import recurring tasks for this module
        for (final sharedTask in sharedModule.tasks) {
          final task = RecurringTask(
            id: '', // Firestore will generate
            moduleId: moduleId,
            type: RecurringTaskType.custom, // Default type for imported tasks
            name: sharedTask.name,
            dayOfWeek: sharedTask.dayOfWeek,
            time: sharedTask.time,
          );
          await repository.createRecurringTask(user.uid, moduleId, task);
        }
      }

      // Increment import count
      await _shareService.incrementImportCount(_previewBundle!.id);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_previewBundle!.modules.length} module${_previewBundle!.modules.length != 1 ? 's' : ''} imported successfully!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      // Go back to home screen
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to import modules: ${e.toString()}';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Import Module',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.download_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Import Shared Module',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-character share code to preview and import a module',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Share code input
              Text(
                'Share Code',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ABC123',
                        hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: const Color(0xFF94A3B8),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0EA5E9),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (_error != null || _previewModule != null || _previewBundle != null) {
                          setState(() {
                            _error = null;
                            _previewModule = null;
                            _previewBundle = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _loadPreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loadPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Load',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Preview
              if (_previewModule != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Module header
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _parseColor(_previewModule!.moduleColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _previewModule!.moduleCode,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.titleLarge?.color,
                                  ),
                                ),
                                Text(
                                  _previewModule!.moduleName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // What will be imported
                      Text(
                        'What will be imported:',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Assessments
                      _buildPreviewItem(
                        Icons.assessment_outlined,
                        'Assessments',
                        '${_previewModule!.assessments.length} assessment${_previewModule!.assessments.length != 1 ? 's' : ''}',
                      ),
                      if (_previewModule!.assessments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...(_previewModule!.assessments.map((a) => Padding(
                              padding: const EdgeInsets.only(left: 30, bottom: 4),
                              child: Text(
                                '• ${a.name} (${a.weight}%)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ))),
                      ],

                      const SizedBox(height: 12),

                      // Tasks
                      _buildPreviewItem(
                        Icons.task_outlined,
                        'Weekly Tasks',
                        '${_previewModule!.tasks.length} task${_previewModule!.tasks.length != 1 ? 's' : ''}',
                      ),
                      if (_previewModule!.tasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...(_previewModule!.tasks.map((t) => Padding(
                              padding: const EdgeInsets.only(left: 30, bottom: 4),
                              child: Text(
                                '• ${t.name} (${_getDayName(t.dayOfWeek)}${t.time != null ? ' at ${t.time}' : ''})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ))),
                      ],

                      const SizedBox(height: 16),

                      // Info notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your personal progress will start fresh',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Import button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isImporting ? null : _importModule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isImporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.download_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Import Module',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Import count
                      Text(
                        'Imported ${_previewModule!.importCount} time${_previewModule!.importCount != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              // Bundle Preview
              if (_previewBundle != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bundle header
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.folder_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Module Bundle',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.titleLarge?.color,
                                  ),
                                ),
                                Text(
                                  '${_previewBundle!.modules.length} module${_previewBundle!.modules.length != 1 ? 's' : ''} included',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Module list
                      Text(
                        'Modules in this bundle:',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List each module
                      ...(_previewBundle!.modules.asMap().entries.map((entry) {
                        final index = entry.key;
                        final module = entry.value;
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: index < _previewBundle!.modules.length - 1 ? 12 : 0,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _parseColor(module.moduleColor),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${module.moduleCode} - ${module.moduleName}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${module.assessments.length} assessment${module.assessments.length != 1 ? 's' : ''}, ${module.tasks.length} task${module.tasks.length != 1 ? 's' : ''}',
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
                      })),

                      const SizedBox(height: 20),

                      // Total summary
                      Text(
                        'Total contents:',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildPreviewItem(
                        Icons.assessment_outlined,
                        'Assessments',
                        '${_previewBundle!.totalAssessments} assessment${_previewBundle!.totalAssessments != 1 ? 's' : ''} across all modules',
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewItem(
                        Icons.task_outlined,
                        'Weekly Tasks',
                        '${_previewBundle!.totalTasks} task${_previewBundle!.totalTasks != 1 ? 's' : ''} across all modules',
                      ),

                      const SizedBox(height: 16),

                      // Info notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your personal progress will start fresh for all modules',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Import button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isImporting ? null : _importBundle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isImporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.download_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Import All Modules',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Import count
                      Text(
                        'Imported ${_previewBundle!.importCount} time${_previewBundle!.importCount != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return const Color(0xFF3B82F6);
    }
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}

/// Text formatter to convert input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
