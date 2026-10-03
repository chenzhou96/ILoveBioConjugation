// Optional real-font captures: --dart-define=CAPTURE_HISTORY=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/history/history_detail_screen.dart';

import '../fixtures/gradient_history.dart';
import '../state/fake_database.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_HISTORY');
  const output = String.fromEnvironment(
    'SCREENSHOT_DIR',
    defaultValue: 'build/qa/history-gradient',
  );
  const fontPath = String.fromEnvironment(
    'SCREENSHOT_FONT',
    defaultValue: 'C:/Windows/Fonts/msyh.ttc',
  );
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!capture) return;
    final bytes = await File(fontPath).readAsBytes();
    for (final family in ['WorkspaceCJK', 'Roboto', 'Ahem']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final entry in [
    ('desktop', const Size(1366, 900), 1.0, false),
    ('desktop-dark', const Size(1366, 900), 1.0, true),
    ('phone', const Size(390, 844), 1.0, false),
    ('enlarged', const Size(390, 1000), 2.0, false),
  ]) {
    testWidgets('capture ${entry.$1} complete gradient history', (
      tester,
    ) async {
      await binding.setSurfaceSize(entry.$2);
      tester.view.physicalSize = entry.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(() => binding.setSurfaceSize(null));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = FakeDatabase()
        ..records.add(gradientHistoryRecord(gradientHistoryInput()));
      final boundaryKey = GlobalKey();
      final base = entry.$4 ? AppTheme.dark : AppTheme.light;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: base.copyWith(
                textTheme: base.textTheme.apply(fontFamily: 'WorkspaceCJK'),
                primaryTextTheme: base.primaryTextTheme.apply(
                  fontFamily: 'WorkspaceCJK',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(entry.$3)),
                child: child!,
              ),
              home: const HistoryDetailScreen(recordId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('history-gradient-plan')),
      );
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File(
          '$output/${entry.$1}-history-gradient.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      expect(database.saveRequests, isEmpty);
    }, skip: !capture);
  }
}
