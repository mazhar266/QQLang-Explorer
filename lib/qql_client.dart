// Locating the QQ Lang build, and running queries against it.
//
// The native library and the JSON data both live in the QQ Lang checkout
// rather than in this app, so the one thing worth being careful about is
// where that checkout is and what to say when it is not there.

import 'dart:io';

import 'qql_binding.dart';

/// Paths into the QQ Lang checkout.
///
/// `QQL_HOME` overrides the location; otherwise the sibling checkout under
/// `~/Projects` is assumed, which is where it lives during development.
class QqlPaths {
  static String get home =>
      Platform.environment['QQL_HOME'] ?? '$_userHome/Projects/QQ Lang';

  /// The release build of the C ABI library.
  static String get library {
    if (Platform.isWindows) return '$home\\target\\release\\qql.dll';
    if (Platform.isMacOS) return '$home/target/release/libqql.dylib';
    return '$home/target/release/libqql.so';
  }

  /// The JSON data directory the context reads.
  static String get sources => '$home${Platform.pathSeparator}sources';

  static String get _userHome =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
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

  /// Library version, once open.
  String? version;

  bool get isOpen => _qql != null;

  /// Open the context. Safe to call more than once; only the first opens.
  void open() {
    if (_qql != null) return;

    final library = File(QqlPaths.library);
    if (!library.existsSync()) {
      openError =
          'No QQL library at ${QqlPaths.library}\n\n'
          'Build it from the QQ Lang checkout:\n'
          '    cargo build --release --features vector,fulltext\n\n'
          'Or point QQL_HOME at a different checkout.';
      return;
    }
    if (!Directory(QqlPaths.sources).existsSync()) {
      openError = 'No data directory at ${QqlPaths.sources}';
      return;
    }

    try {
      final qql = Qql.open(QqlPaths.sources, libraryPath: QqlPaths.library);
      version = qql.version;
      _qql = qql;
      openError = null;
    } catch (e) {
      openError = 'Could not open the QQL library:\n\n$e';
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
