// The record layout is where the fiddly logic lives — records have no fixed
// shape, so what these pin is that each source's fields land in the right
// place and that nothing is silently dropped.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqlang_explorer/about.dart';
import 'package:qqlang_explorer/main.dart';
import 'package:qqlang_explorer/result_card.dart';
import 'package:qqlang_explorer/saved_lists.dart';

void main() {
  group('RecordView', () {
    test('reads a Quran record', () {
      final view = RecordView(const {
        'source': 'Q',
        'collection': 'Quran',
        'surah': 2,
        'ayah': 255,
        'surah_name_en': 'Al-Baqarah',
        'surah_name_ar': 'البقرة',
        'ar': 'ٱللَّهُ',
        'en': 'Allah',
      });

      expect(view.reference, '2:255');
      expect(view.titleEn, 'Al-Baqarah');
      expect(view.titleAr, 'البقرة');
      expect(view.score, isNull);
      expect(view.extras, isEmpty);
    });

    test('reads a hadith record, narrator apart from the text', () {
      final view = RecordView(const {
        'source': 'B',
        'collection': 'Sahih al-Bukhari',
        'chapter': 1,
        'number': 1,
        'chapter_name_en': 'Revelation',
        'narrator': "Narrated 'Umar bin Al-Khattab:",
        'ar': 'إِنَّمَا',
        'en': 'The reward of deeds depends upon the intentions',
      });

      expect(view.reference, '1:1');
      expect(view.titleEn, 'Revelation');
      expect(view.narrator, "Narrated 'Umar bin Al-Khattab:");
      expect(view.extras, isEmpty);
    });

    test('keeps fields the layout does not name', () {
      final view = RecordView(const {
        'source': 'HM',
        'collection': 'Hisnul Muslim',
        'chapter': 1,
        'number': 1,
        'chapter_title': 'supplications for when you wake up',
        'note': '(Alhamdu lillahil-lathee ahyana...)',
        'audio': 'http://www.hisnmuslim.com/audio/ar/1.mp3',
        'repeat': 1,
        'ar': 'الْحَمْدُ',
        'en': 'All praise is for Allah',
      });

      expect(view.titleEn, 'supplications for when you wake up');
      expect(view.note, startsWith('(Alhamdu'));
      // Not laid out explicitly, so they must survive as chips.
      expect(view.extras.keys, containsAll(<String>['audio', 'repeat']));
    });

    test('carries the score on a ranked hit', () {
      final view = RecordView(const {
        'source': 'Q',
        'collection': 'Quran',
        'surah': 1,
        'ayah': 3,
        'score': 12.017,
        'ranked': true,
        'ar': 'ٱلرَّحْمَٰنِ',
        'en': 'The Entirely Merciful',
      });

      expect(view.score, closeTo(12.017, 0.0001));
      // `score` and `ranked` are shown by the header, not as chips.
      expect(view.extras, isEmpty);
    });

    test('falls back when a record carries no numbering it can cite', () {
      final view = RecordView(const {
        'source': 'X',
        'collection': 'Custom',
        'ar': 'نص',
        'en': 'text',
      });

      expect(view.reference, '');
      expect(view.titleEn, isNull);
      expect(view.asPlainText, contains('Custom'));
    });
  });

  testWidgets('the app offers a query field and a search button', (
    tester,
  ) async {
    await tester.pumpWidget(const QqlExplorerApp());

    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Search'), findsOneWidget);
  });

  test('the version shown is the version pubspec declares', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(declared, isNotNull, reason: 'pubspec.yaml has no version');
    // pubspec carries a build number after a +; the app shows the name only.
    expect(declared!.group(1)!.split('+').first, kAppVersion);
  });

  testWidgets('the about screen says what it is and who made it', (
    tester,
  ) async {
    await tester.pumpWidget(const QqlExplorerApp());

    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();

    expect(find.text('QQL Explorer'), findsWidgets);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(find.text('Initiated by'), findsOneWidget);
    expect(find.text('Mazhar Ahmed'), findsOneWidget);
    expect(find.text('www.mazhar.fi'), findsOneWidget);
    expect(find.text('BA in Islamic Studies from IOU'), findsOneWidget);
    expect(
      find.text('Dawra-e-Hadith from Qawmi Madrasa, Bangladesh'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.text('Initiated by'), findsNothing);
  });

  testWidgets('the home screen lists the sources, and a code starts a query', (
    tester,
  ) async {
    await tester.pumpWidget(const QqlExplorerApp());
    // The runtime opens asynchronously now, so the body starts as the
    // opening state and the sources arrive a frame later.
    await tester.pumpAndSettle();

    // Every collection is on the page, not just the ones that happen to fit
    // on screen: the tiles are one Wrap, so they all build.
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Sahih al-Bukhari'), findsOneWidget);
    expect(find.text('Hisnul Muslim'), findsOneWidget);
    expect(find.text('Surah 1–114  ·  ::1–6236'), findsOneWidget);
    expect(find.text('kitab 1–97  ·  ::1–7563'), findsOneWidget);
    // The six with no citation numbering show no :: range.
    expect(find.text('chapter 1–19'), findsOneWidget);

    await tester.tap(find.text('Sahih al-Bukhari'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'B:');
  });

  testWidgets('a saved list can be opened, read and pruned', (tester) async {
    // A temporary file, so a test run cannot touch real saved research.
    final directory = Directory.systemTemp.createTempSync('qql_ui_test');
    addTearDown(() => directory.deleteSync(recursive: true));

    final store = SavedLists(file: File('${directory.path}/lists.json'));
    final id = store.create('Study');
    store.add(id, const {
      'source': 'Q',
      'collection': 'Quran',
      'surah': 2,
      'ayah': 255,
      'ar': 'ٱللَّهُ',
      'en': 'Allah, there is no deity except Him',
    }, 'q:?"kursi"~5');

    await tester.pumpWidget(QqlExplorerApp(lists: store));

    await tester.tap(find.byTooltip('Saved lists'));
    await tester.pumpAndSettle();
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();

    // The record renders, with the query that found it kept alongside.
    // The query is deliberately not one of the example chips, which carry
    // the same text and would match too.
    expect(find.text('Allah, there is no deity except Him'), findsOneWidget);
    expect(find.text('q:?"kursi"~5'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from Study'));
    await tester.pumpAndSettle();

    expect(store.itemCount, 0);
    expect(find.textContaining('Nothing saved'), findsOneWidget);
  });
}
