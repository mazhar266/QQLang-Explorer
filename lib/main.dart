// QQL Explorer — a text field, a search button, and the records QQL returns.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';

import 'help_sheet.dart';
import 'qql_client.dart';
import 'result_card.dart';

void main(List<String> args) {
  // `qqlang_explorer 'Q:2:255'` opens with that query already run.
  runApp(QqlExplorerApp(initialQuery: args.isEmpty ? null : args.first));
}

/// Query forms worth one click, chosen to reach every kind of result the app
/// can render: a single ayah, a whole surah, hadith, both ranked engines, and
/// a query that crosses collections.
const _examples = [
  ('Q:2:255', 'Ayat al-Kursi'),
  ('Q:1', 'Al-Fatihah'),
  ('B:1:1', 'Bukhari, the first hadith'),
  ('q:1:"الحمد"', 'Arabic substring'),
  ('q:?"mercy"~5', 'ranked full text'),
  ('q:*"worship"~5', 'ranked similarity'),
  ('HM:1', 'Hisnul Muslim'),
  ('2:255;B:1:1', 'two collections at once'),
];

class QqlExplorerApp extends StatelessWidget {
  const QqlExplorerApp({super.key, this.initialQuery});

  /// Query to run on launch, if one was given on the command line.
  final String? initialQuery;

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QQL Explorer',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: ExplorerPage(initialQuery: initialQuery),
    );
  }
}

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final _client = QqlClient();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  QueryOutcome? _outcome;

  /// The query [_outcome] came from, which is not necessarily what the field
  /// holds now.
  String _ranQuery = '';

  @override
  void initState() {
    super.initState();
    _client.open();

    // Assigned rather than routed through `_search`, so the results are
    // there on the first frame instead of after an empty one.
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      _ranQuery = initial;
      _outcome = _client.run(initial);
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _search([String? query]) {
    if (query != null) _controller.text = query;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _ranQuery = text;
      _outcome = _client.run(text);
    });

    if (_scroll.hasClients) _scroll.jumpTo(0);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 24,
        title: Row(
          children: [
            Text(
              'QQL Explorer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            if (_client.version != null)
              Text(
                'qql ${_client.version}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Syntax and sources',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: Scaffold.of(context).openEndDrawer,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      endDrawer: HelpDrawer(version: _client.version, home: QqlPaths.home),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Column(
            children: [
              _buildSearchBar(theme),
              const Divider(height: 1),
              Expanded(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: _client.isOpen,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Q:2:255',
                    prefixIcon: const Icon(Icons.terminal_rounded, size: 20),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(_controller.clear),
                          ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  // Redraws so the clear button appears with the first
                  // character and leaves with the last.
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _client.isOpen ? _search : null,
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text('Search'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (query, description) in _examples)
                Tooltip(
                  message: description,
                  child: ActionChip(
                    label: Text(
                      query,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: _client.isOpen ? () => _search(query) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_client.isOpen) {
      return _Notice(
        icon: Icons.link_off_rounded,
        title: 'QQL library not loaded',
        detail: _client.openError ?? '',
        tone: theme.colorScheme.error,
      );
    }

    final outcome = _outcome;
    if (outcome == null) {
      return _Notice(
        icon: Icons.search_rounded,
        title: 'Write a reference, or pick one above',
        detail:
            'Q:2:255 is Surah 2 ayah 255. The source is optional and the '
            'Quran is assumed, so 2:255 is the same query.',
        tone: theme.colorScheme.onSurfaceVariant,
      );
    }

    return switch (outcome) {
      QueryFailed() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: _ErrorCard(failure: outcome, query: _ranQuery),
      ),
      QueryOk(records: final records, elapsed: final elapsed) =>
        records.isEmpty
            ? _Notice(
                icon: Icons.filter_none_rounded,
                title: 'No matches',
                detail:
                    'The query resolved, and nothing in scope matched. A '
                    'search that finds nothing is an empty result, not an '
                    'error.',
                tone: theme.colorScheme.onSurfaceVariant,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResultSummary(count: records.length, elapsed: elapsed),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                      itemCount: records.length,
                      itemBuilder: (context, i) =>
                          ResultCard(record: records[i], index: i),
                    ),
                  ),
                ],
              ),
    };
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.count, required this.elapsed});

  final int count;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 6),
      child: Text(
        '$count ${count == 1 ? 'result' : 'results'}'
        '  ·  ${elapsed.inMilliseconds} ms',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A refused query, with the caret under the character QQL objected to.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.failure, required this.query});

  final QueryFailed failure;
  final String query;

  /// QQL reports a byte offset; the caret has to go under a character.
  static int? _charOffset(String query, int? bytePosition) {
    if (bytePosition == null || bytePosition < 0) return null;
    final bytes = utf8.encode(query);
    if (bytePosition > bytes.length) return null;
    try {
      return utf8.decode(bytes.sublist(0, bytePosition)).length;
    } on FormatException {
      // The offset landed mid-character; no caret is better than a wrong one.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final caret = _charOffset(query, failure.position);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
              const SizedBox(width: 8),
              SelectableText(
                failure.code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.error,
                ),
              ),
              if (failure.position != null) ...[
                const SizedBox(width: 8),
                Text(
                  'at ${failure.position}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            failure.message,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          if (caret != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                '$query\n${' ' * caret}^',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The empty, unloaded and no-match states, which differ only in wording.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: tone.withValues(alpha: 0.7)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: tone),
              ),
              const SizedBox(height: 10),
              SelectableText(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                  fontFamily: detail.contains('cargo build') ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
