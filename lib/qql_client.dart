// Running queries against the QQL runtime this app ships.
//
// Where that runtime is differs by platform, and all of that lives in
// qql_install.dart. What is left here is the context itself.

import 'qql_binding.dart';
import 'qql_install.dart';

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

  /// Why the runtime could not be opened, if it could not be.
  String? openError;

  /// The version the library reports for itself, once open.
  String? version;

  /// The data directory in use, once open.
  String? dataDirectory;

  bool get isOpen => _qql != null;

  /// Open the context, unpacking the data first on platforms that need it.
  ///
  /// [onProgress] reports that unpacking, which happens once per release on
  /// Android and never on desktop. Safe to call more than once; only the
  /// first opens.
  Future<void> open({UnpackProgress? onProgress}) async {
    if (_qql != null) return;

    final library = QqlLibrary.locate();
    if (library == null) {
      openError =
          'No QQL library for this platform.\n\n'
          'On desktop it is fetched by tool/fetch-qql.sh into '
          'third_party/qql/lib and installed beside the executable.';
      return;
    }

    final String? data;
    try {
      data = await QqlData.locate(onProgress: onProgress);
    } catch (e) {
      openError = 'Could not unpack the QQL data:\n\n$e';
      return;
    }

    if (data == null) {
      openError =
          'No QQL data found.\n\n'
          'Run tool/fetch-qql.sh, or point QQL_HOME at an unpacked release '
          'bundle.';
      return;
    }

    try {
      final qql = Qql.open(data, libraryPath: library);
      version = qql.version;
      dataDirectory = data;
      _qql = qql;
      openError = null;
    } catch (e) {
      openError = 'Could not open $library:\n\n$e';
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
