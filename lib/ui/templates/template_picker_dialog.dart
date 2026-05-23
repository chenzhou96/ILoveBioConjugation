import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/templates/template_notifier.dart';

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
  Future<void> _saveCurrent() async {
    final t = widget.currentValues;
    if (t == null || t.name.trim().isEmpty) return;

    await ref.read(templateNotifierProvider.notifier).saveTemplate(
      name: t.name.trim(),
      molecularWeight: t.molecularWeight,
      mwUnit: t.mwUnit,
      storageConcentration: t.storageConcentration,
      storageUnit: t.storageUnit,
      defaultFinalConc: t.defaultFinalConc,
      defaultFinalUnit: t.defaultFinalUnit,
      defaultReactionRatio: t.defaultReactionRatio,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存模板: ${t.name.trim()}'), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return AlertDialog(
      title: const Text('底物模板', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentValues != null) ...[
              const Text(
                '将当前卡片的参数保存为模板，模板名称自动取底物名称',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '名称: ${widget.currentValues!.name.trim().isEmpty ? '(请先在卡片中填写底物名称)' : widget.currentValues!.name.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: widget.currentValues!.name.trim().isEmpty ? null : _saveCurrent,
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('保存', style: TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
            Row(
              children: [
                const Text('已保存的模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Text('点击加载', style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: templatesAsync.when(
                data: (templates) {
                  if (templates.isEmpty) {
                    return const Center(
                      child: Text('暂无模板，请先填写底物名称后保存', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      final storageText = t.storageConcentration != null
                          ? '${t.storageConcentration} ${t.storageUnit}'
                          : t.storageUnit;
                      final mwText = t.molecularWeight != null
                          ? 'MW ${t.molecularWeight} ${t.mwUnit}'
                          : '';

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(context).pop(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(t.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [storageText, mwText].where((s) => s.isNotEmpty).join('  |  '),
                                      style: const TextStyle(fontSize: 9, color: AppColors.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  if (t.id != null) {
                                    await ref.read(templateNotifierProvider.notifier).deleteTemplate(t.id!);
                                  }
                                },
                                child: const Icon(Icons.close, size: 14, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('加载失败: $e', style: const TextStyle(fontSize: 12, color: AppColors.errorFg)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
