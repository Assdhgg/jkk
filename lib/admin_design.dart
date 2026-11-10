import 'package:flutter/material.dart';

const adminAccent = Color(0xff4d16d5);
const adminText = Color(0xff160b49);

/// Decorative artwork is separate from content so real data stays readable.
class AdminBackdrop extends StatelessWidget {
  const AdminBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfff6f3ff),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(child: CustomPaint(painter: _AdminWaves())),
        child,
      ],
    ),
  );
}

class _AdminWaves extends CustomPainter {
  const _AdminWaves();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = Path()
      ..moveTo(w * .36, 0)
      ..cubicTo(w * .42, h * .18, w * .55, h * .03, w * .67, h * .035)
      ..cubicTo(w * .80, h * .04, w * .85, h * .15, w, h * .10)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xfff4efff), Color(0xffe0d0fa), Color(0xffeee5fb)],
        ).createShader(Offset.zero & size),
    );
    final wave = Path()
      ..moveTo(0, h * .89)
      ..cubicTo(w * .14, h * .78, w * .25, h * .98, w * .42, h * .95)
      ..cubicTo(w * .60, h * .92, w * .70, h * .82, w * .82, h * .88)
      ..cubicTo(w * .90, h * .91, w * .94, h * .86, w, h * .84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xffe2d4fa));
    final lower = Path()
      ..moveTo(0, h * .94)
      ..cubicTo(w * .17, h * .84, w * .25, h * 1.04, w * .45, h * .98)
      ..cubicTo(w * .68, h * .90, w * .78, h * .88, w, h * .95)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      lower,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffc4a7fa), Color(0xffdfd0fa), Color(0xffb89bf4)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AdminIllustration extends StatelessWidget {
  const AdminIllustration(this.name, {super.key, this.height = 140});
  final String name;
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/admin/$name.png',
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class AdminHeading extends StatelessWidget {
  const AdminHeading({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.eyebrow,
    this.art,
  });
  final String title;
  final IconData icon;
  final String? subtitle, eyebrow, art;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      return Row(
        children: [
          Container(
            width: wide ? 88 : 48,
            height: wide ? 88 : 48,
            decoration: BoxDecoration(
              color: const Color(0xffe4d8fa),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: adminAccent, size: wide ? 42 : 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!,
                    style: const TextStyle(
                      color: adminAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    color: adminText,
                    fontSize: wide ? 40 : 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0xff514379),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (wide && art != null) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: constraints.maxWidth * .32,
              child: AdminIllustration(art!, height: 180),
            ),
          ],
        ],
      );
    },
  );
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.art,
  });
  final String title;
  final String? subtitle, art;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (art != null) AdminIllustration(art!, height: 170),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: adminText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xff6a5b91)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AdminPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminPageBar({
    super.key,
    required this.title,
    required this.icon,
    required this.desktop,
    this.subtitle,
    this.art,
    this.actions = const [],
  });
  final String title;
  final IconData icon;
  final bool desktop;
  final String? subtitle, art;
  final List<Widget> actions;
  @override
  Size get preferredSize => Size.fromHeight(desktop ? 190 : kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: preferredSize.height,
    titleSpacing: desktop ? 24 : null,
    title: desktop
        ? AdminHeading(title: title, icon: icon, subtitle: subtitle, art: art)
        : Text(title),
    actions: actions,
  );
}
