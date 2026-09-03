// The Android unpack path cannot be run here, so what these pin is the half
// that is testable: that the data really is in the asset bundle, that the
// manifest filter the unpacker uses selects all of it and nothing else, and
// that the version stamp it writes is readable.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqlang_explorer/qql_install.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> dataKeys() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((k) => k.startsWith(QqlData.assetRoot))
        .toList();
  }

  test('every data file is in the asset bundle', () async {
    final keys = await dataKeys();
    expect(keys, hasLength(1106));

    // The collections the resolvers open, and both ranked engines.
    expect(keys, contains('${QqlData.assetRoot}quran/chapters/1.json'));
    expect(keys, contains('${QqlData.assetRoot}canonical/B.json'));
    expect(keys, contains('${QqlData.assetRoot}vectors/Q.qv'));
    expect(
      keys.where((k) => k.startsWith('${QqlData.assetRoot}fulltext/')),
      isNotEmpty,
    );
    expect(
      keys.where((k) => k.startsWith('${QqlData.assetRoot}hadith/')),
      isNotEmpty,
    );
  });

  test('the filter does not drag in the rest of the bundle', () async {
    final keys = await dataKeys();

    // The icon and the licence sit outside sources/ and must not be unpacked.
    expect(keys.where((k) => k.contains('app_icon')), isEmpty);
    expect(keys.where((k) => k.endsWith('LICENSE.md')), isEmpty);
  });

  test('the version stamp is readable and exact', () async {
    final version = (await rootBundle.loadString(QqlData.versionAsset)).trim();

    expect(version, isNotEmpty);
    // The stamp is compared literally to decide whether to unpack again.
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version), isTrue);
  });

  test('every unpacked path stays inside the target directory', () async {
    for (final key in await dataKeys()) {
      final relative = key.substring(QqlData.assetRoot.length);
      expect(relative, isNot(startsWith('/')));
      expect(relative, isNot(contains('..')));
    }
  });
}
