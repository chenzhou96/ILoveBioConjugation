import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjunction/data/substrate_template.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/templates/template_notifier.dart';

/// Shows a dialog for picking or saving substrate templates.
/// Returns the selected [SubstrateTemplate], or null if cancelled.
Future<SubstrateTemplate?> showTemplatePicker(
  BuildContext context, {
  SubstrateTemplate? currentValues,
}) {
  return showDialog<SubstrateTemplate>(
    context: context,
    builder: (context) => _TemplatePickerDialog(currentValues: currentValues),
  );
}

class _TemplatePickerDialog extends ConsumerStatefulWidget {
  final SubstrateTemplate? currentValues;
  const _TemplatePickerDialog({this.currentValues});

  @override
  ConsumerState<_TemplatePickerDialog> createState() => _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends ConsumerState<_TemplatePickerDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final t = widget.currentValues;
    await ref.read(templateNotifierProvider.notifier).saveTemplate(
      name: name,
      molecularWeight: t?.molecularWeight,
      mwUnit: t?.mwUnit ?? 'Da',
      storageConcentration: t?.storageConcentration,
      storageUnit: t?.storageUnit ?? 'mg/mL',
      defaultFinalConc: t?.defaultFinalConc,
      defaultFinalUnit: t?.defaultFinalUnit ?? 'mg/mL',
      defaultReactionRatio: t?.defaultReactionRatio,
    );
    _nameController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('模板已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return AlertDialog(
      title: const Text('底物模板', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Save current as template
            if (widget.currentValues != null) ...[
              const Text('保存当前为模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: '模板名称',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveCurrent,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('保存', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
            // Template list
            const Text('已保存的模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Flexible(
              child: templatesAsync.when(
                data: (templates) {
                  if (templates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('暂无模板', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      final storageText = t.storageConcentration != null
                          ? '${t.storageConcentration} ${t.storageUnit}'
                          : 'N/A';
                      final mwText = t.molecularWeight != null
                          ? '${t.molecularWeight} ${t.mwUnit}'
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(t.name, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'MW: $mwText  |  母液: $storageText',
                            style: const TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () async {
                              if (t.id != null) {
                                await ref.read(templateNotifierProvider.notifier).deleteTemplate(t.id!);
                              }
                            },
                          ),
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Text('加载失败: $e', style: const TextStyle(fontSize: 12, color: AppColors.errorFg)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
