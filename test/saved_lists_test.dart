// The store is where saved research can actually be lost, so these pin the
// things that would lose it: de-duplication, the round trip through the file,
// and what happens to a file that will not parse.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qqlang_explorer/saved_lists.dart';

const _ayah = {
  'source': 'Q',
  'collection': 'Quran',
  'surah': 2,
  'ayah': 255,
  'ar': 'ٱللَّهُ',
  'en': 'Allah',
};

const _hadith = {
  'source': 'B',
  'collection': 'Sahih al-Bukhari',
  'chapter': 1,
  'number': 1,
  'ar': 'إِنَّمَا',
  'en': 'The reward of deeds depends upon the intentions',
};

void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('qql_lists_test');
    file = File('${directory.path}/lists.json');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  SavedLists open() => SavedLists(file: file)..load();

  test('a missing file is simply no lists', () {
    final lists = open();
    expect(lists.isEmpty, isTrue);
    expect(lists.loadWarning, isNull);
  });

  test('creates, renames and deletes', () {
    final lists = open();
    final id = lists.create('  Patience  ');

    expect(lists.all.single.name, 'Patience', reason: 'the name is trimmed');

    lists.rename(id, 'Sabr');
    expect(lists.all.single.name, 'Sabr');

    lists.delete(id);
    expect(lists.isEmpty, isTrue);
  });

  test('an empty name does not make an unnameable list', () {
    final lists = open();
    lists.create('   ');
    expect(lists.all.single.name, 'Untitled');
  });

  test('the same record is not added twice', () {
    final lists = open();
    final id = lists.create('Study');

    expect(lists.add(id, _ayah, 'Q:2:255'), isTrue);
    expect(lists.add(id, _ayah, '2:255'), isFalse,
        reason: 'a different query for the same record is still that record');
    expect(lists.byId(id)!.items, hasLength(1));
  });

  test('a ranked hit is the same record as the plain one', () {
    final lists = open();
    final id = lists.create('Study');
    lists.add(id, _ayah, 'Q:2:255');

    // The same ayah arriving from a ranked query carries two extra fields.
    final ranked = {..._ayah, 'score': 12.017, 'ranked': true};
    expect(lists.add(id, ranked, 'q:?"kursi"'), isFalse);
    expect(lists.byId(id)!.contains(ranked), isTrue);
  });

  test('a record can be in several lists at once', () {
    final lists = open();
    final study = lists.create('Study');
    final khutbah = lists.create('Khutbah');

    lists.add(study, _ayah, 'Q:2:255');
    lists.add(khutbah, _ayah, 'Q:2:255');

    expect(
      lists.containing(_ayah).map((l) => l.name),
      containsAll(<String>['Study', 'Khutbah']),
    );
    expect(lists.containing(_hadith), isEmpty);
  });

  test('toggle adds then removes', () {
    final lists = open();
    final id = lists.create('Study');

    lists.toggle(id, _ayah, 'Q:2:255');
    expect(lists.byId(id)!.contains(_ayah), isTrue);

    lists.toggle(id, _ayah, 'Q:2:255');
    expect(lists.byId(id)!.contains(_ayah), isFalse);
    expect(lists.itemCount, 0);
  });

  test('survives a restart, provenance included', () {
    final before = open();
    final id = before.create('Study');
    before.add(id, _ayah, 'q:?"kursi"~5');
    before.add(id, _hadith, 'B:1:1');

    final after = open();
    final list = after.all.single;
    expect(list.name, 'Study');
    expect(list.items, hasLength(2));
    expect(list.items.first.query, 'q:?"kursi"~5');
    expect(list.items.first.record['ar'], 'ٱللَّهُ');
    expect(list.contains(_hadith), isTrue,
        reason: 'membership is rebuilt on load, not just on add');
  });

  test('an unreadable file is kept, not written over', () {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{ this is not json');

    final lists = open();

    expect(lists.isEmpty, isTrue);
    expect(lists.loadWarning, isNotNull);

    final keptAside = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('unreadable'));
    expect(keptAside, hasLength(1));
    expect(keptAside.single.readAsStringSync(), '{ this is not json');
  });

  test('one bad entry costs one entry, not the file', () {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'version': 1,
        'lists': [
          {
            'id': 'l1',
            'name': 'Study',
            'created': DateTime.now().toIso8601String(),
            'items': [
              {'record': _ayah, 'query': 'Q:2:255', 'added': '2026-09-03'},
              {'nonsense': true},
            ],
          },
          {'no': 'id'},
        ],
      }),
    );

    final lists = open();
    expect(lists.loadWarning, isNull);
    expect(lists.all, hasLength(1));
    expect(lists.all.single.items, hasLength(1));
  });

  test('notifies listeners so the UI follows the store', () {
    final lists = open();
    var notifications = 0;
    lists.addListener(() => notifications++);

    final id = lists.create('Study');
    lists.add(id, _ayah, 'Q:2:255');
    lists.removeItem(id, lists.all.single.items.single.key);

    expect(notifications, 3);
  });
}
