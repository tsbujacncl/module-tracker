import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/theme_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/providers/customization_provider.dart';
import 'package:module_tracker/models/customization_preferences.dart';
import 'package:module_tracker/screens/settings/notification_settings_screen.dart';
import 'package:module_tracker/screens/settings/event_colors_screen.dart';
import 'package:module_tracker/screens/import_module/import_module_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:module_tracker/widgets/hover_scale_widget.dart';
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/widgets/user_avatar.dart';

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
                  ref
                      .read(customizationProvider.notifier)
                      .setWeekStartDay(value);
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
                  ref
                      .read(customizationProvider.notifier)
                      .setGradeDisplayFormat(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
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

  Future<void> _showBirthdayPicker() async {
    final currentBirthday = ref.read(userPreferencesProvider).birthday;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Your Birthday',
    );

    if (selectedDate != null) {
      await ref
          .read(userPreferencesProvider.notifier)
          .setBirthday(selectedDate);
    }
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currentTheme = ref.watch(themeProvider);
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
                                    child: Text(
                                      'Account: ${userPreferences.userName ?? 'Set name'}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18 * scaleFactor,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
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
                          // Email row - informational only, no tap, no chevron
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
                            subtitle: Text(
                              'Email address',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.cake_outlined,
                              size: 24 * scaleFactor,
                            ),
                            title: Text(
                              userPreferences.birthday != null
                                  ? '${userPreferences.birthday!.day}/${userPreferences.birthday!.month}/${userPreferences.birthday!.year}'
                                  : 'Set your birthday',
                            ),
                            subtitle: const Text('Birthday'),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showBirthdayPicker,
                          ),
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
                          ListTile(
                            leading: Icon(
                              Icons.logout_outlined,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Log Out'),
                            subtitle: const Text('Sign out of your account'),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showLogoutDialog,
                          ),
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
                            onTap: () {
                              // Show module selection dialog for sharing
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Go to a module card and use the share option from the menu',
                                  ),
                                  backgroundColor: Color(0xFF0EA5E9),
                                ),
                              );
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
                              currentTheme.icon,
                              size: 24 * scaleFactor,
                            ),
                            title: const Text('Theme'),
                            subtitle: Text(currentTheme.displayName),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: _showThemeDialog,
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
                            leading: Icon(Icons.grade, size: 24 * scaleFactor),
                            title: const Text('Grade Display Format'),
                            subtitle: Text(
                              customizationPrefs.gradeDisplayFormat.displayName,
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () => _showGradeFormatDialog(
                              customizationPrefs.gradeDisplayFormat,
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
                              'Customize lecture, lab, and assignment colors',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 24 * scaleFactor,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EventColorsScreen(),
                                ),
                              );
                            },
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
                                  height: 150,
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
                    const SizedBox(height: 44),
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
                    const SizedBox(height: 8),
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
