import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/note.dart';
import 'package:module_tracker/providers/notes_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:intl/intl.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _editController = TextEditingController();
  String? _editingNoteId;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController(text: 'New Note');
    final contentController = TextEditingController();
    final titleFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          titleFocusNode.addListener(() {
            if (titleFocusNode.hasFocus && titleController.text == 'New Note') {
              titleController.clear();
              setState(() {}); // Rebuild to update text color
            }
          });

          return AlertDialog(
            title: TextField(
              controller: titleController,
              focusNode: titleFocusNode,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  hintText: 'Enter your note...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                autofocus: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  titleFocusNode.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (contentController.text.trim().isNotEmpty) {
                    // If title is still "New Note" or empty, save as empty string
                    final finalTitle = titleController.text == 'New Note' ||
                            titleController.text.isEmpty
                        ? ''
                        : titleController.text;
                    ref.read(notesProvider.notifier).addNote(
                          finalTitle,
                          contentController.text,
                        );
                    titleFocusNode.dispose();
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditNoteDialog(Note note) {
    // Show custom title if exists, otherwise show "Edit Note"
    final initialTitle = note.title.isEmpty ? 'Edit Note' : note.title;
    final titleController = TextEditingController(text: initialTitle);
    final contentController = TextEditingController(text: note.content);
    final titleFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          titleFocusNode.addListener(() {
            if (titleFocusNode.hasFocus && titleController.text == 'Edit Note') {
              titleController.clear();
              setState(() {}); // Rebuild to update text color
            }
          });

          return AlertDialog(
            title: TextField(
              controller: titleController,
              focusNode: titleFocusNode,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  hintText: 'Enter your note...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                autofocus: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  titleFocusNode.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // If title is still "Edit Note" or empty, save as empty string
                  final finalTitle = titleController.text == 'Edit Note' ||
                          titleController.text.isEmpty
                      ? ''
                      : titleController.text;
                  ref.read(notesProvider.notifier).updateNote(
                        note.id,
                        finalTitle,
                        contentController.text,
                      );
                  titleFocusNode.dispose();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Note',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(notesProvider.notifier).deleteNote(note.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const GradientHeader(title: 'Quick Notes'),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final maxContentWidth = 600.0;
              final listPadding = AppSpacing.lg; // Padding used in ReorderableListView

              final padding = screenWidth > maxContentWidth
                  ? (screenWidth - maxContentWidth) / 2 + listPadding
                  : listPadding;

              return Padding(
                padding: EdgeInsets.only(right: padding),
                child: Material(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: _showAddNoteDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first note',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: notes.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.05,
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(notesProvider.notifier)
                        .reorderNotes(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ReorderableDragStartListener(
                      index: index,
                      key: Key(note.id),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _showEditNoteDialog(note),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (note.title.isNotEmpty) ...[
                                            Text(
                                              note.title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Text(
                                            note.content,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                            maxLines: 8,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 12),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Color(0xFFEF4444),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Color(0xFFEF4444),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            _showEditNoteDialog(note);
                                            break;
                                          case 'delete':
                                            _confirmDelete(note);
                                            break;
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  note.updatedAt != null
                                      ? 'Edited ${_formatDate(note.updatedAt!)}'
                                      : _formatDate(note.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
