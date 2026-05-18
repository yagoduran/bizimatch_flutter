import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app_theme.dart';

/// Gardentasun estiloko (glassmorphism) txartel bat erakusten duen widget konposatua.
///
/// Helburua: barruko `child` edukiari atzeko blur eta gradiente ikusgarri batekin testuinguru argia/iluna ematea.
///
/// Parametroak:
/// - `child`: Txartel barruan erakutsiko den widget-a.
/// - `padding`, `margin`, `borderRadius`: Diseinu espaziala kontrolatzen dutenak.
/// - `opacity`, `blur`: Gardentasun eta atzeko blur maila egokitzeko erabiltzen diren balioak.
/// - `glowColor`: txartelaren glow efektuarako kolorea.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 24,
    this.opacity = 0.14,
    this.blur = 10,
    this.glowColor = AppTheme.primary,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double opacity;
  final double blur;
  final Color glowColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    // Testuinguruaren arabera (dark/light) opacity eta koloreak egokitu.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassOpacity = isDark ? opacity.clamp(0.05, 0.08) : opacity;
    // Dekorazio globala (gradient, boxShadow) eta atzeko blur aplikatzen dira.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glowColor.withValues(alpha: isDark ? 0.28 : 0.22),
            Colors.white.withValues(alpha: isDark ? 0.08 : 0.12),
            AppTheme.indigo.withValues(alpha: isDark ? 0.14 : 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.28 : 0.18),
            blurRadius: isDark ? 34 : 26,
            spreadRadius: isDark ? -8 : -10,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : const Color(0x120B1220),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 1),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient:
                    gradient ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: glassOpacity.toDouble()),
                        Colors.white.withValues(alpha: isDark ? 0.06 : 0.22),
                        AppTheme.primary.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                      ],
                    ),
                borderRadius: BorderRadius.circular(borderRadius - 1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.11 : 0.26),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikono botoi bat, kolore gradientearekin eta 'glow' itxurarekin.
///
/// Parametro garrantzitsuak:
/// - `icon`: erakutsiko den IconData.
/// - `onPressed`: botoia sakatzen denean exekutatuko den `VoidCallback?`.
/// - `tooltip`: aukeran, Tooltip mezu bat erakutsi daiteke.
class GlowIconButton extends StatelessWidget {
  const GlowIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.size = 56,
    this.colors = AppTheme.emeraldIndigo,
    this.tooltip,
    this.semanticLabel,
    this.semanticHint,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final List<Color> colors;
  final String? tooltip;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.42),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, color: Colors.white, size: size * 0.44),
        ),
      ),
    );

    final decoratedButton = Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      hint: semanticHint ?? (tooltip != null ? 'Activa $tooltip' : null),
      child: ExcludeSemantics(child: button),
    );

    // Tooltip-a aukeran agertzen da; semantic informazioa erabiliz accessibility hobetzen da.
    if (tooltip == null) {
      return decoratedButton;
    }
    return Tooltip(message: tooltip!, child: decoratedButton);
  }
}

/// Zerrenda edo txartel skeleton bat erakusten duen shimmer animazioarekin.
///
/// Parametroak:
/// - `itemCount`: Zenbat elementu skeleton erakutsi.
/// - `padding`: kanpoko espazioa.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.all(20),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFD9E6DF),
        highlightColor: const Color(0xFFF8FBFA),
        period: const Duration(milliseconds: 1200),
        child: Column(
          children: List.generate(widget.itemCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 24,
                child: Row(
                  children: [
                    _ShimmerBox(
                      progress: _controller.value,
                      width: 54,
                      height: 54,
                      radius: 18,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(
                            progress: _controller.value,
                            width: double.infinity,
                            height: 14,
                            radius: 7,
                          ),
                          const SizedBox(height: 10),
                          _ShimmerBox(
                            progress: _controller.value,
                            width: 160,
                            height: 12,
                            radius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Shimmer lerro edo laukizuzen txiki bat marrazteko laguntzailea.
/// `progress` animazioaren balioa erabiltzen du gradient-ak desplazatzeko.
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.progress,
    required this.width,
    required this.height,
    required this.radius,
  });

  final double progress;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // `alignment` kalkulua animazio-progresioaren arabera gradient-a desplazatzeko erabiltzen da.
    final alignment = Alignment(-1.4 + progress * 2.8, 0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x1AFFFFFF),
            Color(0x7AFFFFFF),
            Color(0x1AFFFFFF),
          ],
          stops: [
            (progress - 0.25).clamp(0.0, 1.0),
            progress.clamp(0.0, 1.0),
            (progress + 0.25).clamp(0.0, 1.0),
          ],
          transform: _GradientSlide(alignment.x),
        ),
      ),
    );
  }
}

