// Locating the vendored QQL runtime, and running queries against it.
//
// The library and the JSON data are shipped with this app rather than read
// out of a QQ Lang checkout, so the only interesting part is finding the
// bundle: it sits beside the executable in a built app and in third_party/
// when running from the repository.

import 'dart:io';

import 'qql_binding.dart';

/// A QQL runtime bundle: `lib/` beside `sources/`, as the release tarballs
/// from https://github.com/mazhar266/QQ-Lang/releases are laid out.
class QqlBundle {
  const QqlBundle(this.root);

  /// The directory holding `lib/` and `sources/`.
  final String root;

  String get library {
    final name = Platform.isWindows
        ? 'qql.dll'
        : Platform.isMacOS
        ? 'libqql.dylib'
        : 'libqql.so';
    return '$root${Platform.pathSeparator}lib${Platform.pathSeparator}$name';
  }

  String get sources => '$root${Platform.pathSeparator}sources';

  /// The version recorded when the bundle was vendored. Advisory only — the
  /// library is asked for its own version once it is open.
  String? get recordedVersion {
    final file = File('$root${Platform.pathSeparator}VERSION');
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync().trim();
    return text.isEmpty ? null : text;
  }

  bool get isComplete =>
      File(library).existsSync() && Directory(sources).existsSync();

  /// Where the runtime is looked for, in order.
  ///
  /// `QQL_HOME` first so a different build can be tried without moving files
  /// about; then beside the executable, which is where a built app carries
  /// it; then the checkout, which is what `flutter run` and the tests use.
  static List<QqlBundle> candidates() {
    final beside = File(Platform.resolvedExecutable).parent.path;

    return [
      ?_fromEnvironment(),
      QqlBundle('$beside${Platform.pathSeparator}qql'),
      const QqlBundle('third_party/qql'),
    ];
  }

  /// The first candidate that is actually there, or null.
  static QqlBundle? locate() {
    for (final candidate in candidates()) {
      if (candidate.isComplete) return candidate;
    }
    return null;
  }

  static QqlBundle? _fromEnvironment() {
    final home = Platform.environment['QQL_HOME'];
    return (home == null || home.isEmpty) ? null : QqlBundle(home);
  }
}

/// What a query produced.
sealed class QueryOutcome {
  const QueryOutcome();
}

/// Records, in the order QQL returned them.
class QueryOk extends QueryOutcome {
  const QueryOk(this.records, this.elapsed);

  final List<Map<String, dynamic>> records;
  final Duration elapsed;
}

/// A query QQL refused — a syntax error, an out-of-range reference, or a
/// search engine the library was built without.
class QueryFailed extends QueryOutcome {
  const QueryFailed(this.code, this.message, this.position);

  final String code;
  final String message;

  /// Byte offset into the query the error points at, when QQL knows one.
  final int? position;
}

/// One long-lived QQL context.
///
/// The context caches every data file it reads, so it is worth keeping rather
/// than opening per query. Queries run on the main isolate: the slowest thing
/// QQL can be asked — an exact search across a whole hadith collection —
/// measures about 250 ms, which is not worth an isolate handshake.
class QqlClient {
  Qql? _qql;

  /// Why the library could not be opened, if it could not be.
  String? openError;

  /// The version the library reports for itself, once open.
  String? version;

  /// The bundle in use, once found.
  QqlBundle? bundle;

  bool get isOpen => _qql != null;

  /// Open the context. Safe to call more than once; only the first opens.
  void open() {
    if (_qql != null) return;

    final found = QqlBundle.locate();
    if (found == null) {
      openError =
          'No QQL runtime found. Looked in:\n\n'
          '${QqlBundle.candidates().map((c) => '    ${c.root}').join('\n')}\n\n'
          'Fetch it with:\n'
          '    tool/fetch-qql.sh\n\n'
          'Or point QQL_HOME at an unpacked release bundle.';
      return;
    }

    try {
      final qql = Qql.open(found.sources, libraryPath: found.library);
      version = qql.version;
      bundle = found;
      _qql = qql;
      openError = null;
    } catch (e) {
      openError = 'Could not open ${found.library}:\n\n$e';
    }
  }

  /// Run [query], timing it.
  QueryOutcome run(String query) {
    final qql = _qql;
    if (qql == null) {
      return QueryFailed('QQL_UNAVAILABLE', openError ?? 'not open', null);
    }

    final started = Stopwatch()..start();
    try {
      final records = qql.execute(query);
      return QueryOk(records, started.elapsed);
    } on QqlException catch (e) {
      return QueryFailed(e.code, e.message, e.position);
    } catch (e) {
      return QueryFailed('QQL_INTERNAL_ERROR', '$e', null);
    }
  }

  void dispose() {
    _qql?.dispose();
    _qql = null;
  }
}
