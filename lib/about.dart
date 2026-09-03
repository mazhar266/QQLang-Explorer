// The About dialog: what this is, and who made it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's own version.
///
/// Kept in step with `version:` in pubspec.yaml by a test, which fails if the
/// two ever drift apart.
const kAppVersion = '1.0.0';

const _author = 'Mazhar Ahmed';
const _web = 'www.mazhar.fi';

const _credentials = [
  'BA in Islamic Studies from IOU',
  'Dawra-e-Hadith from Qawmi Madrasa, Bangladesh',
];

/// Show the About dialog.
///
/// [engineVersion] is QQL's version, which is a different thing from the
/// app's. [libraryVersion] is what the loaded library reports for itself:
/// when it disagrees with the tag, the build is behind the checkout and
/// saying so beats quietly showing one number.
Future<void> showAboutQqlExplorer(
  BuildContext context, {
  String? engineVersion,
  String? libraryVersion,
}) => showDialog<void>(
  context: context,
  builder: (context) => _AboutDialog(
    engineVersion: engineVersion,
    libraryVersion: libraryVersion,
  ),
);

class _AboutDialog extends StatelessWidget {
  const _AboutDialog({this.engineVersion, this.libraryVersion});

  final String? engineVersion;
  final String? libraryVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/app_icon_128.png',
                    width: 56,
                    height: 56,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'QQL Explorer',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Version $kAppVersion',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (engineVersion != null)
                        Text(
                          'QQL engine $engineVersion',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                      if (libraryVersion != null &&
                          libraryVersion != engineVersion)
                        Text(
                          'loaded library reports $libraryVersion',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Text(
              'Initiated by',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _author,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const _WebLink(_web),
            const SizedBox(height: 18),
            for (final credential in _credentials)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        credential,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// The author's site, opened with whatever the platform uses to open things.
///
/// Handing the URL to `xdg-open` and its equivalents avoids a plugin for one
/// link. If that fails — no opener on a bare desktop, say — the address goes
/// to the clipboard instead, so the click is never simply inert.
class _WebLink extends StatelessWidget {
  const _WebLink(this.url);

  final String url;

  static const _openers = {
    'linux': 'xdg-open',
    'macos': 'open',
    'windows': 'explorer',
  };

  Future<void> _open(ScaffoldMessengerState messenger) async {
    final opener = Platform.isMacOS
        ? _openers['macos']!
        : Platform.isWindows
        ? _openers['windows']!
        : _openers['linux']!;

    var opened = false;
    try {
      final result = await Process.run(opener, ['https://$url']);
      // `explorer` reports failure even when it worked, so on Windows the
      // exit code is not worth believing.
      opened = result.exitCode == 0 || Platform.isWindows;
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: 'https://$_web'));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open a browser — address copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    return InkWell(
      onTap: () => _open(messenger),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language_rounded, size: 16, color: colors.primary),
            const SizedBox(width: 7),
            Text(
              url,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: colors.primary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
