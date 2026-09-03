// Rendering one QQL record.
//
// Records are not a fixed shape: `source`, `collection`, `ar` and `en` are
// the only fields every source promises, and the rest — `surah`/`ayah` for
// the Quran, `chapter`/`number`/`narrator` for hadith, `note` and `audio` for
// Hisnul Muslim — is flattened in alongside them. So the known fields get
// laid out deliberately and anything left over is shown as a chip, which
// means a source this app has never heard of still renders completely.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lists_ui.dart';
import 'saved_lists.dart';

/// Fields this card lays out itself, and so must not repeat as chips.
const _handled = {
  'source',
  'collection',
  'ar',
  'en',
  'score',
  'ranked',
  'surah',
  'ayah',
  'surah_name_ar',
  'surah_name_en',
  'chapter',
  'number',
  'chapter_name_ar',
  'chapter_name_en',
  'chapter_title',
  'narrator',
  'note',
};

/// A record's fields, read defensively — every one of them is optional.
class RecordView {
  RecordView(this.raw);

  final Map<String, dynamic> raw;

  String get code => '${raw['source'] ?? '?'}';
  String get collection => '${raw['collection'] ?? ''}';
  String get ar => '${raw['ar'] ?? ''}';
  String get en => '${raw['en'] ?? ''}';

  String? get narrator => _text('narrator');
  String? get note => _text('note');

  /// Arabic name of the surah or chapter, for the right-hand side of the
  /// header.
  String? get titleAr => _text('surah_name_ar') ?? _text('chapter_name_ar');

  /// English name of the surah or chapter.
  String? get titleEn =>
      _text('surah_name_en') ??
      _text('chapter_name_en') ??
      _text('chapter_title');

  /// The citation, in the collection's own numbering.
  String get reference {
    final surah = raw['surah'], ayah = raw['ayah'];
    if (surah != null && ayah != null) return '$surah:$ayah';

    final chapter = raw['chapter'], number = raw['number'];
    if (chapter != null && number != null) return '$chapter:$number';
    if (chapter != null) return 'ch. $chapter';
    if (number != null) return '#$number';
    return '';
  }

  /// Relevance, on ranked hits only. Everything else is in written order.
  double? get score {
    final value = raw['score'];
    return value is num ? value.toDouble() : null;
  }

  /// Whatever this source carries that the layout above does not name.
  Map<String, dynamic> get extras => {
    for (final entry in raw.entries)
      if (!_handled.contains(entry.key)) entry.key: ?entry.value,
  };

  String? _text(String key) {
    final value = raw[key];
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// The record as text, for the clipboard.
  String get asPlainText => [
    '$collection${reference.isEmpty ? '' : ' $reference'}',
    if (ar.isNotEmpty) ar,
    ?narrator,
    if (en.isNotEmpty) en,
  ].join('\n\n');
}

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.record,
    required this.index,
    required this.lists,
    required this.query,
    this.saved,
  });

  final Map<String, dynamic> record;

  /// Position in the result list, shown so a hit can be referred to out loud.
  final int index;

  final SavedLists lists;

  /// The query behind this record, saved with it as provenance.
  final String query;

  /// Set when the card is showing a saved item rather than a search result.
  /// The card then offers removal and says where the record came from.
  final ({SavedList list, SavedItem item})? saved;

  @override
  Widget build(BuildContext context) {
    final view = RecordView(record);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              view: view,
              index: index,
              record: record,
              lists: lists,
              query: query,
              saved: saved,
            ),
            if (view.ar.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ArabicText(view.ar),
            ],
            if (view.narrator != null) ...[
              const SizedBox(height: 16),
              Text(
                view.narrator!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (view.en.isNotEmpty) ...[
              SizedBox(height: view.narrator == null ? 16 : 6),
              SelectableText(
                view.en,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ],
            if (view.note != null) ...[
              const SizedBox(height: 10),
              SelectableText(
                view.note!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
            if (view.extras.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Extras(view.extras),
            ],
            if (saved != null) ...[
              const SizedBox(height: 14),
              _Provenance(saved!.item),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.view,
    required this.index,
    required this.record,
    required this.lists,
    required this.query,
    required this.saved,
  });

  final RecordView view;
  final int index;
  final Map<String, dynamic> record;
  final SavedLists lists;
  final String query;
  final ({SavedList list, SavedItem item})? saved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SourceBadge(view.code),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${view.collection}'
                      '${view.reference.isEmpty ? '' : '  ${view.reference}'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (view.score != null) ...[
                    const SizedBox(width: 8),
                    _ScorePill(view.score!),
                  ],
                ],
              ),
              if (view.titleEn != null || view.titleAr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (view.titleEn != null) view.titleEn!,
                      if (view.titleAr != null) view.titleAr!,
                    ].join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Text(
          '${index + 1}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.outline,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (saved == null)
          AddToListButton(lists: lists, record: record, query: query)
        else
          IconButton(
            tooltip: 'Remove from ${saved!.list.name}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
            onPressed: () =>
                lists.removeItem(saved!.list.id, saved!.item.key),
          ),
        IconButton(
          tooltip: 'Copy',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 17),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: view.asPlainText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied'),
                behavior: SnackBarBehavior.floating,
                width: 160,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill(this.score);

  final double score;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 12,
              color: colors.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onTertiaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Arabic body, right-to-left and set large enough for the diacritics to
/// resolve. The text is shown exactly as stored — nothing here rewrites it.
class _ArabicText extends StatelessWidget {
  const _ArabicText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SelectableText(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: 'Amiri Quran',
          fontFamilyFallback: [
            'Noto Naskh Arabic',
            'Noto Sans Arabic',
            'DejaVu Sans',
          ],
          fontSize: 25,
          height: 2.0,
        ),
      ),
    );
  }
}

/// Fields the layout above does not name — `repeat` and `audio` on Hisnul
/// Muslim, and whatever a user-defined source adds.
class _Extras extends StatelessWidget {
  const _Extras(this.fields);

  final Map<String, dynamic> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final entry in fields.entries)
          Tooltip(
            message: '${entry.key}: ${entry.value}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                '${entry.key} ${_short('${entry.value}')}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _short(String value) =>
      value.length <= 40 ? value : '${value.substring(0, 39)}…';
}

/// Where a saved record came from. Months after the fact, the query that
/// found a verse is often the thing worth remembering about it.
class _Provenance extends StatelessWidget {
  const _Provenance(this.item);

  final SavedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final added = item.added;

    return Row(
      children: [
        Icon(Icons.subdirectory_arrow_right_rounded,
            size: 14, color: colors.outline),
        const SizedBox(width: 6),
        Flexible(
          child: SelectableText(
            item.query,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'saved ${added.year}-${_two(added.month)}-${_two(added.day)}',
          style: theme.textTheme.labelSmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
