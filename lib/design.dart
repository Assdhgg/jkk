import 'package:flutter/material.dart';

const growthPurple = Color(0xff5416e8);
const growthInk = Color(0xff171047);
const growthGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff31118f), Color(0xff3c11b6), Color(0xff742aff)],
);

/// The soft waves frame the content without intercepting taps or scrolling.
class GrowthBackdrop extends StatelessWidget {
  const GrowthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xfff6f3ff),
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
      ..moveTo(0, h * .78)
      ..cubicTo(w * .18, h * .75, w * .33, h * .92, w * .54, h * .90)
      ..cubicTo(w * .75, h * .88, w * .89, h * .79, w, h * .79)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0xffe7dbfb));
    final lower = Path()
      ..moveTo(0, h * .84)
      ..cubicTo(w * .20, h * .80, w * .34, h * .98, w * .56, h * .94)
      ..cubicTo(w * .79, h * .90, w * .89, h * .84, w, h * .85)
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

class GrowthActionButton extends StatelessWidget {
  const GrowthActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff8c36ff), Color(0xff3a00bc)],
      ),
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: growthPurple.withValues(alpha: .25),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      ),
    ),
  );
}

class GrowthPrimaryButton extends StatelessWidget {
  const GrowthPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: onPressed == null
            ? [const Color(0xffbfb3dd), const Color(0xffaca0ca)]
            : [const Color(0xff893aff), const Color(0xff3900b8)],
      ),
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: growthPurple.withValues(alpha: .20),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: Text(label, textAlign: TextAlign.center)),
          if (icon != null)
            Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 20),
            ),
        ],
      ),
    ),
  );
}

class GrowthHero extends StatelessWidget {
  const GrowthHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.art,
    this.background,
  });
  final String title, subtitle;
  final IconData icon;
  final String? art;
  final String? background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      gradient: growthGradient,
      image: background == null
          ? null
          : DecorationImage(
              image: AssetImage('assets/design/$background.png'),
              fit: BoxFit.fill,
            ),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.35,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (background != null)
          const SizedBox(width: 112, height: 82)
        else if (art != null)
          Image.asset(
            'assets/design/$art.png',
            height: 82,
            width: 112,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        else
          Icon(icon, color: const Color(0xffe3d4ff), size: 62),
      ],
    ),
  );
}

/// Rounded navigation bar used by all four main screens.
class GrowthNavigation extends StatelessWidget {
  const GrowthNavigation({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.campaign_outlined,
      Icons.person_outline,
    ];
    const active = [
      Icons.home_rounded,
      Icons.explore,
      Icons.campaign,
      Icons.person,
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: growthPurple.withValues(alpha: .16),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == i,
                  label: labels[i],
                  child: InkWell(
                    onTap: () => onSelected(i),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: selected == i && i == 0
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xff762aff), Color(0xff3500b6)],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: selected == i && i != 0
                                  ? const Color(0xffd6bcff)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              selected == i ? active[i] : icons[i],
                              size: 23,
                              color: selected == i
                                  ? (i == 0 ? Colors.white : growthPurple)
                                  : growthInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: selected == i
                                    ? (i == 0 ? Colors.white : growthPurple)
                                    : growthInk,
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
      ),
    );
  }
}

class GrowthEmpty extends StatelessWidget {
  const GrowthEmpty({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.action,
    this.artHeight = 170,
  });
  final String art, title;
  final String? subtitle;
  final Widget? action;
  final double artHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    child: Column(
      children: [
        GrowthArt(art, height: artHeight),
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
