import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/services/module_share_service.dart';
import 'package:module_tracker/widgets/module_selection_dialog.dart';

class ModuleShareDialog extends StatefulWidget {
  // For single module sharing
  final Module? module;
  final List<Assessment>? assessments;
  final List<RecurringTask>? tasks;

  // For multi-module sharing
  final List<Module>? modules;
  final Map<String, List<Assessment>>? assessmentsByModule;
  final Map<String, List<RecurringTask>>? tasksByModule;

  final String userId;

  // For back navigation
  final String? semesterId;
  final Module? preSelectedModule;
  final Set<String>? selectedModuleIds;

  const ModuleShareDialog({
    super.key,
    this.module,
    this.assessments,
    this.tasks,
    this.modules,
    this.assessmentsByModule,
    this.tasksByModule,
    required this.userId,
    this.semesterId,
    this.preSelectedModule,
    this.selectedModuleIds,
  });

  // Helper to determine if this is a single or multi-module share
  bool get isSingleModule => module != null;
  bool get isMultiModule => modules != null && modules!.isNotEmpty;

  @override
  State<ModuleShareDialog> createState() => _ModuleShareDialogState();
}

class _ModuleShareDialogState extends State<ModuleShareDialog> {
  final ModuleShareService _shareService = ModuleShareService();
  bool _isGenerating = false;
  String? _shareCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateShareLink();
  }

  Future<void> _generateShareLink() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      String code;

      if (widget.isSingleModule) {
        // Single module sharing
        code = await _shareService.shareModule(
          module: widget.module!,
          assessments: widget.assessments!,
          tasks: widget.tasks!,
          userId: widget.userId,
        );
      } else if (widget.isMultiModule) {
        // Multi-module sharing
        code = await _shareService.shareMultipleModules(
          modules: widget.modules!,
          assessmentsByModule: widget.assessmentsByModule!,
          tasksByModule: widget.tasksByModule!,
          userId: widget.userId,
        );
      } else {
        throw Exception('Invalid dialog state: no modules provided');
      }

      if (mounted) {
        setState(() {
          _shareCode = code;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate share link: ${e.toString()}';
          _isGenerating = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_shareCode == null) return;

    final url = 'https://moduletracker.app/share/$_shareCode';
    Clipboard.setData(ClipboardData(text: url));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link copied to clipboard!',
          style: GoogleFonts.inter(),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _shareVia() {
    if (_shareCode == null) return;

    String message;
    String subject;

    if (widget.isSingleModule) {
      message = _shareService.generateShareMessage(
        widget.module!.code,
        widget.module!.name,
        _shareCode!,
      );
      subject = '${widget.module!.code} - Module Tracker Share';
    } else {
      message = _shareService.generateBundleShareMessage(
        widget.modules!,
        _shareCode!,
      );
      subject = 'Module Tracker - ${widget.modules!.length} Modules';
    }

    Share.share(
      message,
      subject: subject,
    );
  }

  void _goBack() {
    // Close this dialog
    Navigator.pop(context);

    // Reopen module selection dialog with previous state
    if (widget.semesterId != null) {
      showDialog(
        context: context,
        builder: (context) => ModuleSelectionDialog(
          preSelectedModule: widget.preSelectedModule,
          semesterId: widget.semesterId!,
          initialSelectedModuleIds: widget.selectedModuleIds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Back button (only show if we have semester ID for navigation)
                if (widget.semesterId != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _goBack,
                    tooltip: 'Back to module selection',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isSingleModule ? 'Share Module' : 'Share Modules',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        widget.isSingleModule
                            ? widget.module!.code
                            : '${widget.modules!.length} module${widget.modules!.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
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
            const SizedBox(height: 24),

            // What will be shared
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What will be shared:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isSingleModule) ...[
                    _buildShareItem(
                      Icons.school_outlined,
                      'Module Details',
                      '${widget.module!.code} - ${widget.module!.name}',
                    ),
                    const SizedBox(height: 8),
                    _buildShareItem(
                      Icons.assessment_outlined,
                      'Assessments',
                      '${widget.assessments!.length} assessment${widget.assessments!.length != 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 8),
                    _buildShareItem(
                      Icons.task_outlined,
                      'Weekly Tasks',
                      '${widget.tasks!.length} task${widget.tasks!.length != 1 ? 's' : ''}',
                    ),
                  ] else ...[
                    // Multi-module view
                    ..._buildMultiModuleList(),
                    const SizedBox(height: 8),
                    _buildShareItem(
                      Icons.assessment_outlined,
                      'Total Assessments',
                      '${_getTotalAssessments()} assessment${_getTotalAssessments() != 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 8),
                    _buildShareItem(
                      Icons.task_outlined,
                      'Total Tasks',
                      '${_getTotalTasks()} task${_getTotalTasks() != 1 ? 's' : ''}',
                    ),
                  ],
                  const SizedBox(height: 12),
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
                            'Personal progress not included',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share link or loading
            if (_isGenerating)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Generating share link...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else if (_error != null)
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
                          fontSize: 13,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_shareCode != null) ...[
              // Share URL
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Code',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shareCode!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0EA5E9),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'moduletracker.app/share/$_shareCode',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: _copyToClipboard,
                      tooltip: 'Copy link',
                      color: const Color(0xFF0EA5E9),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              if (kIsWeb)
                // Web: Only show Copy Link button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(
                      'Copy Link',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                )
              else
                // Mobile/Desktop: Show both buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(
                          'Copy Link',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0EA5E9),
                          side: const BorderSide(color: Color(0xFF0EA5E9)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareVia,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(
                          'Share Via...',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // Expiry notice
              Text(
                'Link expires in 30 days',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMultiModuleList() {
    if (!widget.isMultiModule) return [];

    final widgets = <Widget>[];
    for (int i = 0; i < widget.modules!.length; i++) {
      final module = widget.modules![i];
      final assessments = widget.assessmentsByModule![module.id] ?? [];
      final tasks = widget.tasksByModule![module.id] ?? [];

      widgets.add(
        _buildShareItem(
          Icons.school_outlined,
          module.code,
          '${module.name} • ${assessments.length} assessment${assessments.length != 1 ? 's' : ''}, ${tasks.length} task${tasks.length != 1 ? 's' : ''}',
        ),
      );

      if (i < widget.modules!.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const Divider(height: 1, color: Color(0xFFE2E8F0)));
    }

    return widgets;
  }

  int _getTotalAssessments() {
    if (!widget.isMultiModule) return 0;
    return widget.assessmentsByModule!.values
        .fold(0, (total, assessments) => total + assessments.length);
  }

  int _getTotalTasks() {
    if (!widget.isMultiModule) return 0;
    return widget.tasksByModule!.values
        .fold(0, (total, tasks) => total + tasks.length);
  }

  Widget _buildShareItem(IconData icon, String title, String subtitle) {
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
}
