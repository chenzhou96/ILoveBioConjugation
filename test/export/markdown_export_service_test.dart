import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ilovebioconjugation/export/markdown_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'macOS uses the selected-file native writer with exact Unicode content',
    () async {
      const channel = MethodChannel('ilovebioconjugation/markdown_export');
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await writeMarkdownMacos('/selected/方案.md', '蛋白 1 µM 🧪');
      expect(received!.method, 'save');
      expect(received!.arguments, {
        'path': '/selected/方案.md',
        'contents': '蛋白 1 µM 🧪',
      });
    },
  );
  test('cancel never writes a file', () async {
    var writes = 0;
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (_) async => null,
      writeFile: (_, _) async => writes++,
    );
    expect(await service.save('方案'), isNull);
    expect(writes, 0);
  });

  test('delayed selection rejects newer inputs before writing', () async {
    final choice = Completer<String?>();
    var current = true;
    var writes = 0;
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (_) => choice.future,
      writeFile: (_, _) async => writes++,
    );
    final export = service.save('旧方案', isCurrent: () => current);
    current = false;
    choice.complete('/unused/record.md');
    await expectLater(export, throwsStateError);
    expect(writes, 0);
  });

  test('already stale results do not even open a dialog', () async {
    var opened = false;
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (_) async {
        opened = true;
        return '/unused/record.md';
      },
    );
    await expectLater(
      service.save('旧方案', isCurrent: () => false),
      throwsStateError,
    );
    expect(opened, isFalse);
  });

  test('unsupported platforms never silently write a private file', () async {
    final service = NativeMarkdownExportService(supported: false);
    expect(service.isSupported, isFalse);
    await expectLater(service.save('方案'), throwsUnsupportedError);
  });

  test('empty content and non-Markdown destinations are rejected', () async {
    var writes = 0;
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (_) async => '/unused/record.txt',
      writeFile: (_, _) async => writes++,
    );
    await expectLater(service.save('  '), throwsArgumentError);
    await expectLater(service.save('方案'), throwsArgumentError);
    expect(writes, 0);
  });

  test('chosen filename and exact serialized content are retained', () async {
    final writes = <(String, String)>[];
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (name) async {
        expect(name, 'gradient-plan.md');
        return '/selected/梯度.MD';
      },
      writeFile: (path, contents) async => writes.add((path, contents)),
    );
    const markdown = '| 浓度 | 取样量 |\n| --- | --- |\n| 2 µM | 1 µL |\n';
    expect(
      await service.save(markdown, suggestedName: 'gradient-plan.md'),
      '/selected/梯度.MD',
    );
    expect(writes, [('/selected/梯度.MD', markdown)]);
  });

  test(
    'a relative path cannot write into the application working directory',
    () async {
      var writes = 0;
      final service = NativeMarkdownExportService(
        supported: true,
        selectPath: (_) async => 'unselected.md',
        writeFile: (_, _) async => writes++,
      );
      await expectLater(service.save('计划配方'), throwsArgumentError);
      expect(writes, 0);
    },
  );

  test('filesystem errors reach the caller, without success results', () async {
    final service = NativeMarkdownExportService(
      supported: true,
      selectPath: (_) async => '/selected/record.md',
      writeFile: (_, _) async => throw const FileSystemException('read-only'),
    );
    await expectLater(service.save('方案'), throwsA(isA<FileSystemException>()));
  });

  test(
    'real UTF-8 file replacement preserves Unicode and cleans staging',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'md-export-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/方案.md');
      await file.writeAsString('previous');
      const contents = '## 计划配方\n蛋白浓度 6.67 µM / 1 mg/mL 🧪\n';
      await writeMarkdownAtomically(file.path, contents);
      expect(await file.readAsString(), contents);
      expect(await directory.list().length, 1);
    },
  );

  test('failed replacement leaves unrelated existing file untouched', () async {
    final directory = await Directory.systemTemp.createTemp('md-export-test-');
    addTearDown(() => directory.delete(recursive: true));
    final existing = File('${directory.path}/existing.md');
    await existing.writeAsString('keep');
    final invalidTarget = Directory('${directory.path}/directory.md');
    await invalidTarget.create();
    await expectLater(
      writeMarkdownAtomically(invalidTarget.path, 'new'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await existing.readAsString(), 'keep');
    expect(await directory.list().length, 2);
  });
}
