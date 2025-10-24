import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  TimeOfDay? _reminderTime;
  bool _remindersEnabled = true;
  double _targetGrade = 70.0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getGradeClassification(double grade) {
    if (grade >= 70) return '1st';
    if (grade >= 60) return '2:1';
    if (grade >= 50) return '2:2';
    if (grade >= 40) return '3rd';
    return 'Fail';
  }

  Future<void> _completeOnboarding() async {
    if (_nameController.text.isEmpty) return;

    final prefsNotifier = ref.read(userPreferencesProvider.notifier);

    await prefsNotifier.setUserName(_nameController.text);

    // Save reminder time if enabled
    if (_remindersEnabled && _reminderTime != null) {
      final timeString = '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
      await prefsNotifier.setNotificationTime(timeString);
    } else if (!_remindersEnabled) {
      await prefsNotifier.setNotificationTime('off');
    }

    await prefsNotifier.setTargetGrade(_targetGrade);
    await prefsNotifier.completeOnboarding();

    // No need to manually navigate - AuthWrapper will automatically
    // switch to HomeScreen when hasCompletedOnboarding becomes true
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final canProceed = _nameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFDCEEFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // App title with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        'Module Tracker',
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let\'s get you set up',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Card container
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            _buildSectionLabel('Your Name', required: true),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextField(
                                controller: _nameController,
                                style: GoogleFonts.inter(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'First or preferred name',
                                  filled: true,
                                  fillColor: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Notifications
                            _buildSectionLabel('Daily Reminders', emoji: '🔔'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Switch
                                Switch(
                                  value: _remindersEnabled,
                                  onChanged: (value) {
                                    setState(() => _remindersEnabled = value);
                                  },
                                  activeColor: const Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _remindersEnabled ? 'Enabled' : 'Disabled',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                // Space between toggle and time picker
                                const SizedBox(width: 20),
                                // Time picker button
                                if (_remindersEnabled)
                                  InkWell(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                                      );
                                      if (time != null) {
                                        setState(() => _reminderTime = time);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF3B82F6),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 18,
                                            color: const Color(0xFF3B82F6),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _reminderTime != null
                                                ? _reminderTime!.format(context)
                                                : 'Set time',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Target Grade
                            _buildSectionLabel('Target Grade', emoji: '🎯'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${_targetGrade.toInt()}% ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF3B82F6),
                                          height: 1.0,
                                        ),
                                      ),
                                      Text(
                                        '(${_getGradeClassification(_targetGrade)})',
                                        style: GoogleFonts.poppins(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF3B82F6).withOpacity(0.7),
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Quick select buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildGradeButton(40, isDarkMode),
                                      const SizedBox(width: 8),
                                      _buildGradeButton(50, isDarkMode),
                                      const SizedBox(width: 8),
                                      _buildGradeButton(60, isDarkMode),
                                      const SizedBox(width: 8),
                                      _buildGradeButton(70, isDarkMode),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Slider(
                                    value: _targetGrade,
                                    min: 0,
                                    max: 100,
                                    divisions: 100,
                                    activeColor: const Color(0xFF3B82F6),
                                    onChanged: (value) => setState(() => _targetGrade = value),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Get Started Button inside card
                            Center(
                              child: FilledButton(
                                onPressed: canProceed ? _completeOnboarding : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  disabledBackgroundColor: const Color(0xFF94A3B8),
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Get Started',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {bool required = false, bool optional = false, String? emoji}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        if (optional)
          Text(
            ' (optional)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        if (emoji != null) ...[
          const SizedBox(width: 8),
          Text(emoji, style: const TextStyle(fontSize: 20)),
        ],
      ],
    );
  }

  Widget _buildGradeButton(int grade, bool isDarkMode) {
    final isSelected = _targetGrade.toInt() == grade;
    return InkWell(
      onTap: () => setState(() => _targetGrade = grade.toDouble()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.5,
          ),
        ),
        child: Text(
          '$grade%',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
