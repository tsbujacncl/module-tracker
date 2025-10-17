import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/widgets/shared/gradient_button.dart';
import 'package:module_tracker/utils/responsive_helper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCreatingAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Build responsive header (logo + title)
  Widget _buildHeader(ScreenSize screenSize) {
    final logoSize = ResponsiveHelper.getLogoSize(screenSize);
    final logoIconSize = ResponsiveHelper.getLogoIconSize(screenSize);
    final titleFontSize = ResponsiveHelper.getTitleFontSize(screenSize);
    final subtitleFontSize = ResponsiveHelper.getSubtitleFontSize(screenSize);
    final logoToTitleSpacing = ResponsiveHelper.getSpacing('logo_to_title', screenSize);
    final titleToSubtitleSpacing = ResponsiveHelper.getSpacing('title_to_subtitle', screenSize);
    final isHorizontal = ResponsiveHelper.useHorizontalHeader(screenSize);
    final logoBorderRadius = ResponsiveHelper.getLogoBorderRadius(screenSize);

    // Logo widget
    final logo = Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(logoBorderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.school_rounded,
        size: logoIconSize,
        color: Colors.white,
      ),
    );

    // Title widget
    final title = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
      ).createShader(bounds),
      child: Text(
        'Module Tracker',
        style: GoogleFonts.poppins(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        textAlign: isHorizontal ? TextAlign.left : TextAlign.center,
      ),
    );

    // Subtitle widget
    final subtitle = Text(
      'Track your university modules and tasks',
      style: GoogleFonts.inter(
        fontSize: subtitleFontSize,
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.w400,
      ),
      textAlign: isHorizontal ? TextAlign.left : TextAlign.center,
    );

    if (isHorizontal) {
      // Horizontal layout for small screens
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              logo,
              SizedBox(width: logoToTitleSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    SizedBox(height: titleToSubtitleSpacing),
                    subtitle,
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Vertical layout for larger screens
      return Column(
        children: [
          Center(child: logo),
          SizedBox(height: logoToTitleSpacing),
          title,
          SizedBox(height: titleToSubtitleSpacing),
          subtitle,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveHelper.getScreenSize(MediaQuery.of(context).size.height);
    final outerPadding = ResponsiveHelper.getOuterPadding(screenSize);
    final cardPadding = ResponsiveHelper.getCardPadding(screenSize);
    final subtitleToCardSpacing = ResponsiveHelper.getSpacing('subtitle_to_card', screenSize);
    final welcomeTitleSize = ResponsiveHelper.getWelcomeTitleSize(screenSize);
    final welcomeToFormSpacing = ResponsiveHelper.getSpacing('welcome_to_form', screenSize);
    final fieldGap = ResponsiveHelper.getSpacing('field_gap', screenSize);
    final fieldToButtonSpacing = ResponsiveHelper.getSpacing('field_to_button', screenSize);
    final buttonGap = ResponsiveHelper.getSpacing('button_gap', screenSize);
    final dividerSpacing = ResponsiveHelper.getSpacing('divider_spacing', screenSize);
    final socialButtonGap = ResponsiveHelper.getSpacing('social_button_gap', screenSize);
    final buttonVerticalPadding = ResponsiveHelper.getButtonVerticalPadding(screenSize);
    final buttonFontSize = ResponsiveHelper.getButtonFontSize(screenSize);
    final textFieldPadding = ResponsiveHelper.getTextFieldPadding(screenSize);
    final textFieldFontSize = ResponsiveHelper.getTextFieldFontSize(screenSize);

    return Scaffold(
      body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(outerPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Header (logo + title)
                    _buildHeader(screenSize),
                    SizedBox(height: subtitleToCardSpacing),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isCreatingAccount ? 'Create Your Account' : 'Welcome Back!',
                          style: GoogleFonts.poppins(
                            fontSize: welcomeTitleSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: welcomeToFormSpacing),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(fontSize: textFieldFontSize),
                          onFieldSubmitted: (_) {
                            _passwordFocusNode.requestFocus();
                          },
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            contentPadding: textFieldPadding,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: fieldGap),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: _isCreatingAccount ? TextInputAction.next : TextInputAction.done,
                          style: TextStyle(fontSize: textFieldFontSize),
                          onFieldSubmitted: (_) {
                            if (_isCreatingAccount) {
                              _confirmPasswordFocusNode.requestFocus();
                            } else if (!_isLoading) {
                              _signIn();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            contentPadding: textFieldPadding,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _isCreatingAccount
                              ? Column(
                                  children: [
                                    SizedBox(height: fieldGap),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      focusNode: _confirmPasswordFocusNode,
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      style: TextStyle(fontSize: textFieldFontSize),
                                      onFieldSubmitted: (_) {
                                        if (!_isLoading) {
                                          _register();
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        contentPadding: textFieldPadding,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                          onPressed: () {
                                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (!_isCreatingAccount) return null;
                                        if (value == null || value.isEmpty) {
                                          return 'Please confirm your password';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        SizedBox(height: fieldToButtonSpacing),
                        GradientButton(
                          text: _isCreatingAccount ? 'Create Account' : 'Sign In',
                          onPressed: _isCreatingAccount ? _register : _signIn,
                          isLoading: _isLoading,
                        ),
                        SizedBox(height: buttonGap),
                        if (_isCreatingAccount)
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isCreatingAccount = false;
                                      _confirmPasswordController.clear();
                                    });
                                  },
                            child: Text(
                              'Already have an account? Sign In',
                              style: GoogleFonts.poppins(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0EA5E9),
                              ),
                            ),
                          )
                        else
                          OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isCreatingAccount = true;
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                              side: const BorderSide(color: Color(0xFF0EA5E9)),
                            ),
                            child: Text(
                              'Create Account',
                              style: GoogleFonts.poppins(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                        SizedBox(height: dividerSpacing),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        SizedBox(height: dividerSpacing),
                        // Apple Sign-In Button (iOS/macOS only)
                        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) ...[
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithApple,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              backgroundColor: Colors.black,
                            ),
                            icon: const Icon(
                              Icons.apple,
                              size: 24,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Continue with Apple',
                              style: GoogleFonts.poppins(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: socialButtonGap),
                        ],
                        // Google Sign-In Button
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                            side: BorderSide(color: Colors.grey[300]!),
                            backgroundColor: Colors.white,
                          ),
                          icon: Image.asset(
                            'assets/images/google_logo.png',
                            height: 24,
                            width: 24,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to gradient icon if image fails to load
                              return Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4285F4), Color(0xFFDB4437), Color(0xFFF4B400), Color(0xFF0F9D58)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
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
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        SizedBox(height: socialButtonGap),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _signInAnonymously,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: buttonVerticalPadding),
                              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                              backgroundColor: Colors.grey[50],
                            ),
                            child: Text(
                              'Continue as Guest',
                              style: GoogleFonts.poppins(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }
}