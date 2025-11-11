import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';

class WeeklyCompletionDialog extends StatefulWidget {
  final String userName;

  const WeeklyCompletionDialog({
    super.key,
    required this.userName,
  });

  @override
  State<WeeklyCompletionDialog> createState() => _WeeklyCompletionDialogState();
}

class _WeeklyCompletionDialogState extends State<WeeklyCompletionDialog>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late String _selectedEmoji;
  late String _selectedMessage;

  // 5 different party emojis
  static const List<String> _partyEmojis = [
    '🎉', // Party popper
    '🎊', // Confetti ball
    '🥳', // Partying face
    '🌟', // Glowing star
    '🎈', // Balloon
  ];

  // 5 different congratulatory messages (without emojis)
  static const List<String> _messages = [
    'Amazing work, {name}!',
    'You crushed it this week, {name}!',
    'Week completed! Way to go, {name}!',
    'Fantastic job this week, {name}!',
    'All done for the week, {name}!',
  ];

  String _getRandomMessage() {
    final random = Random();
    final message = _messages[random.nextInt(_messages.length)];
    return message.replaceAll('{name}', widget.userName);
  }

  String _getRandomEmoji() {
    final random = Random();
    return _partyEmojis[random.nextInt(_partyEmojis.length)];
  }

  @override
  void initState() {
    super.initState();

    // Select random emoji and message
    _selectedEmoji = _getRandomEmoji();
    _selectedMessage = _getRandomMessage();

    // Setup confetti - reduced duration to avoid debug mode slowdown
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _confettiController.play();

    // Setup entrance animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    // Start entrance animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero, // Make dialog full-screen
      child: Stack(
        children: [
          // Tap detector for dismissing when clicking outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Full-screen confetti coverage - optimized for performance
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // Down
                  blastDirectionality: BlastDirectionality.explosive, // Spread in all directions
                  maxBlastForce: 15,
                  minBlastForce: 5,
                  emissionFrequency: 0.05,
                  numberOfParticles: 15,
                  gravity: 0.1,
                  shouldLoop: false, // Don't loop - just one burst
                  colors: const [
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.purple,
                    Colors.pink,
                  ],
                ),
              ),
            ),
          ),
          // Dialog content - narrower with entrance animation
          Center(
            child: GestureDetector(
              onTap: () {}, // Absorb taps on content so it doesn't dismiss
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(28),
                margin: const EdgeInsets.symmetric(horizontal: 48),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Random celebration emoji
                    Text(
                      _selectedEmoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    // Congratulatory message
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
                      ).createShader(bounds),
                      child: Text(
                        _selectedMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'All tasks completed!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDarkMode
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
