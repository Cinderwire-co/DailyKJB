import 'package:daily_kjb/bible/kjb.dart';
import 'package:daily_kjb/bible/study_data.dart';
import 'package:daily_kjb/models/user_data.dart';
import 'package:daily_kjb/services/bible_service.dart';
import 'package:daily_kjb/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Kjb.load();
  });

  group('The Bible in the app', () {
    test('has every book, chapter and verse', () {
      expect(Kjb.books.length, 66);
      expect(Kjb.total, 1189);
      expect(
        Kjb.verses(1, 1).first,
        startsWith('In the beginning God created'),
      );
      expect(Kjb.verses(19, 119).length, 176);
      expect(Kjb.verses(66, 22).length, 21);
    });

    test('finds books by name and abbreviation', () {
      expect(Kjb.named('Psalm')?.id, 19);
      expect(Kjb.named('Psa.')?.id, 19);
      expect(Kjb.named('1 Co')?.name, '1 Corinthians');
      expect(Kjb.named('Song of Songs')?.name, 'Song of Solomon');
      expect(Kjb.named('jn')?.name, 'John');
      expect(Kjb.ref('John 3:16'), (43, 3, 16));
      expect(Kjb.ref('ps 23'), (19, 23, null));
      expect(Kjb.ref('Jude 2'), null); // Jude has one chapter
      expect(Kjb.verse('Proverbs 3:5–6')?.$1, 'Proverbs 3:5–6');
    });
  });

  group('Plan passages', () {
    test('whole chapters', () {
      expect(Kjb.spans('Gen 1-3'), [
        const ChapterSpan(1, 1),
        const ChapterSpan(1, 2),
        const ChapterSpan(1, 3),
      ]);
      expect(Kjb.spans('Oba'), [const ChapterSpan(31, 1)]);
      expect(Kjb.spans('Gen 1-3; Ps 1; Pro 1').length, 5);
    });

    test('verses, within and across chapters', () {
      expect(Kjb.spans('Mat 2:1–18'), [const ChapterSpan(40, 2, 1, 18)]);
      expect(Kjb.spans('Mat 2:19–3:17'), [
        const ChapterSpan(40, 2, 19),
        const ChapterSpan(40, 3, null, 17),
      ]);
      expect(Kjb.spans('Heb 11:1–12:3'), [
        const ChapterSpan(58, 11),
        const ChapterSpan(58, 12, null, 3),
      ]);
    });

    test('across books', () {
      final s = Kjb.spans('2 Co 13:11–Gal 1:10');
      expect(s.first, const ChapterSpan(47, 13, 11));
      expect(s.last, const ChapterSpan(48, 1, null, 10));
      expect(s.length, 2);
      final t = Kjb.spans('1 Ti 6:2–2 Ti 1:2');
      expect(t, [
        const ChapterSpan(54, 6, 2),
        const ChapterSpan(55, 1, null, 2),
      ]);
    });

    test('described for people', () {
      expect(Kjb.describe(Kjb.spans('Gen 1-3')), 'Genesis 1–3');
      expect(Kjb.describe(Kjb.spans('Mat 2:19–3:17')), 'Matthew 2:19–3:17');
      expect(Kjb.describe(Kjb.spans('Ps 23')), 'Psalm 23');
      expect(Kjb.describe(Kjb.spans('Jude')), 'Jude');
    });
  });

  group('Every plan, every length', () {
    for (final plan in availablePlans) {
      test(plan.name, () async {
        final units = await BibleService().loadUnits(plan.id);
        expect(units, isNotEmpty);
        for (final u in units) {
          expect(
            u.span.verses(),
            isNotEmpty,
            reason: '${plan.id} unit ${u.index} ${u.span.label}',
          );
        }
        for (final days in planDurationOptions.where(
          (d) => d <= BibleService.maxDays(units),
        )) {
          final spread = BibleService.spread(units, days);
          expect(spread.length, days);
          expect(
            spread.where((d) => d.isEmpty),
            isEmpty,
            reason: '${plan.id} over $days days has an empty day',
          );
          expect(
            spread.expand((d) => d).length,
            units.length,
            reason: 'every chapter once',
          );
        }
      });
    }
  });

  group('Study, offline', () {
    test("Strong's lines up with the verse's words", () async {
      final s = await StudyData.verse(1, 1, 1);
      expect(s.words, isNotEmpty);
      final words = s.text.split(' ');
      final created = words.indexOf('created');
      expect(s.words[s.at[created]].ids, contains('H1254'));
      expect(s.dict['H1254']?.translit, isNotEmpty);
      // "the" in "the heaven" is looked up as heaven
      expect(s.look[words.indexOf('heaven') - 1], 'heaven');
      expect(s.xrefs, isNotEmpty);
    });

    test("Webster's finds the King James forms", () async {
      expect((await StudyData.webster('grace')).entries, isNotEmpty);
      expect((await StudyData.webster('saith')).as, 'say');
      expect((await StudyData.webster('goeth')).as, 'go');
      expect((await StudyData.webster('believeth')).as, isNotNull);
    });
  });

  group('Saved progress', () {
    test('an old save is read, its theme left to the phone', () {
      final u = UserData.fromJsonString(
        '{"name":"Ann","planId":"whole_bible","targetDays":365,"startDate":"2026-01-01","completedReadings":[0,1,2],"themeMode":"dark"}',
      )!;
      expect(u.version, 1);
      expect(u.completedReadings, [0, 1, 2]);
      expect(u.themeMode, 'system');
      expect(u.verseLayout, 'lines');
    });
  });
}
