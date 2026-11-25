import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// The page itself: parchment with its grain, a little darker toward the edges
/// as old paper is.
class Paper extends StatelessWidget {
  const Paper({super.key, required this.child, this.vignette = true});
  final Widget child;
  final bool vignette;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.page),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/images/paper_grain.png'),
                    repeat: ImageRepeat.repeat,
                    scale: 2.2,
                    opacity: p.dark ? .16 : .32,
                    colorFilter: ColorFilter.mode(p.grain, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
          if (vignette)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        (p.dark ? Colors.black : const Color(0xFF8A5A2B))
                            .withValues(alpha: p.dark ? .28 : .10),
                      ],
                      stops: const [.62, 1],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// A screen: paper, a title in capitals, a way back, actions.
class Leaf extends StatelessWidget {
  const Leaf({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.back = true,
    this.bottom,
  });
  final String title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;
  final bool back;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final canPop = back && Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: p.page,
      body: Paper(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: canPop
                          ? Tap(
                              onTap: () => Navigator.of(context).maybePop(),
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                CupertinoIcons.chevron_back,
                                color: p.inkStrong,
                                size: 22,
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Center(
                        child:
                            titleWidget ??
                            Text(
                              title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: p.title(15).copyWith(letterSpacing: 2.4),
                            ),
                      ),
                    ),
                    SizedBox(
                      width: actions.isEmpty ? 52 : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
                  ],
                ),
              ),
              Hairline(color: p.rule.withValues(alpha: .7)),
              Expanded(child: Measure(child: body)),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

/// A page's width on a wide screen (iPad): lines no longer than a book's.
class Measure extends StatelessWidget {
  const Measure({super.key, required this.child, this.width = 700});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

/// A tap target that dims a little while it's held.
class Tap extends StatefulWidget {
  const Tap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = EdgeInsets.zero,
    this.semantics,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final String? semantics;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 90),
          opacity: !enabled
              ? .45
              : _down
              ? .55
              : 1,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

/// Spaced Roman capitals over a section.
class Label extends StatelessWidget {
  const Label(this.text, {super.key, this.color, this.size});
  final String text;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Text(
      text.toUpperCase(),
      style: p.label.copyWith(color: color, fontSize: size),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color, this.indent = 0});
  final Color? color;
  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent),
    color: color ?? context.parch.rule,
  );
}

/// A printer's ornament between sections: a rule, a lozenge, a rule.
class Ornament extends StatelessWidget {
  const Ornament({super.key, this.width = 120, this.color});
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.parch.gold;
    return Center(
      child: SizedBox(
        width: width,
        height: 12,
        child: CustomPaint(painter: _OrnamentPainter(c)),
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2, cx = size.width / 2;
    final line = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(cx - 12, mid), line);
    canvas.drawLine(Offset(cx + 12, mid), Offset(size.width, mid), line);
    final fill = Paint()..color = color;
    final d = Path()
      ..moveTo(cx, mid - 5)
      ..lineTo(cx + 5, mid)
      ..lineTo(cx, mid + 5)
      ..lineTo(cx - 5, mid)
      ..close();
    canvas.drawPath(d, fill);
    canvas.drawCircle(Offset(cx - 9, mid), 1.6, fill);
    canvas.drawCircle(Offset(cx + 9, mid), 1.6, fill);
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) => old.color != color;
}

