import 'dart:io';
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../bible/kjb.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'reader.dart' show openInBible;

/// A verse to share: an image of it made on the phone, square for a post or
/// tall for a story, on paper, in ink, or in ember; or just its words.
class VerseShareScreen extends StatefulWidget {
  const VerseShareScreen({
    super.key,
    required this.reference,
    required this.text,
  });
  final String reference, text;

  @override
  State<VerseShareScreen> createState() => _VerseShareScreenState();
}

class _VerseShareScreenState extends State<VerseShareScreen> {
  final _card = GlobalKey();
  String _look = 'paper', _shape = 'square';
  bool _busy = false;

  String get _words => '"${widget.text}" ${widget.reference} (KJB)';

  // The image, drawn from the card at 1080 pixels wide
  Future<File> _image() async {
    final box =
        _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await box.toImage(pixelRatio: 1080 / box.size.width);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final name = widget.reference.replaceAll(RegExp(r'[^\w]+'), '-');
    final f = File('${(await getTemporaryDirectory()).path}/$name-$_shape.png');
    await f.writeAsBytes(png!.buffer.asUint8List());
    return f;
  }

  Rect? _origin(BuildContext from) {
    final box = from.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareImage(BuildContext from) async {
    final origin = _origin(from);
    setState(() => _busy = true);
    try {
      final f = await _image();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path, mimeType: 'image/png')],
          text: _words,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        toast(context, "The image couldn't be made. Try again.", error: true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    Widget action(IconData icon, String label, VoidCallback? onTap) => Expanded(
      child: Tap(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: p.inkStrong, size: 22),
            const SizedBox(height: 4),
            Label(label, size: 9.5, color: p.ink),
          ],
        ),
      ),
    );
    return Leaf(
      title: widget.reference,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.paddingOf(context).bottom + 30,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _shape == 'story' ? 270 : 360,
              ),
              child: RepaintBoundary(
                key: _card,
                child: AspectRatio(
                  aspectRatio: _shape == 'story' ? 9 / 16 : 1,
                  child: VerseCard(
                    text: widget.text,
                    reference: widget.reference,
                    look: _look,
                    tall: _shape == 'story',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, l) in const [
                ('paper', 'Paper'),
                ('ink', 'Ink'),
                ('ember', 'Ember'),
              ])
                Pill(l, on: _look == k, onTap: () => setState(() => _look = k)),
              const SizedBox(width: 10),
              for (final (k, l) in const [
                ('square', 'A post'),
                ('story', 'A story'),
              ])
                Pill(
                  l,
                  on: _shape == k,
                  onTap: () => setState(() => _shape = k),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (ctx) => ParchButton(
              _busy ? 'Making it…' : 'Share or save the image',
              kind: Btn.solid,
              expand: true,
              icon: CupertinoIcons.square_arrow_up,
              onTap: _busy ? null : () => _shareImage(ctx),
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (ctx) => ParchButton(
              'Share the words',
              expand: true,
              icon: CupertinoIcons.text_quote,
              onTap: () => SharePlus.instance.share(
                ShareParams(text: _words, sharePositionOrigin: _origin(ctx)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                action(CupertinoIcons.doc_on_doc, 'Copy', () async {
                  await Clipboard.setData(ClipboardData(text: _words));
                  if (context.mounted) toast(context, 'Copied');
                }),
                action(CupertinoIcons.book, 'Read it', () {
                  final r = Kjb.ref(widget.reference);
                  if (r != null) openInBible(context, r.$1, r.$2, r.$3);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The image: the verse in the Bible's type, its reference in spaced
/// capitals, an ornament, and the app's name at the foot.
class VerseCard extends StatelessWidget {
  const VerseCard({
    super.key,
    required this.text,
    required this.reference,
    required this.look,
    this.tall = false,
  });
  final String text, reference, look;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final (bg, ink, mark) = switch (look) {
      'ink' => (
        const Color(0xFF1C1611),
        const Color(0xFFF1E6D3),
        const Color(0xFFE79B5D),
      ),
      'ember' => (
        const Color(0xFFB9572A),
        const Color(0xFFFFF4E6),
        const Color(0xFF3A1B0C),
      ),
      _ => (
        const Color(0xFFF3E9D7),
        const Color(0xFF2A1E15),
        const Color(0xFFC0632B),
      ),
    };
    // A picture, the same on every phone: the phone's own text size doesn't change it
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Container(
            decoration: BoxDecoration(
              color: bg,
              gradient: look == 'ember'
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD06A33), Color(0xFF94401C)],
                    )
                  : null,
              image: look == 'paper'
                  ? const DecorationImage(
                      image: AssetImage('assets/images/paper_grain.png'),
                      repeat: ImageRepeat.repeat,
                      opacity: .6,
                      colorFilter: ColorFilter.mode(
                        Color(0xFF6E4B2A),
                        BlendMode.srcIn,
                      ),
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: w * .1,
              vertical: w * (tall ? .14 : .08),
            ),
            child: Column(
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    fontFamily: Parchment.serif,
                    fontSize: w * .16,
                    height: .8,
                    color: mark,
                  ),
                ),
                // The words and the reference at the largest size that fits
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      final lh = text.length > 260
                          ? 1.26
                          : text.length > 150
                          ? 1.32
                          : 1.4;
                      TextStyle words(double f) => TextStyle(
                        fontFamily: Parchment.serif,
                        fontSize: f,
                        height: lh,
                        color: ink,
                        fontWeight: FontWeight.w500,
                      );
                      TextStyle refs(double f) => TextStyle(
                        fontFamily: Parchment.caps,
                        fontSize: (f * .5).clamp(8.0, w * .042),
                        height: 1.25,
                        letterSpacing: f * .12,
                        fontWeight: FontWeight.w700,
                        color: look == 'ember' ? ink : mark,
                      );
                      double high(String s, TextStyle st) => (TextPainter(
                        text: TextSpan(text: s, style: st),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: inner.maxWidth)).height;
                      final ref = reference.toUpperCase();
                      var f = w * (tall ? .1 : .09);
                      for (; f > 7; f -= .5) {
                        if (high(text, words(f)) +
                                f * 1.8 +
                                12 +
                                high(ref, refs(f)) <=
                            inner.maxHeight) {
                          break;
                        }
                      }
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: inner.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                text,
                                textAlign: TextAlign.center,
                                style: words(f),
                              ),
                              SizedBox(height: f * 1.0),
                              Ornament(
                                width: w * .22,
                                color: look == 'ember' ? ink : mark,
                              ),
                              SizedBox(height: f * .7),
                              Text(
                                ref,
                                textAlign: TextAlign.center,
                                style: refs(f),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: w * .04),
                Text(
                  'DAILY KJB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Parchment.caps,
                    fontSize: w * .026,
                    letterSpacing: w * .008,
                    fontWeight: FontWeight.w700,
                    color: ink.withValues(alpha: .55),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
