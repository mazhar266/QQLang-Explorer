// The collections QQL can resolve, and the panel that shows them.
//
// Transcribed from the project wiki:
// https://github.com/mazhar266/QQ-Lang/wiki/Sources
//
// One definition, used by both the home screen and the reference drawer. The
// chapter counts were checked against the data rather than taken on trust —
// B:97 resolves and B:98 does not, and so on down the table.

import 'package:flutter/material.dart';

/// One collection QQL knows about.
class QqlSource {
  const QqlSource(
    this.code,
    this.name, {
    required this.primaryLabel,
    required this.primaryRange,
    this.flatRange,
    this.alias,
    this.note,
  });

  /// The short code a query names it by, e.g. `B`.
  final String code;

  final String name;

  /// What the first-level index means — Surah for the Quran, chapter for the
  /// rest.
  final String primaryLabel;

  /// The range that index runs over, e.g. `1–97`.
  final String primaryRange;

  /// The range of the flat `CODE::N` form, or null for the six collections
  /// with no canonical citation numbering QQL can source.
  final String? flatRange;

  final String? alias;
  final String? note;

  /// The one line under the name.
  String get summary => [
    '$primaryLabel $primaryRange',
    if (flatRange != null) '::$flatRange',
  ].join('  ·  ');

  /// The fuller reading, for a tooltip.
  String get detail => [
    '$code — $name',
    '$primaryLabel $primaryRange',
    if (flatRange != null)
      '$code::N numbers $flatRange across the collection'
    else
      'No citation numbering QQL can source, so $code::N is refused',
    if (alias != null) 'Also answers to $alias',
    ?note,
  ].join('\n');
}

/// Every built-in source, in the order the registry declares them.
const kSources = [
  QqlSource(
    'Q',
    'Quran',
    primaryLabel: 'Surah',
    primaryRange: '1–114',
    flatRange: '1–6236',
    note: 'The default — a query naming no source means the Quran.',
  ),
  QqlSource(
    'B',
    'Sahih al-Bukhari',
    primaryLabel: 'kitab',
    primaryRange: '1–97',
    flatRange: '1–7563',
  ),
  QqlSource(
    'M',
    'Sahih Muslim',
    primaryLabel: 'chapter',
    primaryRange: '1–56',
    flatRange: '1–7563',
  ),
  QqlSource(
    'AD',
    'Sunan Abi Dawud',
    primaryLabel: 'chapter',
    primaryRange: '1–43',
    flatRange: '1–5274',
  ),
  QqlSource(
    'T',
    "Jami' at-Tirmidhi",
    primaryLabel: 'chapter',
    primaryRange: '1–49',
    flatRange: '1–3956',
  ),
  QqlSource(
    'N',
    "Sunan an-Nasa'i",
    primaryLabel: 'chapter',
    primaryRange: '1–51',
    flatRange: '1–5758',
  ),
  QqlSource(
    'IM',
    'Sunan Ibn Majah',
    primaryLabel: 'chapter',
    primaryRange: '1–37',
    flatRange: '1–4341',
  ),
  QqlSource(
    'MA',
    'Muwatta Malik',
    primaryLabel: 'chapter',
    primaryRange: '1–61',
    flatRange: '1–1858',
  ),
  QqlSource(
    'DA',
    'Sunan ad-Darimi',
    primaryLabel: 'chapter',
    primaryRange: '1–23',
    note: 'Arabic only — upstream carries no English for its 2,757 hadiths.',
  ),
  QqlSource(
    'RS',
    'Riyad as-Salihin',
    primaryLabel: 'chapter',
    primaryRange: '1–19',
  ),
  QqlSource(
    'BM',
    'Bulugh al-Maram',
    primaryLabel: 'chapter',
    primaryRange: '1–16',
  ),
  QqlSource(
    'AM',
    'Al-Adab Al-Mufrad',
    primaryLabel: 'chapter',
    primaryRange: '1–57',
  ),
  QqlSource(
    'MK',
    'Mishkat al-Masabih',
    primaryLabel: 'chapter',
    primaryRange: '1–24',
  ),
  QqlSource(
    'SM',
    "Ash-Shama'il Al-Muhammadiyah",
    primaryLabel: 'chapter',
    primaryRange: '1–56',
  ),
  QqlSource(
    'NW',
    "Al-Arba'in an-Nawawiyyah",
    primaryLabel: 'chapter',
    primaryRange: '1',
    flatRange: '1–42',
    note: 'An undivided book, so NW::13 and NW:1:13 are the same hadith.',
  ),
  QqlSource(
    'QD',
    'Forty Hadith Qudsi',
    primaryLabel: 'chapter',
    primaryRange: '1',
    flatRange: '1–40',
    note: 'An undivided book, so QD::13 and QD:1:13 are the same hadith.',
  ),
  QqlSource(
    'SW',
    'Forty Hadith of Shah Waliullah',
    primaryLabel: 'chapter',
    primaryRange: '1',
    flatRange: '1–40',
    note: 'An undivided book, so SW::13 and SW:1:13 are the same hadith.',
  ),
  QqlSource(
    'HM',
    'Hisnul Muslim',
    primaryLabel: 'chapter',
    primaryRange: '1–132',
    flatRange: '1–267',
    alias: 'HISN',
  ),
];

/// The home screen: what there is to query, before anything has been queried.
class SourcesPanel extends StatelessWidget {
  const SourcesPanel({super.key, required this.onPick});

  /// Called with a code when one is chosen, to start a query with it.
  final void Function(String code) onPick;

  /// Columns at a given content width. A phone gets one, a tablet or a
  /// narrow window two, a desktop three — chosen so a tile never falls below
  /// about 240 logical pixels, which is where the collection names start to
  /// truncate.
  static int columnsFor(double width) {
    if (width >= 840) return 3;
    if (width >= 520) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Narrow screens cannot spare 24 either side.
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 520 ? 14.0 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 22, pad, 40),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 2,
          children: [
            Text('Sources', style: theme.textTheme.titleMedium),
            Text(
              '${kSources.length} collections. Pick a code to start a '
              'query with it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // The tiles divide the row rather than being a fixed size, so a
        // narrow window gets whole tiles instead of a column with the rest of
        // the width left ragged beside it.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = columnsFor(constraints.maxWidth);
            final tile =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final source in kSources)
                  SizedBox(
                    width: tile,
                    child: _SourceTile(source: source, onPick: onPick),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'The code is optional and the Quran is assumed, so 2:255 and '
          'Q:2:255 are the same query. A stated code then carries forward '
          'until another one replaces it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.onPick});

  final QqlSource source;
  final void Function(String code) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Tooltip(
      message: source.detail,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onPick(source.code),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    source.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.summary,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
