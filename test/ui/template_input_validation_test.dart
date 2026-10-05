import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_card.dart';
import 'package:ilovebioconjugation/ui/templates/template_notifier.dart';

void main() {
  final saved = SubstrateTemplate(
    id: 1,
    name: 'Known template',
    createdAt: '2026-01-01',
    updatedAt: '2026-01-01',
  );
  final cases = [
    SubstrateInput(name: 'IgG', mw: 'abc'),
    SubstrateInput(name: 'IgG', mw: 'Infinity'),
    SubstrateInput(name: 'IgG', mw: '0'),
    SubstrateInput(name: 'IgG', storageConc: '-1'),
    SubstrateInput(name: 'IgG', reactionRatio: 'NaN'),
    SubstrateInput(name: 'IgG', finalConc: '-1'),
  ];
  for (final compact in [false, true]) {
    for (var index = 0; index < cases.length; index++) {
      testWidgets(
        'invalid template input $index (compact=$compact) cannot be saved but permits loading',
        (tester) async {
          tester.view.physicalSize = const Size(1366, 768);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SubstrateTemplate? loaded;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                templateListProvider.overrideWith((ref) async => [saved]),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: ChemicalCard(
                      index: 0,
                      compact: compact,
                      input: cases[index],
                      isMain: true,
                      onFieldChanged: (_, _) {},
                      onTemplateSelected: (template) => loaded = template,
                    ),
                  ),
                ),
              ),
            ),
          );
          final button = compact
              ? find.byTooltip('主底物使用 / 保存模板')
              : find.text('使用 / 保存模板');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.textContaining('当前参数无法保存'), findsOneWidget);
          expect(find.text('保存'), findsNothing);
          await tester.tap(find.text('Known template'));
          await tester.pumpAndSettle();
          expect(loaded, same(saved));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
