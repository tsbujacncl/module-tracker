import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/providers/customization_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/models/customization_preferences.dart';
import 'package:module_tracker/screens/settings/notification_settings_screen.dart';
import 'package:module_tracker/screens/import_module/import_module_screen.dart';
import 'package:module_tracker/utils/date_picker_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:module_tracker/widgets/hover_scale_widget.dart';
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/widgets/user_avatar.dart';
import 'package:module_tracker/widgets/module_selection_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isChangingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  /// Get responsive scale factor for smooth scaling across screen sizes
  /// Mobile (<600px): 1.0x
  /// Tablet (600-900px): smoothly 1.0x → 1.1x
  /// Desktop (>900px): smoothly 1.1x → 1.2x
  double _getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 1.0;
    } else if (width < 900) {
      // Smooth interpolation from 1.0 to 1.1 between 600-900px
      final progress = (width - 600) / 300; // 0.0 to 1.0
      return 1.0 + (0.1 * progress);
    } else {
      // Smooth interpolation from 1.1 to 1.2 between 900-1200px
      final progress = ((width - 900) / 300).clamp(
        0.0,
        1.0,
      ); // 0.0 to 1.0, capped at 1200px
      return 1.1 + (0.1 * progress);
    }
  }

  /// Get responsive horizontal padding for smooth margin scaling
  /// Mobile (<600px): 16px each side
  /// Tablet (600-900px): smoothly 16px → 40px
  /// Desktop (900-1200px): smoothly 40px → 60px
  /// Large Desktop (>1200px): capped at 60px
  double _getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 16.0;
    } else if (width < 900) {
      // Smooth interpolation from 16 to 40 between 600-900px
      final progress = (width - 600) / 300; // 0.0 to 1.0
      return 16.0 + (24.0 * progress); // 16 + 24 = 40
    } else {
      // Smooth interpolation from 40 to 60 between 900-1200px
      final progress = ((width - 900) / 300).clamp(
        0.0,
        1.0,
      ); // Capped at 1200px
      return 40.0 + (20.0 * progress); // 40 + 20 = 60
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _showCurrentPassword = false;
    _showNewPassword = false;
    _showConfirmPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _showCurrentPassword = !_showCurrentPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showCurrentPassword,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNewPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _showNewPassword = !_showNewPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showNewPassword,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showConfirmPassword,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (_newPasswordController.text !=
                    _confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (_newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setDialogState(() => _isChangingPassword = true);

                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.changePassword(
                    _currentPasswordController.text,
                    _newPasswordController.text,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => _isChangingPassword = false);
                  }
                }
              },
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final isGuest = ref.read(isGuestUserProvider);

    if (isGuest) {
      // Guest-specific warning dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: const Color(0xFFF59E0B),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Exit Guest Mode?')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All your data will be permanently deleted!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This includes:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildDataItem('All semesters'),
              _buildDataItem('All modules and course info'),
              _buildDataItem('All tasks and assessments'),
              _buildDataItem('All settings and preferences'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Create an account first to save your data.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF10B981)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showCreateAccountFromGuestDialog();
              },
              child: Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              onPressed: () async {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to login screen
                }
              },
              child: const Text('Delete Data & Exit'),
            ),
          ],
        ),
      );
    } else {
      // Normal logout dialog for authenticated users
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to login screen
                }
              },
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDataItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.close,
            size: 16,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWeekStartDialog(WeekStartDay current) async {
    WeekStartDay? tempWeekStart = current;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Week Starts On'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: WeekStartDay.values.map((day) {
              return RadioListTile<WeekStartDay>(
                title: Text(day.displayName),
                value: day,
                groupValue: tempWeekStart,
                onChanged: (value) {
                  setState(() {
                    tempWeekStart = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempWeekStart != null) {
                  ref
                      .read(customizationProvider.notifier)
                      .setWeekStartDay(tempWeekStart!);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTargetGradeDialog() async {
    final currentTarget = ref.read(userPreferencesProvider).targetGrade;
    double tempTarget = currentTarget;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Target Grade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set your target grade for all modules',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${tempTarget.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                  Text(
                    '%',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempTarget,
                min: 40.0,
                max: 100.0,
                divisions: 60,
                label: '${tempTarget.toStringAsFixed(0)}%',
                onChanged: (value) {
                  setState(() {
                    tempTarget = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '40% (Pass)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '70% (First)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '100%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(userPreferencesProvider.notifier)
                    .setTargetGrade(tempTarget);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEventColorsDialog() async {
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

    // State for view management - declared outside builder to persist across rebuilds
    String currentView = 'list'; // 'list' or 'picker'
    String? selectedEventType;
    Color? selectedColor;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final userPreferences = ref.watch(userPreferencesProvider);

          return AlertDialog(
            title: Row(
              children: [
                if (currentView == 'picker')
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        currentView = 'list';
                        selectedEventType = null;
                        selectedColor = null;
                      });
                    },
                  ),
                Expanded(
                  child: Text(
                    currentView == 'list'
                      ? 'Event Colors'
                      : 'Choose Colour for $selectedEventType',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.only(top: 20),
            content: Container(
              width: 320,
              height: 240,
              constraints: const BoxConstraints(
                minWidth: 320,
                maxWidth: 320,
                minHeight: 240,
                maxHeight: 240,
              ),
              child: currentView == 'list'
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        // Lecture Color
                        ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: userPreferences.customLectureColor ??
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
                          onTap: () {
                            setState(() {
                              currentView = 'picker';
                              selectedEventType = 'Lecture';
                              selectedColor = userPreferences.customLectureColor;
                            });
                          },
                        ),
                        const Divider(height: 1),
                        // Lab/Tutorial Color
                        ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: userPreferences.customLabTutorialColor ??
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
                          onTap: () {
                            setState(() {
                              currentView = 'picker';
                              selectedEventType = 'Lab/Tutorial';
                              selectedColor = userPreferences.customLabTutorialColor;
                            });
                          },
                        ),
                        const Divider(height: 1),
                        // Assignment Color
                        ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: userPreferences.customAssignmentColor ??
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
                          onTap: () {
                            setState(() {
                              currentView = 'picker';
                              selectedEventType = 'Assignment';
                              selectedColor = userPreferences.customAssignmentColor;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            actions: [
              if (currentView == 'list')
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                )
              else ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentView = 'list';
                      selectedEventType = null;
                      selectedColor = null;
                    });
                  },
                  child: Text('Cancel', style: GoogleFonts.inter()),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedColor != null && selectedEventType != null) {
                      if (selectedEventType == 'Lecture') {
                        ref
                            .read(userPreferencesProvider.notifier)
                            .setLectureColor(selectedColor!);
                      } else if (selectedEventType == 'Lab/Tutorial') {
                        ref
                            .read(userPreferencesProvider.notifier)
                            .setLabTutorialColor(selectedColor!);
                      } else if (selectedEventType == 'Assignment') {
                        ref
                            .read(userPreferencesProvider.notifier)
                            .setAssignmentColor(selectedColor!);
                      }
                    }
                    setState(() {
                      currentView = 'list';
                      selectedEventType = null;
                      selectedColor = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                  child: Text('Save', style: GoogleFonts.inter(color: Colors.white)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNameDialog() async {
    final currentName = ref.read(userPreferencesProvider).userName ?? '';
    _nameController.text = currentName;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                await ref
                    .read(userPreferencesProvider.notifier)
                    .setUserName(name);
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action cannot be undone. All your data will be permanently deleted.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Enter your password to confirm',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your password'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final authService = ref.read(authServiceProvider);
                await authService.deleteAccount(passwordController.text);

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to login screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateAccountFromGuestDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_circle,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Create Your Account')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Convert your guest account to a full account to sync your data across devices.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose how to create your account:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Email/Password Option
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.email, color: Colors.white),
              label: Text(
                'Continue with Email',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showEmailPasswordLinkDialog();
              },
            ),
            const SizedBox(height: 12),
            // Google Option
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              icon: Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4285F4),
                          Color(0xFFDB4437),
                          Color(0xFFF4B400),
                          Color(0xFF0F9D58),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _linkWithGoogle();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailPasswordLinkDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPassword = false;
    bool showConfirmPassword = false;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Account with Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email and password to create your account. Your guest data will be preserved.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => showPassword = !showPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validation
                      if (emailController.text.isEmpty ||
                          !emailController.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (passwordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (passwordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final authService = ref.read(authServiceProvider);
                        await authService.linkWithEmailAndPassword(
                          emailController.text.trim(),
                          passwordController.text,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account created successfully! Your data has been preserved.',
                              ),
                              backgroundColor: Color(0xFF10B981),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _linkWithGoogle() async {
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.linkWithGoogle();

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account linked with Google successfully! Your data has been preserved.',
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestUserProvider);
    final userPreferences = ref.watch(userPreferencesProvider);
    final customizationPrefs = ref.watch(customizationProvider);
    final scaleFactor = _getScaleFactor(context);
    final horizontalPadding = _getHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(title: const GradientHeader(title: 'Settings')),
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // Account Section
                    Card(
                      child: Column(
                        children: [
                          // Account section header with avatar and name - tappable to edit
                          InkWell(
                            onTap: _showNameDialog,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // User avatar
                                  UserAvatar(
                                    name: userPreferences.userName ?? 'User',
                                    size: 44 * scaleFactor,
                                  ),
                                  const SizedBox(width: 12),
                                  // Account: Name text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                userPreferences.userName != null
                                                    ? 'Account: ${userPreferences.userName}'
                                                    : 'Your Name',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18 * scaleFactor,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ),
                                            if (isGuest) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF59E0B,
                                                  ).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'GUEST',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11 * scaleFactor,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFFF59E0B),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (userPreferences.userName == null && !isGuest)
                                          Text(
                                            'Tap to set your name',
                                            style: GoogleFonts.inter(
                                              fontSize: 13 * scaleFactor,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        if (isGuest)
                                          Text(
                                            'Create account to sync across devices',
                                            style: GoogleFonts.inter(
                                              fontSize: 13 * scaleFactor,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: const Color(0xFF94A3B8),
                                    size: 24 * scaleFactor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          // Email row - informational only for authenticated, guest mode info for guests
                          if (isGuest)
                            ListTile(
                              leading: Icon(
                                Icons.person_off_outlined,
                                color: const Color(0xFFF59E0B),
                                size: 24 * scaleFactor,
                              ),
                              title: const Text('Guest Mode'),
                              subtitle: const Text(
                                'Limited features - create account to unlock all features',
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'GUEST',
                                  style: GoogleFonts.inter(
                                    fontSize: 11 * scaleFactor,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF59E0B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListTile(
                              leading: Icon(
                                Icons.email_outlined,
                                color: Colors.grey.shade600,
                                size: 24 * scaleFactor,
                              ),
                              title: Text(
                                user?.email ?? 'Not logged in',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          const Divider(height: 1),
                          // Create Account button - only for guests
                          if (isGuest) ...[
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_circle,
                                  color: const Color(0xFF10B981),
                                  size: 24 * scaleFactor,
                                ),
                              ),
                              title: Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              subtitle: const Text(
                                'Sync your data and access from any device',
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: const Color(0xFF10B981),
                                size: 24 * scaleFactor,
                              ),
                              tileColor: const Color(0xFF10B981).withValues(alpha: 0.05),
                              onTap: _showCreateAccountFromGuestDialog,
                            ),
                            const Divider(height: 1),
                          ],
                          // Hide Change Password for guests (they don't have a password)
                          if (!isGuest) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                Icons.lock_outline,
                                size: 24 * scaleFactor,
                              ),
                              title: const Text('Change Password'),
                              subtitle: const Text(
                                'Update your account password',
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                size: 24 * scaleFactor,
                              ),
                              onTap: _showChangePasswordDialog,
                            ),
                            const Divider(height: 1),
                          ] else
                            const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              isGuest ? Icons.exit_to_app : Icons.logout_outlined,
                              size: 24 * scaleFactor,
                              color: isGuest ? const Color(0xFFEF4444) : null,
                            ),
                            title: Text(
                              isGuest ? 'Exit Guest Mode' : 'Log Out',
                              style: TextStyle(
                                color: isGuest ? const Color(0xFFEF4444) : null,
                              ),
                            ),
                            subtitle: Text(
                              isGuest
                                  ? 'Warning: Your data will be deleted'
                                  : 'Sign out of your account',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showLogoutDialog,
                          ),
                          // Hide Delete Account for guests
                          if (!isGuest) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: const Color(0xFFEF4444),
                                size: 24 * scaleFactor,
                              ),
                              title: const Text(
                                'Delete Account',
                                style: TextStyle(color: Color(0xFFEF4444)),
                              ),
                              subtitle: const Text(
                                'Permanently delete your account',
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                size: 24 * scaleFactor,
                              ),
                              onTap: _showDeleteAccountDialog,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Modules Section
                    Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.school_outlined,
                                    color: const Color(0xFF10B981),
                                    size: 20 * scaleFactor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Modules',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.download_rounded,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Import Module'),
                            subtitle: const Text('Import a shared module'),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ImportModuleScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.share_rounded,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Share Module'),
                            subtitle: const Text('Share a module with others'),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () async {
                              // Get current semester
                              final selectedSemester = ref.read(selectedSemesterProvider);

                              if (selectedSemester == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No active semester found. Please set up a semester first.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                                return;
                              }

                              // Show loading dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Loading modules...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              try {
                                // Wait for modules to load
                                final modulesAsync = await ref.read(
                                  modulesForSemesterProvider(selectedSemester.id).future,
                                );

                                if (!mounted) return;

                                // Dismiss loading dialog
                                Navigator.pop(context);

                                if (modulesAsync.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No modules found. Please add a module first.'),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                  return;
                                }

                                // Show module selection dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => ModuleSelectionDialog(
                                    preSelectedModule: null,
                                    semesterId: selectedSemester.id,
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;

                                // Dismiss loading dialog
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error loading modules: $error'),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Customisation Section
                    Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEC4899,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.palette_outlined,
                                    color: const Color(0xFFEC4899),
                                    size: 20 * scaleFactor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Customisation',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.calendar_today,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Week Starts On'),
                            subtitle: Text(
                              customizationPrefs.weekStartDay.displayName,
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () => _showWeekStartDialog(
                              customizationPrefs.weekStartDay,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.flag_outlined,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Target Grade'),
                            subtitle: Text(
                              '${userPreferences.targetGrade.toStringAsFixed(0)}%',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showTargetGradeDialog,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.notifications_outlined,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Notifications'),
                            subtitle: const Text('Manage reminders and alerts'),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationSettingsScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.palette_outlined,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Event Colors'),
                            subtitle: const Text(
                              'Customise lecture, lab, and assignment colors',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showEventColorsDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Support Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Enjoying the app? Support the development',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        GlowPulseWidget(
                          glowColor: const Color(0xFFFFC107),
                          onTap: () async {
                            final url = Uri.parse(
                              'https://buymeacoffee.com/tyrbujac',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                Image.asset(
                                  'assets/images/buy_me_a_coffee_button.png',
                                  height: 135,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.open_in_new,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Designer credit
                    Text(
                      'Designed by Tyr @ tyrbujac.com',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
