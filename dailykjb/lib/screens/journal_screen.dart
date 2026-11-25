import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../bible/kjb.dart';
import '../models/highlight.dart';
import '../models/verse_note.dart';
import '../services/marks.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'reader.dart';

/// Every note and highlight in one place: find in them, open each where it is.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, this.visible = true});
  final bool visible;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _q = TextEditingController();
  String _show = 'notes';

  @override
  void initState() {
    super.initState();
    if (!Marks.i.loaded) Marks.i.load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _words(String book, int chapter, int start, int end) {
    final b = Kjb.named(book);
    if (b == null) return '';
    final v = Kjb.verses(b.id, chapter);
    return [for (var n = start; n <= end && n <= v.length; n++) v[n - 1]]
        .join(' ');
  }

  void _open(String book, int chapter, int verse) {
    final b = Kjb.named(book);
    if (b != null) openInBible(context, b.id, chapter, verse);
  }

  String _ref(String book, int chapter, int start, int end) {
    final name = book == 'Psalms' ? 'Psalm' : book;
    return start == end
        ? '$name $chapter:$start'
        : '$name $chapter:$start–$end';
  }

  Future<void> _noteActions(VerseNote n) async {
    final r = await writeNote(
      context,
      title: _ref(n.book, n.chapter, n.startVerse, n.endVerse),
      verse: n.verseTexts.isNotEmpty
          ? n.verseTexts.join(' ')
          : _words(n.book, n.chapter, n.startVerse, n.endVerse),
      initial: n.content,
      canDelete: true,
    );
    if (r == null) return;
    if (r == noteDeleted) {
      await Marks.i.deleteNote(n);
    } else if (r.trim().isNotEmpty) {
      await Marks.i.updateNote(n, r.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Leaf(
      title: 'Journal',
      back: false,
      body: ListenableBuilder(
        listenable: Marks.i,
        builder: (context, _) {
          final q = _q.text.trim().toLowerCase();
          final notes = Marks.i.notes
              .where(
                (n) =>
                    q.isEmpty ||
                    n.content.toLowerCase().contains(q) ||
                    n.reference.toLowerCase().contains(q),
              )
              .toList();
          final hls = Marks.i.highlights
              .where(
                (h) =>
                    q.isEmpty ||
                    h.reference.toLowerCase().contains(q) ||
                    _words(
                      h.book,
                      h.chapter,
                      h.startVerse,
                      h.endVerse,
                    ).toLowerCase().contains(q),
              )
              .toList();
          final list = _show == 'notes' ? notes : hls;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              MediaQuery.paddingOf(context).bottom + 30,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                style: p.body,
                decoration: InputDecoration(
                  hintText: 'Find in your notes and highlights',
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: p.faded,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  Pill(
                    'Notes · ${Marks.i.notes.length}',
                    on: _show == 'notes',
                    onTap: () => setState(() => _show = 'notes'),
                  ),
                  Pill(
                    'Highlights · ${Marks.i.highlights.length}',
                    on: _show == 'highlights',
                    onTap: () => setState(() => _show = 'highlights'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!Marks.i.loaded)
                const Padding(padding: EdgeInsets.all(30), child: Waiting())
              else if (list.isEmpty)
                Empty(
                  q.isNotEmpty
                      ? 'Nothing matches.'
                      : _show == 'notes'
                      ? 'Tap a verse while you read, then Note.'
                      : 'Tap a verse while you read, then a colour.',
                  title: q.isNotEmpty
                      ? null
                      : _show == 'notes'
                      ? 'No notes yet'
                      : 'No highlights yet',
                  icon: _show == 'notes'
                      ? CupertinoIcons.pencil_outline
                      : CupertinoIcons.paintbrush,
                )
              else if (_show == 'notes')
                for (final n in notes) _noteRow(n)
              else
                for (final h in hls) _highlightRow(h),
            ],
          );
        },
      ),
    );
  }

  Widget _noteRow(VerseNote n) {
    final p = context.parch;
    final words = n.verseTexts.isNotEmpty
        ? n.verseTexts.join(' ')
        : _words(n.book, n.chapter, n.startVerse, n.endVerse);
    return Column(
      children: [
        Tap(
          onTap: () => _open(n.book, n.chapter, n.startVerse),
          onLongPress: () => _noteActions(n),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 52, color: p.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _ref(n.book, n.chapter, n.startVerse, n.endVerse),
                            style: p.small.copyWith(
                              color: p.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d').format(n.updatedAt),
                          style: p.small.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(n.content, style: p.body.copyWith(color: p.inkStrong)),
                    const SizedBox(height: 2),
                    Text(
                      words,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.small.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              Tap(
                onTap: () => _noteActions(n),
                padding: const EdgeInsets.fromLTRB(10, 2, 0, 8),
                semantics: 'Edit note',
                child: Icon(CupertinoIcons.ellipsis, size: 18, color: p.faded),
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _highlightRow(VerseHighlight h) {
    final p = context.parch;
    final words = _words(h.book, h.chapter, h.startVerse, h.endVerse);
    final ref = _ref(h.book, h.chapter, h.startVerse, h.endVerse);
    return Column(
      children: [
        Tap(
          onTap: () => _open(h.book, h.chapter, h.startVerse),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 52,
                color: Parchment.highlight(h.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ref,
                            style: p.small.copyWith(
                              color: p.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d').format(h.createdAt),
                          style: p.small.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      words,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: p.body.copyWith(fontSize: 16.5),
                    ),
                  ],
                ),
              ),
              Tap(
                onTap: () => sheet(
                  context,
                  title: ref,
                  body: (ctx) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(words, style: ctx.parch.body),
                      const SizedBox(height: 16),
                      ParchButton(
                        'Share',
                        icon: CupertinoIcons.square_arrow_up,
                        expand: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          SharePlus.instance.share(
                            ShareParams(text: '"$words" $ref (KJB)'),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ParchButton(
                        'Remove the highlight',
                        kind: Btn.quiet,
                        expand: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          Marks.i.removeHighlight(h);
                        },
                      ),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(10, 2, 0, 8),
                semantics: 'Highlight options',
                child: Icon(CupertinoIcons.ellipsis, size: 18, color: p.faded),
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}
