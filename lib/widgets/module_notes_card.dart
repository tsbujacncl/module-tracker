import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

/// A card widget for displaying and editing module-level notes
/// Features auto-save with debouncing for better UX
class ModuleNotesCard extends ConsumerStatefulWidget {
  final Module module;

  const ModuleNotesCard({
    super.key,
    required this.module,
  });

  @override
  ConsumerState<ModuleNotesCard> createState() => _ModuleNotesCardState();
}

class _ModuleNotesCardState extends ConsumerState<ModuleNotesCard> {
  late TextEditingController _controller;
  Timer? _debounce;
  bool _isSaving = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.module.notes ?? '');
    _isExpanded = (widget.module.notes?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onNotesChanged(String value) {
    // Cancel previous timer
    _debounce?.cancel();

    // Start new timer for auto-save (500ms delay)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _saveNotes(value);
    });
  }

  Future<void> _saveNotes(String notes) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateModuleNotes(
        user.uid,
        widget.module.id,
        notes.isEmpty ? null : notes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving notes: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.notes_outlined,
                    color: const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Quick Notes',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (_isSaving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      ),
                    )
                  else
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: isDarkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                ],
              ),
            ),
          ),

          // Expandable text field
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onNotesChanged,
                maxLines: null,
                minLines: 3,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Add notes about this module...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDarkMode
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    borderSide: const BorderSide(
                      color: Color(0xFF8B5CF6),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
