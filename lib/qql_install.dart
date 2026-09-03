// Getting the QQL data somewhere the resolvers can read it.
//
// The data ships as Flutter assets. On a desktop build those are ordinary
// files inside the app bundle, so the Rust side can open them where they lie
// and nothing needs doing. Inside an APK they are entries in a zip, which
// std::fs cannot open, so they are written out once to the app's own storage.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Files unpacked so far, and files in total.
typedef UnpackProgress = void Function(int done, int total);

/// Where the JSON data is, and how it gets there.
class QqlData {
  /// The prefix every data asset shares.
  static const assetRoot = 'third_party/qql/sources/';

  /// Records which release the assets came from, so an upgrade re-unpacks.
  static const versionAsset = 'third_party/qql/VERSION';

  /// Platforms whose assets are not files on disk.
  static bool get needsUnpacking => Platform.isAndroid || Platform.isIOS;

  /// The data directory, unpacking first if the platform needs it.
  ///
  /// Null when the data is nowhere to be found, which on desktop means the
  /// app was built without it.
  static Future<String?> locate({UnpackProgress? onProgress}) async {
    final override = _fromEnvironment();
    if (override != null) return override;

    return needsUnpacking ? await _unpack(onProgress) : _onDisk();
  }

  /// `QQL_HOME/sources`, for pointing at an unpacked release bundle.
  static String? _fromEnvironment() {
    final home = Platform.environment['QQL_HOME'];
    if (home == null || home.isEmpty) return null;

    final path = '$home${Platform.pathSeparator}sources';
    return Directory(path).existsSync() ? path : null;
  }

  /// The assets as the desktop bundle lays them out, then the checkout —
  /// which is what `flutter run` and the tests read.
  static String? _onDisk() {
    final beside = File(Platform.resolvedExecutable).parent.path;

    for (final candidate in [
      '$beside/data/flutter_assets/$assetRoot',
      'third_party/qql/sources',
    ]) {
      if (Directory(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Write every data asset out to the app's storage, once per release.
  static Future<String> _unpack(UnpackProgress? onProgress) async {
    final support = await getApplicationSupportDirectory();
    final target = Directory('${support.path}/qql-sources');
    final stamp = File('${target.path}/.version');

    final version = (await rootBundle.loadString(versionAsset)).trim();
    if (stamp.existsSync() && stamp.readAsStringSync().trim() == version) {
      return target.path;
    }

    // Start clean. Overlaying a new release on an old one would leave data
    // files behind that no longer belong to it, and the stamp is written
    // last so an interrupted unpack is retried rather than trusted.
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys =
        manifest.listAssets().where((k) => k.startsWith(assetRoot)).toList()
          ..sort();

    var done = 0;
    for (final key in keys) {
      final file = File('${target.path}/${key.substring(assetRoot.length)}');
      file.parent.createSync(recursive: true);

      final bytes = await rootBundle.load(key);
      file.writeAsBytesSync(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      // The bundle caches what it loads. Without this the whole 120 MB is
      // held in memory by the time the last file is written.
      rootBundle.evict(key);

      onProgress?.call(++done, keys.length);
    }

    stamp.writeAsStringSync(version);
    return target.path;
  }
}

/// Where the shared library is.
class QqlLibrary {
  /// The path to hand [DynamicLibrary.open], or null if there is none.
  static String? locate() {
    // Packaged per ABI in the APK and already on the loader's path, so it is
    // named rather than pointed at.
    if (Platform.isAndroid) return 'libqql.so';

    final name = Platform.isMacOS
        ? 'libqql.dylib'
        : Platform.isWindows
        ? 'qql.dll'
        : 'libqql.so';

    final beside = File(Platform.resolvedExecutable).parent.path;
    final home = Platform.environment['QQL_HOME'];

    for (final directory in [
      if (home != null && home.isNotEmpty) home,
      '$beside${Platform.pathSeparator}qql',
      'third_party/qql',
    ]) {
      final path = [
        directory,
        'lib',
        name,
      ].join(Platform.pathSeparator);
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}
