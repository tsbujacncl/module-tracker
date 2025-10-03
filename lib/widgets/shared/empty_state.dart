import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/theme/design_tokens.dart';
import 'package:module_tracker/widgets/shared/gradient_button.dart';

/// A consistent empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionText;
  final VoidCallback? onAction;
  final Gradient? iconGradient;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionText,
    this.onAction,
    this.iconGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                decoration: BoxDecoration(
                  gradient: iconGradient ?? DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
                  boxShadow: [
                    BoxShadow(
                      color: DesignTokens.primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: DesignTokens.iconHuge,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXL),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.getTextPrimaryColor(
                    Theme.of(context).brightness,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: DesignTokens.spaceS),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceXL,
                  ),
                  child: Text(
                    message!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: DesignTokens.getTextSecondaryColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: DesignTokens.spaceXXL),
                GradientButton(
                  text: actionText!,
                  onPressed: onAction,
                  icon: Icons.add_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact empty state for smaller spaces
class EmptyStateCompact extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const EmptyStateCompact({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: DesignTokens.iconHuge,
              color: DesignTokens.getTextSecondaryColor(
                Theme.of(context).brightness,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceL),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: DesignTokens.spaceS),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignTokens.getTextSecondaryColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
