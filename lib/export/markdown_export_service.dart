import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Save dialogs are supported by the native desktop plugin. Mobile callers can
/// still copy the same Markdown; no inaccessible app-private export is created.
abstract class MarkdownExportService {
  bool get isSupported;

  /// Returns the chosen path, or null when the user cancels the dialog.
  Future<String?> save(
    String markdown, {
    String suggestedName = 'reaction-record.md',
    bool Function()? isCurrent,
  });
}

final markdownExportServiceProvider = Provider<MarkdownExportService>(
  (ref) => NativeMarkdownExportService(),
);

class NativeMarkdownExportService implements MarkdownExportService {
  final Future<String?> Function(String suggestedName) _selectPath;
  final Future<void> Function(String path, String contents) _writeFile;
  final bool _supported;

  NativeMarkdownExportService({
    Future<String?> Function(String suggestedName)? selectPath,
    Future<void> Function(String path, String contents)? writeFile,
    bool? supported,
  }) : _selectPath = selectPath ?? _selectNativePath,
       _writeFile = writeFile ?? _writeOnPlatform,
       _supported =
           supported ??
           (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  bool get isSupported => _supported;

  @override
  Future<String?> save(
    String markdown, {
    String suggestedName = 'reaction-record.md',
    bool Function()? isCurrent,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('当前平台不支持选择保存位置，请复制 Markdown 后保存。');
    }
    if (markdown.trim().isEmpty) {
      throw ArgumentError('没有可导出的计算结果。');
    }
    if (isCurrent != null && !isCurrent()) {
      throw StateError('计算已变化，请重新计算后导出。');
    }
    final path = await _selectPath(suggestedName);
    if (path == null) return null;
    // A delayed native dialog must not export a stale or dismissed plan.
    if (isCurrent != null && !isCurrent()) {
      throw StateError('计算已变化，请重新计算后导出。');
    }
    if (!p.isAbsolute(path) || p.extension(path).toLowerCase() != '.md') {
      throw ArgumentError('请选择以 .md 结尾的文件名。');
    }
    await _writeFile(path, markdown);
    return path;
  }

  static Future<String?> _selectNativePath(String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      confirmButtonText: '导出',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    return location?.path;
  }
}

Future<void> _writeOnPlatform(String path, String contents) => Platform.isMacOS
    ? writeMarkdownMacos(path, contents)
    : writeMarkdownAtomically(path, contents);

/// A macOS save panel grants access to the selected file, not its siblings.
/// Foundation supplies a sandbox-aware replacement directory on that volume.
Future<void> writeMarkdownMacos(String path, String contents) =>
    const MethodChannel(
      'ilovebioconjugation/markdown_export',
    ).invokeMethod<void>('save', {'path': path, 'contents': contents});

/// Stage a complete UTF-8 file in the destination filesystem before replacing
/// the user-selected file. Failed writes never truncate an existing export.
Future<void> writeMarkdownAtomically(String path, String contents) async {
  final destination = File(path);
  final temporaryDirectory = await destination.parent.createTemp(
    '.reaction-export-',
  );
  try {
    final temporary = File(p.join(temporaryDirectory.path, 'record.md'));
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(destination.path);
  } finally {
    // Cleanup must not mask a write failure, or a successful file replacement.
    try {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    } on FileSystemException {
      // Only our uniquely created staging directory can remain behind.
    }
  }
}
