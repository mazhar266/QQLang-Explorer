// The home screen has to hold up on a phone and a tablet as well as a
// desktop window, so these pump it at each and check the tiles divide the
// row rather than leaving it ragged. An overflow anywhere fails the test on
// its own, which is half the point of pumping at 360 wide at all.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qqlang_explorer/main.dart';
import 'package:qqlang_explorer/saved_lists.dart';
import 'package:qqlang_explorer/sources.dart';

Future<void> _pumpAt(WidgetTester tester, double width, double height) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const QqlExplorerApp());
  await tester.pumpAndSettle();
}

double _tileWidth(WidgetTester tester) => tester
    .getSize(
      find
          .ancestor(of: find.text('Quran'), matching: find.byType(InkWell))
          .first,
    )
    .width;

void main() {
  test('columns follow the width', () {
    expect(SourcesPanel.columnsFor(360), 1);
    expect(SourcesPanel.columnsFor(519), 1);
    expect(SourcesPanel.columnsFor(520), 2);
    expect(SourcesPanel.columnsFor(839), 2);
    expect(SourcesPanel.columnsFor(840), 3);
  });

  testWidgets('phone: one column, filling the width', (tester) async {
    await _pumpAt(tester, 360, 740);

    expect(find.text('Quran'), findsOneWidget);
    // 360 less the narrow-screen padding of 14 a side.
    expect(_tileWidth(tester), closeTo(332, 1));
  });

  testWidgets('tablet: two columns', (tester) async {
    await _pumpAt(tester, 700, 1000);

    // 700 less 24 a side, less the 12 between the two.
    expect(_tileWidth(tester), closeTo(320, 1));
  });

  testWidgets('phone: a record card holds together at 360', (tester) async {
    final directory = Directory.systemTemp.createTempSync('qql_narrow');
    addTearDown(() => directory.deleteSync(recursive: true));

    final store = SavedLists(file: File('${directory.path}/lists.json'));
    final id = store.create('Study');
    store.add(id, const {
      'source': 'B',
      'collection': 'Sahih al-Bukhari',
      'chapter': 1,
      'number': 1,
      'chapter_name_en': 'Revelation',
      'chapter_name_ar': 'كتاب بدء الوحى',
      'narrator': "Narrated 'Umar bin Al-Khattab:",
      'ar': 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
      'en': 'The reward of deeds depends upon the intentions',
    }, 'B:1:1');

    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The card header carries a badge, two lines of title, an index and two
    // buttons; at 360 that is the tightest row in the app.
    await tester.pumpWidget(QqlExplorerApp(lists: store));
    await tester.tap(find.byTooltip('Saved lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sahih al-Bukhari'), findsWidgets);
    expect(find.byTooltip('Remove from Study'), findsOneWidget);
  });

  testWidgets('desktop: three columns, inside the reading width', (
    tester,
  ) async {
    await _pumpAt(tester, 1280, 800);

    // The body caps at 940, so the tiles divide 892 three ways.
    expect(_tileWidth(tester), closeTo(289.3, 1));
  });
}
