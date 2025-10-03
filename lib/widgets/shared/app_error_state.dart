import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/theme/design_tokens.dart';

/// A consistent error state widget
class AppErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
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
                  color: DesignTokens.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXXL),
                ),
                child: Icon(
                  icon,
                  size: DesignTokens.iconHuge,
                  color: DesignTokens.red,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXL),
              Text(
                title ?? 'Something went wrong',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.getTextPrimaryColor(
                    Theme.of(context).brightness,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: DesignTokens.spaceS),
                Text(
                  message!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: DesignTokens.getTextSecondaryColor(
                      Theme.of(context).brightness,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: DesignTokens.spaceXL),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceXL,
                      vertical: DesignTokens.spaceM,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact error message widget for inline errors
class AppErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const AppErrorMessage({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceM),
      decoration: BoxDecoration(
        color: DesignTokens.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusM),
        border: Border.all(
          color: DesignTokens.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: DesignTokens.red,
            size: DesignTokens.iconM,
          ),
          const SizedBox(width: DesignTokens.spaceM),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: DesignTokens.red,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: DesignTokens.spaceS),
            IconButton(
              icon: const Icon(Icons.close, size: DesignTokens.iconS),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: DesignTokens.red,
            ),
          ],
        ],
      ),
    );
  }
}