/// Gradient transform bat, animazioaren arabera gradient-a horizontalki desplazatzen duena.
class _GradientSlide extends GradientTransform {
  const _GradientSlide(this.slide);

  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}

/// Animatu eta organiko itxurako atzeko plano dinamikoa margotzen duen widget-a.
/// Barruan `child` jarriz, marrazkia eta edukia elkarren gainean agertzen dira.
class AnimatedOrganicBackground extends StatefulWidget {
  const AnimatedOrganicBackground({required this.child, super.key});

  final Widget child;

  @override
  State<AnimatedOrganicBackground> createState() =>
      _AnimatedOrganicBackgroundState();
}

class _AnimatedOrganicBackgroundState extends State<AnimatedOrganicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                painter: _OrganicBackgroundPainter(_controller.value),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Empty/placeholder egoeretarako txartel zentral bat erakusten duen widget-a.
///
/// Parametroak:
/// - `title`, `message`: testu nagusia eta deskribapena.
/// - `actionLabel` eta `onAction`: botoi nagusiaren etiketa eta callback-a.
/// - `secondaryActionLabel` eta `onSecondaryAction`: aukeran ager daitezkeen bigarren mailako ekintzak.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.icon = Icons.home_work_outlined,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    // Zentratutako txartela GlassCard erabiliz margotzen da, ikonografia eta botoiak barne.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          borderRadius: 28,
          glowColor: AppTheme.indigo,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 170,
                height: 150,
                child: ExcludeSemantics(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 122,
                        height: 122,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.24),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 16,
                        child: _OrbitDot(color: AppTheme.turquoise),
                      ),
                      Positioned(
                        right: 24,
                        top: 28,
                        child: _OrbitDot(color: AppTheme.violet),
                      ),
                      Positioned(
                        left: 28,
                        bottom: 20,
                        child: _OrbitDot(color: AppTheme.primary),
                      ),
                      Positioned(
                        right: 18,
                        bottom: 16,
                        child: _OrbitDot(color: Colors.white),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 34, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
              // Bigarren mailako ekintza aukeran ager daiteke; kontrolatu parametroak null ez diren.
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Orbit-bolo txiki dekoratiboa; ExcludeSemantics erabiliz irudi estetiko huts gisa tratatzen da.
class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Organiko eta mugikor itxurako atzeko planoa marrazten duen CustomPainter-a.
/// `t` parametroaren arabera puntu blurred eta animatuak marrazten ditu.
class _OrganicBackgroundPainter extends CustomPainter {
  const _OrganicBackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Oinarrizko gradientea margotu atzeko plano gisa.
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4FFF9), Color(0xFFEFF3FF), Color(0xFFE6FFFA)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // `blob` laguntzaile funtzioak gorputz blurred eta mugikorren dentsoak marrazten ditu,
    // `t` fase animazioaren arabera desplazatzen dira.
    void blob(Color color, Offset origin, double radius, double phase) {
      final dx = math.sin((t + phase) * math.pi * 2) * 24;
      final dy = math.cos((t + phase) * math.pi * 2) * 20;
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38)
        ..color = color;
      canvas.drawCircle(origin + Offset(dx, dy), radius, paint);
    }

    blob(
      AppTheme.primary.withValues(alpha: 0.22),
      Offset(size.width * 0.14, size.height * 0.16),
      130,
      0,
    );
    blob(
      AppTheme.indigo.withValues(alpha: 0.18),
      Offset(size.width * 0.92, size.height * 0.22),
      160,
      0.33,
    );
    blob(
      AppTheme.turquoise.withValues(alpha: 0.20),
      Offset(size.width * 0.58, size.height * 0.88),
      180,
      0.66,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicBackgroundPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

/// Bortz kolor gradient-az inguratutako animatutako border bat ematen duen kontenedor dekoratiboa.
/// `child` barruan jarrita, kanpoaldetik biraka dabilen rainbow efektua sortzen du.
class AnimatedRainbowBorder extends StatefulWidget {
  const AnimatedRainbowBorder({
    required this.child,
    super.key,
    this.borderRadius = 30,
    this.padding = const EdgeInsets.all(1.6),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  State<AnimatedRainbowBorder> createState() => _AnimatedRainbowBorderState();
}

class _AnimatedRainbowBorderState extends State<AnimatedRainbowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * math.pi * 2),
              colors: const [
                Color(0xFF10B981),
                Color(0xFF22D3EE),
                Color(0xFF6366F1),
                Color(0xFFA855F7),
                Color(0xFF10B981),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.indigo.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: -6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
