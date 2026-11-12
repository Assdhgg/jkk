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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Image.asset(
              'assets/design/bottom_waves.png',
              fit: BoxFit.fitWidth,
              excludeFromSemantics: true,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.topRight,
          radius: 1.25,
          colors: [Color(0xffe8d9fc), Color(0xfff5efff), Color(0xfff5efff)],
          stops: [0, .5, 1],
        ).createShader(bounds),
    );
    final outer = Path()
      ..moveTo(w * .32, 0)
      ..cubicTo(w * .49, w * .44, w * .80, w * .04, w, w * .34)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffe5d5ff), Color(0xffc8a3fa), Color(0xffa074f3)],
        ).createShader(Rect.fromLTWH(w * .32, 0, w * .68, w * .34)),
    );
    final inner = Path()
      ..moveTo(w * .52, 0)
      ..cubicTo(w * .65, w * .26, w * .89, w * .14, w, w * .12)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.topRight,
          radius: 1.1,
          colors: [Color(0xff4810d2), Color(0xff7d3bf0), Color(0xffc8a1ff)],
        ).createShader(Rect.fromLTWH(w * .52, -w * .10, w * .48, w * .38)),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..color = const Color(0x88ffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GrowthIcon extends StatelessWidget {
  const GrowthIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xfff3edff), Color(0xffd9c7ff)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(13),
      boxShadow: [
        BoxShadow(
          color: growthPurple.withValues(alpha: .12),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: growthPurple, size: 22),
  );
}

class GrowthArt extends StatelessWidget {
  const GrowthArt(this.name, {super.key, this.height = 170});
  final String name;
  final double height;
  @override
  Widget build(BuildContext context) {
    Widget art = Image.asset(
      'assets/design/$name.png',
      height: height,
      fit: BoxFit.contain,
    );
    if (name.endsWith('_reference')) {
      art = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .09, .91, 1],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, .09, .91, 1],
          ).createShader(bounds),
          child: art,
        ),
      );
    }
    return ExcludeSemantics(child: art);
  }
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
    this.action,
    this.minHeight = 0,
  });
  final Widget? action;
  final double minHeight;
  final String title, subtitle;
  final IconData icon;
  final String? art;
  final String? background;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
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
                  fontSize: 16,
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
              if (action != null) ...[const SizedBox(height: 8), action!],
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
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: selected == i && i != 1
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
                              color: selected == i && i == 1
                                  ? const Color(0xffd6bcff)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              selected == i ? active[i] : icons[i],
                              size: 21,
                              color: selected == i
                                  ? (i == 1 ? growthPurple : Colors.white)
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
                                    ? (i == 1 ? growthPurple : Colors.white)
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
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Column(
      children: [
        GrowthArt(art, height: artHeight),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: growthInk,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff696184),
              height: 1.4,
              fontSize: 11,
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