/// A fresher leaf laid on the page: a card.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = false,
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.leaf,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent ? p.accent.withValues(alpha: .55) : p.rule,
        ),
        boxShadow: [
          BoxShadow(
            color: (p.dark ? Colors.black : const Color(0xFF6E4B2A)).withValues(
              alpha: p.dark ? .30 : .08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null ? box : Tap(onTap: onTap, child: box);
  }
}

/// Frosted, for what floats over the reading.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding, this.radius = 14});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.dark ? .45 : .16),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.leaf.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.rule),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum Btn { solid, outline, quiet }

class ParchButton extends StatelessWidget {
  const ParchButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = Btn.outline,
    this.icon,
    this.expand = false,
    this.small = false,
  });
  final String label;
  final VoidCallback? onTap;
  final Btn kind;
  final IconData? icon;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final fg = switch (kind) {
      Btn.solid => p.onAccent,
      Btn.outline => p.inkStrong,
      Btn.quiet => p.accent,
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 15 : 18, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Parchment.caps,
              fontSize: small ? 11.5 : 13,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ],
    );
    return Tap(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 18,
          vertical: small ? 9 : 15,
        ),
        decoration: BoxDecoration(
          color: kind == Btn.solid ? p.accent : null,
          borderRadius: BorderRadius.circular(6),
          border: kind == Btn.outline
              ? Border.all(color: p.rule, width: 1.2)
              : kind == Btn.solid
              ? Border.all(color: p.accent)
              : null,
          gradient: kind == Btn.solid
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(p.accent, Colors.white, .08)!,
                    Color.lerp(p.accent, Colors.black, .06)!,
                  ],
                )
              : null,
        ),
        child: content,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.on = false, this.onTap, this.icon});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Tap(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? p.accent : p.leaf,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: on ? p.accent : p.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: on ? p.onAccent : p.faded),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: Parchment.serif,
                fontSize: 15.5,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                color: on ? p.onAccent : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet up from the bottom, a leaf with a title.
Future<T?> sheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) body,
  List<Widget> actions = const [],
  bool scroll = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (ctx) {
      final p = ctx.parch;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: p.leaf,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(top: BorderSide(color: p.rule)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * .88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.rule,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 14, 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, style: p.title(19))),
                        ...actions,
                      ],
                    ),
                  ),
                  const Hairline(),
                  Flexible(
                    child: scroll
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                            child: body(ctx),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                            child: body(ctx),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void toast(BuildContext context, String text, {bool error = false}) {
  final p = context.parch;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? p.danger : p.inkStrong,
        content: Text(
          text,
          style: TextStyle(
            fontFamily: Parchment.serif,
            fontSize: 16,
            color: error ? Colors.white : p.page,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Asks before something that can't be taken back.
Future<bool> sure(
  BuildContext context,
  String title, {
  required String ok,
  String? text,
  bool danger = false,
}) async {
  final r = await sheet<bool>(
    context,
    title: title,
    body: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text != null) ...[
          Text(text, style: ctx.parch.body),
          const SizedBox(height: 18),
        ],
        ParchButton(
          ok,
          kind: Btn.solid,
          expand: true,
          onTap: () => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: 8),
        ParchButton(
          'Cancel',
          kind: Btn.quiet,
          expand: true,
          onTap: () => Navigator.pop(ctx, false),
        ),
      ],
    ),
  );
  return r == true;
}

class Waiting extends StatelessWidget {
  const Waiting({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          ),
          if (text != null) ...[
            const SizedBox(height: 14),
            Text(text!, textAlign: TextAlign.center, style: p.small),
          ],
        ],
      ),
    );
  }
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key, this.icon, this.title});
  final String text;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40, color: p.faded.withValues(alpha: .7)),
            const SizedBox(height: 14),
          ],
          if (title != null) ...[
            Text(title!, textAlign: TextAlign.center, style: p.title(18)),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: p.small.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// A ring that fills as the plan is read.
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 7,
    this.child,
  });
  final double value; // 0..1
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, p.deep, p.accent, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.track, this.fill, this.stroke);
  final double v, stroke;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (v > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.fill != fill || old.track != track;
}

/// A switch on a line, with what it's for.
class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 21, color: p.accent),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: p.body.copyWith(color: p.inkStrong)),
                if (subtitle != null) Text(subtitle!, style: p.small),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: p.accent,
          ),
        ],
      ),
    );
  }
}

/// A line to tap: an icon, words, a chevron.
class RowLink extends StatelessWidget {
  const RowLink({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final c = danger ? p.danger : p.inkStrong;
    const pad = EdgeInsets.symmetric(vertical: 13);
    final row = Row(
      children: [
        Icon(icon, size: 21, color: danger ? p.danger : p.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: p.body.copyWith(color: c)),
              if (subtitle != null) Text(subtitle!, style: p.small),
            ],
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(trailing!, style: p.small),
          ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_right, size: 14, color: p.faded),
        ],
      ],
    );
    // Nothing to tap: a plain line, not a dimmed button
    if (onTap == null) return Padding(padding: pad, child: row);
    return Tap(onTap: onTap, padding: pad, child: row);
  }
}
