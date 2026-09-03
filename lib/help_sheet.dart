// The syntax and source-code reference, in a side drawer.
//
// Condensed from the QQ Lang README. It is a drawer rather than a dialog so
// it can be read next to the query being written.

import 'package:flutter/material.dart';

import 'sources.dart';

/// Syntax, as `(form, what it means)`.
const _syntax = [
  ('Q:2:255', 'Surah 2, ayah 255'),
  ('Q:2:1-5,255', 'a range, plus one more'),
  ('2:255', 'the source is optional — it means the Quran'),
  ('Q:1;B:1:1', '; separates references and switches collection'),
  ('b:1:1;3', 'a stated source carries forward'),
  ('Q:1,2,3', 'three whole surahs'),
  ('q:1:2,3,2:3', 'an integer before : starts a new chapter'),
  ('B::100', ':: numbers across the whole collection'),
  ('q:"mercy"', 'exact substring, Arabic and English together'),
  ('q:1:"الحمد"', 'Arabic matches with the marks folded away'),
  ('q:1:3~5:"x"', '~ scopes a search to a range of items'),
  ('q:?"mercy"~5', 'ranked full text, capped at 5'),
  ('q:*"worship"~5', 'ranked similarity, capped at 5'),
];

class HelpDrawer extends StatelessWidget {
  const HelpDrawer({super.key, required this.version, required this.home});

  final String? version;
  final String home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      width: 460,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 40),
          children: [
            Text('QQL reference', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              version == null ? home : 'qql $version  ·  $home',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Syntax'),
            for (final (form, meaning) in _syntax)
              _Row(mono: form, text: meaning),
            const SizedBox(height: 24),
            _SectionTitle('Sources'),
            for (final source in kSources)
              _Row(
                mono: source.code,
                text: source.name,
                trailing: source.summary,
              ),
            const SizedBox(height: 24),
            Text(
              'Ranked search needs the library built with the vector and '
              'fulltext features; without them those forms are refused with '
              'QQL_UNSUPPORTED rather than quietly falling back.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.mono, required this.text, this.trailing});

  final String mono;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: SelectableText(
              mono,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trailing == null ? text : '$text\n$trailing',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
