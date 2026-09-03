// The record layout is where the fiddly logic lives — records have no fixed
// shape, so what these pin is that each source's fields land in the right
// place and that nothing is silently dropped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqlang_explorer/main.dart';
import 'package:qqlang_explorer/result_card.dart';

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
}
