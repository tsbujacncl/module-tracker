import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/theme_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/providers/customization_provider.dart';
import 'package:module_tracker/models/customization_preferences.dart';
import 'package:module_tracker/screens/settings/notification_settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
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
              if (_newPasswordController.text != _confirmPasswordController.text) {
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

              setState(() => _isChangingPassword = true);

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
                  setState(() => _isChangingPassword = false);
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
    );
  }

  Future<void> _showLogoutDialog() async {
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

  Future<void> _showThemeDialog() async {
    final currentTheme = ref.read(themeProvider);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(mode.displayName),
              subtitle: Text(_getThemeDescription(mode)),
              secondary: Icon(mode.icon),
              value: mode,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
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

  String _getThemeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Always use light theme';
      case AppThemeMode.dark:
        return 'Always use dark theme';
      case AppThemeMode.system:
        return 'Follow device settings';
    }
  }

  Future<void> _showWeekStartDialog(WeekStartDay current) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Week Starts On'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WeekStartDay.values.map((day) {
            return RadioListTile<WeekStartDay>(
              title: Text(day.displayName),
              value: day,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(customizationProvider.notifier).setWeekStartDay(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showGradeFormatDialog(GradeDisplayFormat current) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grade Display Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GradeDisplayFormat.values.map((format) {
            return RadioListTile<GradeDisplayFormat>(
              title: Text(format.displayName),
              value: format,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref.read(customizationProvider.notifier).setGradeDisplayFormat(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showColorPickerDialog(String type, Color? currentColor) async {
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Colour for $type',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
                      if (type == 'Lecture') {
                        ref.read(userPreferencesProvider.notifier).setLectureColor(color);
                      } else if (type == 'Lab/Tutorial') {
                        ref.read(userPreferencesProvider.notifier).setLabTutorialColor(color);
                      } else if (type == 'Assignment') {
                        ref.read(userPreferencesProvider.notifier).setAssignmentColor(color);
                      }
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentColor == color ? Colors.black : Colors.grey.shade300,
                          width: currentColor == color ? 3 : 2,
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
                      if (type == 'Lecture') {
                        ref.read(userPreferencesProvider.notifier).setLectureColor(color);
                      } else if (type == 'Lab/Tutorial') {
                        ref.read(userPreferencesProvider.notifier).setLabTutorialColor(color);
                      } else if (type == 'Assignment') {
                        ref.read(userPreferencesProvider.notifier).setAssignmentColor(color);
                      }
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentColor == color ? Colors.black : Colors.grey.shade300,
                          width: currentColor == color ? 3 : 2,
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
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(),
            ),
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
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currentTheme = ref.watch(themeProvider);
    final userPreferences = ref.watch(userPreferencesProvider);
    final customizationPrefs = ref.watch(customizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                // Account Section
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.account_circle_outlined,
                                color: Color(0xFF0EA5E9),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Account',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(user?.email ?? 'Not logged in'),
                        subtitle: const Text('Email address'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your account password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showChangePasswordDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_outlined),
                        title: const Text('Log Out'),
                        subtitle: const Text('Sign out of your account'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showLogoutDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFEF4444),
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                        subtitle: const Text('Permanently delete your account'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 24),
                // Customisation Section
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEC4899).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.palette_outlined,
                                color: Color(0xFFEC4899),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Customisation',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(currentTheme.icon),
                        title: const Text('Theme'),
                        subtitle: Text(currentTheme.displayName),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showThemeDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Week Starts On'),
                        subtitle: Text(customizationPrefs.weekStartDay.displayName),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showWeekStartDialog(customizationPrefs.weekStartDay),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.grade),
                        title: const Text('Grade Display Format'),
                        subtitle: Text(customizationPrefs.gradeDisplayFormat.displayName),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showGradeFormatDialog(customizationPrefs.gradeDisplayFormat),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        subtitle: const Text('Manage reminders and alerts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: userPreferences.customLectureColor ?? const Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: const Text('Lecture Colour'),
                        subtitle: const Text('Colour for lecture events'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showColorPickerDialog('Lecture', userPreferences.customLectureColor),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: userPreferences.customLabTutorialColor ?? const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: const Text('Lab/Tutorial Colour'),
                        subtitle: const Text('Colour for lab and tutorial events'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showColorPickerDialog('Lab/Tutorial', userPreferences.customLabTutorialColor),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: userPreferences.customAssignmentColor ?? const Color(0xFFF44336),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: const Text('Assignment Colour'),
                        subtitle: const Text('Colour for assignment events'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showColorPickerDialog('Assignment', userPreferences.customAssignmentColor),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(height: 24),
                  // Support Section
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.coffee_outlined,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      title: const Text('Buy Me a Coffee'),
                      subtitle: const Text('Support the development'),
                      trailing: const Icon(Icons.open_in_new, size: 20),
                      onTap: () async {
                        final url = Uri.parse('https://buymeacoffee.com/tyrbujac');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Designer credit
                  Text(
                    'Designed by Tyr @ tyrbujac.com',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
