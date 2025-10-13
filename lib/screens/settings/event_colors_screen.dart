import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/widgets/gradient_header.dart';

class EventColorsScreen extends ConsumerWidget {
  const EventColorsScreen({super.key});

  Future<void> _showColorPickerDialog(
    BuildContext context,
    WidgetRef ref,
    String type,
    Color? currentColor,
  ) async {
    final availableColors = [
      const Color(0xFFF44336), // Red
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF4CAF50), // Green
      const Color(0xFF03A9F4), // Light Blue
      const Color(0xFF1565C0), // Dark Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFE91E63), // Pink
      const Color(0xFF795548), // Brown
      const Color(0xFF9E9E9E), // Grey
    ];

    Color? selectedColor = currentColor;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Choose Colour for $type',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // First row (5 colors)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: availableColors.sublist(0, 5).map((color) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.grey.shade300,
                            width: selectedColor == color ? 3 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Second row (5 colors)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: availableColors.sublist(5, 10).map((color) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? Colors.black
                                : Colors.grey.shade300,
                            width: selectedColor == color ? 3 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedColor != null) {
                  if (type == 'Lecture') {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setLectureColor(selectedColor!);
                  } else if (type == 'Lab/Tutorial') {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setLabTutorialColor(selectedColor!);
                  } else if (type == 'Assignment') {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setAssignmentColor(selectedColor!);
                  }
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
              ),
              child: Text('Save', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPreferences = ref.watch(userPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const GradientHeader(title: 'Event Colors')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lecture Color
                  ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            userPreferences.customLectureColor ??
                            const Color(0xFF1565C0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    title: const Text('Lecture Colour'),
                    subtitle: const Text('Colour for lecture events'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showColorPickerDialog(
                      context,
                      ref,
                      'Lecture',
                      userPreferences.customLectureColor,
                    ),
                  ),
                  const Divider(height: 1),
                  // Lab/Tutorial Color
                  ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            userPreferences.customLabTutorialColor ??
                            const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    title: const Text('Lab/Tutorial Colour'),
                    subtitle: const Text('Colour for lab and tutorial events'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showColorPickerDialog(
                      context,
                      ref,
                      'Lab/Tutorial',
                      userPreferences.customLabTutorialColor,
                    ),
                  ),
                  const Divider(height: 1),
                  // Assignment Color
                  ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            userPreferences.customAssignmentColor ??
                            const Color(0xFFF44336),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                    title: const Text('Assignment Colour'),
                    subtitle: const Text('Colour for assignment events'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showColorPickerDialog(
                      context,
                      ref,
                      'Assignment',
                      userPreferences.customAssignmentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
