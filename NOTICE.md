# Notices

Daily KJB is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).

Required Notice: Copyright (c) 2026 Will Reeves (https://github.com/Cinderwire-co/DailyKJB)

## Third-party material

The Bible text and study data in `dailykjb/assets/bible` and `dailykjb/assets/study` are built by `tools/prepare_study_data.py`. Each keeps its own terms, below; none of them is covered by the PolyForm license.

| Files | What | From | Terms |
| --- | --- | --- | --- |
| `assets/bible/kjb.tsv.gz`, `assets/bible/books.tsv` | The King James Bible | The text is in the public domain; this copy from [Bible-kjv](https://github.com/aruljohn/Bible-kjv) by Arul John | MIT, below |
| `assets/study/words/*.tsv.gz` | Each verse's words with their Strong's numbers | [CrossWire Bible Society](https://crosswire.org) KJV module 3.1 (Old Testament numbers from the Bible Foundation, New Testament from the KJV2003 Project) | CrossWire Bible Society: "a general public license to use this text for any purpose" |
| `assets/study/strongs.tsv.gz` | Strong's Hebrew and Greek dictionaries | James Strong, *The Exhaustive Concordance of the Bible* (1894), via [Open Scriptures](https://github.com/openscriptures/strongs) | Public domain |
| `assets/study/xrefs/*.tsv.gz` | Cross references, the best 20 for each verse | [OpenBible.info](https://www.openbible.info/labs/cross-references/), from the Treasury of Scripture Knowledge | [CC BY](https://creativecommons.org/licenses/by/4.0/). Attribution, as the app shows it: "Cross references from OpenBible.info" |
| `assets/study/webster/*.tsv.gz` | Noah Webster, *An American Dictionary of the English Language* (1828) | The dictionary is in the public domain; this copy from [1828-dictionary](https://github.com/DataWar/1828-dictionary) by DataWar, from Project Gutenberg | MIT, below |
| `assets/fonts/Cinzel-*.ttf` | Cinzel | Copyright 2020 The Cinzel Project Authors | [SIL Open Font License 1.1](dailykjb/assets/fonts/OFL.txt) |
| `assets/fonts/EBGaramond-*.ttf` | EB Garamond | Copyright 2017 The EB Garamond Project Authors | [SIL Open Font License 1.1](dailykjb/assets/fonts/OFL.txt) |

Flutter and the Dart packages listed in `dailykjb/pubspec.yaml` are each under their own license. Run `flutter pub deps` to list them.

### MIT License (Bible-kjv)

Copyright (c) 2019 Arul John

### MIT License (1828-dictionary)

Copyright (c) 2021 DataWar

The same terms apply to both:

> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
