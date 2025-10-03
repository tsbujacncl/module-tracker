import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:intl/intl.dart';

class AssessmentDetailScreen extends ConsumerStatefulWidget {
  final Assessment assessment;
  final Module module;

  const AssessmentDetailScreen({
    super.key,
    required this.assessment,
    required this.module,
  });

  @override
  ConsumerState<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends ConsumerState<AssessmentDetailScreen> {
  late TextEditingController _markController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _markController = TextEditingController(
      text: widget.assessment.markEarned?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _markController.dispose();
    super.dispose();
  }

  Future<void> _saveMark() async {
    final markText = _markController.text.trim();
    final mark = markText.isEmpty ? null : double.tryParse(markText);

    if (mark != null && (mark < 0 || mark > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mark must be between 0 and 100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(markEarned: mark).toFirestore(),
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mark saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assessment Details',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            // Assessment Card
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Module Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.module.code} - ${widget.module.name}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assessment Name
                  Text(
                    widget.assessment.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assessment Type and Weighting
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.assessment.type.toString().split('.').last[0].toUpperCase() +
                              widget.assessment.type.toString().split('.').last.substring(1),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.assessment.weighting.toStringAsFixed(0)}% of grade',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Due Date
                  if (widget.assessment.dueDate != null)
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Due Date',
                      value: dateFormat.format(widget.assessment.dueDate!),
                    ),
                  if (widget.assessment.description != null &&
                      widget.assessment.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.description_outlined,
                      label: 'Description',
                      value: widget.assessment.description!,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  // Mark Input Section
                  Text(
                    'Mark Achieved',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _markController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mark (%)',
                              hintText: 'Enter mark (0-100)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixText: '%',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _saveMark,
                          icon: const Icon(Icons.check, color: Colors.green),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.1),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _markController.text =
                                  widget.assessment.markEarned?.toStringAsFixed(1) ?? '';
                              _isEditing = false;
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: widget.assessment.markEarned != null
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFF64748B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.assessment.markEarned != null
                                      ? Icons.check_circle_outline
                                      : Icons.pending_outlined,
                                  color: widget.assessment.markEarned != null
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.assessment.markEarned != null
                                      ? '${widget.assessment.markEarned!.toStringAsFixed(1)}%'
                                      : 'Not graded yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: widget.assessment.markEarned != null
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          icon: const Icon(Icons.edit),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                            foregroundColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Show contribution to overall grade if mark is entered
                  if (widget.assessment.markEarned != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate_outlined,
                            color: Color(0xFF8B5CF6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contribution to overall grade',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                          Text(
                            '${((widget.assessment.markEarned! / 100) * widget.assessment.weighting).toStringAsFixed(2)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
