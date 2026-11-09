import 'package:flutter/material.dart';

const growthPurple = Color(0xff5416e8);
const growthInk = Color(0xff171047);
const growthGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff8d43ff), Color(0xff4c0edc), Color(0xff290a96)],
);

/// The soft waves frame the content without intercepting taps or scrolling.
class GrowthBackdrop extends StatelessWidget {
  const GrowthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfff8f6ff),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: CustomPaint(painter: _WavePainter())),
        child,
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = Path()
      ..moveTo(w * .34, 0)
      ..quadraticBezierTo(w * .44, h * .13, w * .72, h * .10)
      ..quadraticBezierTo(w * .91, h * .08, w, h * .16)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xffe5dafa));
    final topInner = Path()
      ..moveTo(w * .50, 0)
      ..quadraticBezierTo(w * .60, h * .09, w * .80, h * .075)
      ..quadraticBezierTo(w * .93, h * .07, w, h * .12)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(topInner, Paint()..color = const Color(0xffd3bdf8));
    final wave = Path()
      ..moveTo(0, h * .84)
      ..cubicTo(w * .22, h * .79, w * .31, h * .98, w * .58, h * .91)
      ..cubicTo(w * .80, h * .86, w * .88, h * .80, w, h * .84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xffe7dbfb));
    final lower = Path()
      ..moveTo(0, h * .90)
      ..cubicTo(w * .23, h * .85, w * .35, h * 1.02, w * .60, h * .95)
      ..cubicTo(w * .83, h * .90, w * .91, h * .87, w, h * .90)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      lower,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffb89af8), Color(0xff8f5cf4), Color(0xffcab5fb)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GrowthArt extends StatelessWidget {
  const GrowthArt(this.name, {super.key, this.height = 170});
  final String name;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/design/$name.png',
      height: height,
      fit: BoxFit.contain,
    ),
  );
}

class GrowthHero extends StatelessWidget {
  const GrowthHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: growthGradient,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: growthPurple.withValues(alpha: .22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: const Color(0xffe3d4ff), size: 62),
      ],
    ),
  );
}

class GrowthEmpty extends StatelessWidget {
  const GrowthEmpty({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String art, title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    child: Column(
      children: [
        GrowthArt(art),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: growthInk,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff696184), height: 1.4),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
