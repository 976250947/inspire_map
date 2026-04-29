import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: 92,
              child: IgnorePointer(
                child: SizedBox(
                  width: 156,
                  height: 156,
                  child: CustomPaint(
                    painter: _SignalPainter(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandHeader(),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: Text(
                      '懂你的人，\n带你走对的路。',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 272,
                    child: Text(
                      '不是榜单热门，而是真正契合你旅行性格的小众角落。',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.75,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRouter.onboarding),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '开始探索灵感',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.paper,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRouter.login),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        side: const BorderSide(color: AppColors.rule),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        '已有账号，直接登录',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _BrandCompassPainter(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'INSPIREMAP',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.9,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _SignalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.rule.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final thinPaint = Paint()
      ..color = AppColors.rule.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final center = Offset(size.width * 0.55, size.height * 0.55);
    for (final radius in <double>[18, 40, 65, 90]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawLine(
      Offset(center.dx - 95, center.dy),
      Offset(center.dx + 95, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 95),
      Offset(center.dx, center.dy + 95),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 70, center.dy - 70),
      Offset(center.dx + 70, center.dy + 70),
      thinPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 70, center.dy - 70),
      Offset(center.dx - 70, center.dy + 70),
      thinPaint,
    );
    canvas.drawCircle(center, 8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandCompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.inkMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final axis = Paint()
      ..color = AppColors.inkMid.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final inner = Paint()
      ..color = AppColors.inkMid.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final accent = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.fill;
    final darkFill = Paint()
      ..color = AppColors.inkMid
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 10.5, stroke);
    canvas.drawCircle(center, 6.8, inner);
    canvas.drawLine(Offset(center.dx, 2), Offset(center.dx, size.height - 2), axis);
    canvas.drawLine(Offset(2, center.dy), Offset(size.width - 2, center.dy), axis);

    final north = Path()
      ..moveTo(center.dx, 4)
      ..lineTo(center.dx + 1.5, 9)
      ..lineTo(center.dx, 7.4)
      ..lineTo(center.dx - 1.5, 9)
      ..close();
    canvas.drawPath(north, darkFill);

    final south = Path()
      ..moveTo(center.dx, size.height - 4)
      ..lineTo(center.dx - 1.5, size.height - 9)
      ..lineTo(center.dx, size.height - 7.4)
      ..lineTo(center.dx + 1.5, size.height - 9)
      ..close();
    canvas.drawPath(south, darkFill..color = AppColors.inkMid.withValues(alpha: 0.35));

    canvas.drawCircle(center, 2.1, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
