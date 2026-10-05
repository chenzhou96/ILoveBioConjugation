import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/ui/templates/template_picker_dialog.dart';

import 'fake_database.dart';

class FailingSaveDatabase extends FakeDatabase {
  @override
  Future<int> saveTemplate(SubstrateTemplate template) async =>
      throw StateError('duplicate name');
}

void main() {
  const template = SubstrateTemplate(
    id: 1,
    name: 'Protein',
    createdAt: '2026-10-02',
    updatedAt: '2026-10-02',
  );

  Future<void> openPicker(WidgetTester tester, FakeDatabase database) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTemplatePicker(context, currentValues: template),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  testWidgets('template save errors are caught and remain visible', (
    tester,
  ) async {
    await openPicker(tester, FailingSaveDatabase());
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('模板保存失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker deletion requires an explicit confirmation', (
    tester,
  ) async {
    final database = FakeDatabase()..templates.add(template);
    await openPicker(tester, database);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(database.templates, hasLength(1));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(database.templates, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid current inputs show a warning but saved templates still load',
    (tester) async {
      final database = FakeDatabase()..templates.add(template);
      SubstrateTemplate? loaded;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    loaded = await showTemplatePicker(
                      context,
                      currentValuesWarning: '当前母液浓度无效，请先修正再保存。',
                    );
                  },
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(find.text('当前母液浓度无效，请先修正再保存。'), findsOneWidget);
      expect(find.text('保存'), findsNothing);
      await tester.tap(find.text('Protein'));
      await tester.pumpAndSettle();
      expect(loaded?.id, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
