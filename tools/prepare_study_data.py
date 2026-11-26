#!/usr/bin/env python3
"""Builds the app's offline Bible and study data from public reference files.

Usage: python3 tools/prepare_study_data.py <source-folder>

Writes into dailykjb/assets.

The source folder holds books.tsv, kjb.tsv, strongs.tsv.gz, words.tsv.gz,
xrefs.tsv.gz and webster1828.tsv.gz (see NOTICE.md for where each comes from).

Writes, under assets/:
  bible/books.tsv            id, name, testament, chapters
  bible/kjb.tsvz             book, chapter, verse, text (the whole King James Bible)
  study/strongs.tsvz         Strong's Hebrew and Greek dictionaries
  study/words/<book>.tsvz    chapter, verse, the verse's words with their Strong's numbers (JSON)
  study/xrefs/<book>.tsvz    chapter, verse, to_book, to_chapter, to_verse, to_end, votes
  study/webster/<x>.tsvz     word, heading, entry (Webster's 1828), split by first letter

.tsvz is gzipped TSV. Not .gz: Android's asset packaging handles files ending in .gz
itself, and the app couldn't open them there.

Split by book and by letter so a lookup only ever opens one small file.
See NOTICE.md for where each comes from and its terms.
"""
import gzip
import os
import shutil
import sys
from collections import defaultdict

if len(sys.argv) < 2:
    sys.exit(__doc__)
src = sys.argv[1]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dailykjb', 'assets')


def rows(name):
    path = os.path.join(src, name)
    opener = gzip.open if name.endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8') as f:
        lines = f.read().rstrip('\n').split('\n')
    return lines[0], [l.split('\t') for l in lines[1:]]


def write(path, header, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (header + '\n' + '\n'.join(lines) + '\n').encode('utf-8')
    # mtime=0: the same input gives the same bytes, so git only sees real changes
    with open(path, 'wb') as f:
        with gzip.GzipFile(fileobj=f, mode='wb', compresslevel=9, mtime=0) as g:
            g.write(data)


def main():
    os.makedirs(os.path.join(root, 'bible'), exist_ok=True)
    shutil.copy(os.path.join(src, 'books.tsv'), os.path.join(root, 'bible', 'books.tsv'))
    h, kjb = rows('kjb.tsv')
    write(os.path.join(root, 'bible', 'kjb.tsvz'), h, ['\t'.join(r) for r in kjb])

    h, strongs = rows('strongs.tsv.gz')
    write(os.path.join(root, 'study', 'strongs.tsvz'), h, ['\t'.join(r) for r in strongs])

    _, words = rows('words.tsv.gz')
    by_book = defaultdict(list)
    for b, c, v, w in words:
        by_book[b].append(f'{c}\t{v}\t{w}')
    for b, lines in by_book.items():
        write(os.path.join(root, 'study', 'words', f'{b}.tsvz'), 'chapter\tverse\twords', lines)

    _, xrefs = rows('xrefs.tsv.gz')
    by_book = defaultdict(list)
    for b, c, v, tb, tc, tv, te, votes in xrefs:
        by_book[b].append('\t'.join([c, v, tb, tc, tv, te, votes]))
    for b, lines in by_book.items():
        write(os.path.join(root, 'study', 'xrefs', f'{b}.tsvz'), 'chapter\tverse\tto_book\tto_chapter\tto_verse\tto_end\tvotes', lines)

    _, webster = rows('webster1828.tsv.gz')
    by_letter = defaultdict(list)
    for r in webster:
        if len(r) < 3:
            continue
        word, heading, entry = r[0], r[1], r[2]
        first = word[:1].lower()
        by_letter[first if 'a' <= first <= 'z' else '_'].append(f'{word}\t{heading}\t{entry}')
    for x, lines in by_letter.items():
        write(os.path.join(root, 'study', 'webster', f'{x}.tsvz'), 'word\theading\tentry', lines)

    print(f'{len(kjb)} verses, {len(strongs)} Strong\'s entries, {len(words)} verses of words, '
          f'{len(xrefs)} cross references, {len(webster)} Webster entries')


if __name__ == '__main__':
    main()
