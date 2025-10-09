import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Modern hover effect widget with scale and glow animation
/// Replaces InkWell ripple effects with smooth, contemporary animations
class HoverScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final bool enableGlow;
  final Color? glowColor;

  const HoverScaleWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 150),
    this.enableGlow = true,
    this.glowColor,
  });

  @override
  State<HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: widget.enableGlow && _glowAnimation.value > 0
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.glowColor ?? Theme.of(context).primaryColor)
                                .withValues(alpha: 0.3 * _glowAnimation.value),
                            blurRadius: 12 * _glowAnimation.value,
                            spreadRadius: 2 * _glowAnimation.value,
                          ),
                        ],
                      )
                    : null,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Simpler hover widget with just background color fade
/// Good for minimal designs
class HoverFadeWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final Duration duration;

  const HoverFadeWidget({
    super.key,
    required this.child,
    this.onTap,
    this.hoverColor,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverFadeWidget> createState() => _HoverFadeWidgetState();
}

class _HoverFadeWidgetState extends State<HoverFadeWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.hoverColor ??
        Theme.of(context).primaryColor.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered ? hoverColor : Colors.transparent,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Bounce animation with border highlight
/// More playful and engaging
class HoverBounceWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Duration duration;

  const HoverBounceWidget({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverBounceWidget> createState() => _HoverBounceWidgetState();
}

class _HoverBounceWidgetState extends State<HoverBounceWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColor ?? Theme.of(context).primaryColor;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              child: AnimatedContainer(
                duration: widget.duration,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _isHovered
                      ? Border.all(
                          color: borderColor.withValues(alpha: 0.5),
                          width: 2,
                        )
                      : null,
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// NEW MODERN ANIMATION WIDGETS
// ============================================================================

/// Option 1: Magnetic Hover - Icon follows cursor with smooth magnetic pull
/// Best for: Logos, primary brand elements
class MagneticHoverWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double magneticStrength;
  final double scale;
  final Duration duration;

  const MagneticHoverWidget({
    super.key,
    required this.child,
    this.onTap,
    this.magneticStrength = 0.3, // How much it follows cursor (0.0 to 1.0)
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<MagneticHoverWidget> createState() => _MagneticHoverWidgetState();
}

class _MagneticHoverWidgetState extends State<MagneticHoverWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Offset _magneticOffset = Offset.zero;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent event, Size size) {
    if (!_isHovered) {
      setState(() => _isHovered = true);
      _controller.forward();
    }

    // Calculate magnetic offset based on cursor position
    final center = Offset(size.width / 2, size.height / 2);
    final localPosition = event.localPosition;
    final deltaX = (localPosition.dx - center.dx) * widget.magneticStrength;
    final deltaY = (localPosition.dy - center.dy) * widget.magneticStrength;

    setState(() {
      _magneticOffset = Offset(deltaX, deltaY);
    });
  }

  void _onExit() {
    setState(() {
      _isHovered = false;
      _magneticOffset = Offset.zero;
    });
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          _onHover(event, renderBox.size);
        }
      },
      onExit: (_) => _onExit(),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: _magneticOffset,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Option 2: Elastic Bounce with Color Shift
/// Best for: Action icons, buttons
/// STAYS ENLARGED while hovering
class ElasticBounceWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Duration duration;
  final double scale;

  const ElasticBounceWidget({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 200),
    this.scale = 1.08, // How much to scale when hovered
  });

  @override
  State<ElasticBounceWidget> createState() => _ElasticBounceWidgetState();
}

class _ElasticBounceWidgetState extends State<ElasticBounceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Simple scale: 1.0 -> target scale (stays there while hovered)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic, // Smooth ease out
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _controller.forward(); // Scale up and STAY there
    } else {
      _controller.reverse(); // Scale back down
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  // Intensify background color on hover
                  color: _isHovered && widget.backgroundColor != null
                      ? Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.1),
                          widget.backgroundColor!,
                        )
                      : widget.backgroundColor,
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Option 3: Glow Pulse with Lift Effect
/// Best for: Premium features, special actions
/// STAYS ENLARGED while hovering with pulsing glow
class GlowPulseWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glowColor;
  final Duration duration;
  final double scale;

  const GlowPulseWidget({
    super.key,
    required this.child,
    this.onTap,
    this.glowColor,
    this.duration = const Duration(milliseconds: 200),
    this.scale = 1.05,
  });

  @override
  State<GlowPulseWidget> createState() => _GlowPulseWidgetState();
}

class _GlowPulseWidgetState extends State<GlowPulseWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Scale animation - stays at target while hovered
    _scaleController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );

    // Continuous pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _scaleController.forward(); // Scale up and STAY there
      _pulseController.repeat(reverse: true); // Start pulsing
    } else {
      _scaleController.reverse(); // Scale back down
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? Theme.of(context).primaryColor;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleController, _pulseController]),
          builder: (context, child) {
            final pulseValue = _isHovered ? _pulseAnimation.value : 0.0;

            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isHovered
                      ? [
                          // Animated pulsing glow
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.3 + (0.2 * pulseValue)),
                            blurRadius: 15 + (5 * pulseValue),
                            spreadRadius: 2 + (2 * pulseValue),
                          ),
                          // Lift shadow
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Mobile-optimized tap animation widget
/// Press down effect with bounce back - NO grey circle!
class MobileTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? pressColor;
  final bool enableHaptic;
  final Duration duration;

  const MobileTapWidget({
    super.key,
    required this.child,
    this.onTap,
    this.pressColor,
    this.enableHaptic = true,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<MobileTapWidget> createState() => _MobileTapWidgetState();
}

class _MobileTapWidgetState extends State<MobileTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Scale down when pressed, bounce back when released
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();

    // Trigger haptic feedback on mobile
    if (widget.enableHaptic) {
      // Note: Add haptic_feedback package to pubspec.yaml for this
      // HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse().then((_) {
      // Slight bounce back
      _controller.animateTo(0.0, curve: Curves.elasticOut);
    });
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: widget.duration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _isPressed && widget.pressColor != null
                    ? Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.15),
                        widget.pressColor!,
                      )
                    : widget.pressColor,
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Universal Interactive Widget - Auto-detects platform and applies best animation
/// Desktop: Uses hover animations (you choose style)
/// Mobile: Uses tap animations
class UniversalInteractiveWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final InteractiveStyle style;
  final Color? color;

  const UniversalInteractiveWidget({
    super.key,
    required this.child,
    this.onTap,
    this.style = InteractiveStyle.elastic,
    this.color,
  });

  bool get _isDesktop {
    if (kIsWeb) return true;
    try {
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      // Desktop: Use hover animation based on style
      switch (style) {
        case InteractiveStyle.magnetic:
          return MagneticHoverWidget(
            onTap: onTap,
            child: child,
          );
        case InteractiveStyle.elastic:
          return ElasticBounceWidget(
            onTap: onTap,
            backgroundColor: color,
            child: child,
          );
        case InteractiveStyle.glowPulse:
          return GlowPulseWidget(
            onTap: onTap,
            glowColor: color,
            child: child,
          );
      }
    } else {
      // Mobile: Use tap animation
      return MobileTapWidget(
        onTap: onTap,
        pressColor: color,
        child: child,
      );
    }
  }
}

enum InteractiveStyle {
  magnetic,   // Follows cursor with magnetic pull
  elastic,    // Bouncy with color shift
  glowPulse,  // Pulsing glow effect
}
