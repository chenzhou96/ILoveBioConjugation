import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/export/markdown_export_service.dart';

/// Both clipboard and file output consume the same immutable Markdown snapshot.
class RecordActions extends ConsumerStatefulWidget {
  final Object? resultToken;
  final String Function() buildMarkdown;
  final String suggestedName;
  final String label;
  const RecordActions({
    super.key,
    required this.resultToken,
    required this.buildMarkdown,
    this.suggestedName = 'reaction-record.md',
    this.label = '实验记录',
  });
  @override
  ConsumerState<RecordActions> createState() => _RecordActionsState();
}

class _RecordActionsState extends ConsumerState<RecordActions> {
  bool _saving = false;
  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _act(String action) async {
    if (_saving || widget.resultToken == null) return;
    final token = widget.resultToken;
    final markdown = widget.buildMarkdown();
    if (markdown.isEmpty) return;
    if (action == 'copy') {
      try {
        await Clipboard.setData(ClipboardData(text: markdown));
        _notice('完整 Markdown 实验记录已复制');
      } catch (_) {
        _notice('无法访问剪贴板，请稍后重试');
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await ref
          .read(markdownExportServiceProvider)
          .save(
            markdown,
            suggestedName: widget.suggestedName,
            isCurrent: () => mounted && identical(widget.resultToken, token),
          );
      if (path != null) _notice('Markdown 文件已导出：$path');
    } catch (error) {
      _notice('导出未完成：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(markdownExportServiceProvider).isSupported;
    return PopupMenuButton<String>(
      key: const ValueKey('record-menu-button'),
      enabled: !_saving && widget.resultToken != null,
      tooltip: _saving ? '正在导出，请稍候' : '复制或导出完整实验记录',
      onSelected: _act,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'copy', child: Text('复制完整 Markdown')),
        PopupMenuItem(
          value: 'export',
          enabled: supported,
          child: Text(supported ? '导出 .md 文件' : '此平台请复制 Markdown 保存'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Opacity(
          opacity: widget.resultToken == null ? .45 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saving)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 7),
              Text(
                _saving ? '导出中' : widget.label,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}
