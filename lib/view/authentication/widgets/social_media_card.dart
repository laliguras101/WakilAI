import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Social Media Sign-In Pill Card in Swiss / Gemini Light Monochrome styling.
class SocialMediaCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? leading;

  const SocialMediaCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final Widget resolvedLeading = leading ??
        (label.toLowerCase().contains('google')
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              )
            : Icon(icon, size: 18, color: AppColors.primaryBlack));

    return Material(
      color: AppColors.surfaceLow,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              resolvedLeading,
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 18 / 13,
                    color: AppColors.primaryBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = math.min(size.width, size.height) / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    const Offset center = Offset(12, 12);
    const double strokeRadius = 8.5;
    const double strokeWidth = 4.4;
    const double outerRadius = strokeRadius + (strokeWidth / 2);
    final Rect arcRect = Rect.fromCircle(center: center, radius: strokeRadius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Green bottom arc
    canvas.drawArc(
      arcRect,
      0.72,
      1.96,
      false,
      arcPaint(AppColors.googleGreen),
    );

    // Yellow left arc
    canvas.drawArc(
      arcRect,
      2.68,
      0.94,
      false,
      arcPaint(AppColors.googleYellow),
    );

    // Red top arc
    canvas.drawArc(
      arcRect,
      3.62,
      1.90,
      false,
      arcPaint(AppColors.googleRed),
    );

    // Blue right-bottom arc
    canvas.drawArc(
      arcRect,
      0.0,
      0.74,
      false,
      arcPaint(AppColors.googleBlue),
    );

    // Blue horizontal crossbar clipped cleanly to the outer circle perimeter
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: outerRadius)),
    );
    canvas.drawRect(
      const Rect.fromLTRB(12.0, 9.9, 23.0, 14.1),
      Paint()..color = AppColors.googleBlue,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
