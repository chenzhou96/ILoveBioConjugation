import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/templates/template_notifier.dart';

Future<SubstrateTemplate?> showTemplatePicker(
  BuildContext context, {
  SubstrateTemplate? currentValues,
  String? currentValuesWarning,
}) {
  return showDialog<SubstrateTemplate>(
    context: context,
    builder: (context) => _TemplatePickerDialog(
      currentValues: currentValues,
      currentValuesWarning: currentValuesWarning,
    ),
  );
}

class _TemplatePickerDialog extends ConsumerStatefulWidget {
  final SubstrateTemplate? currentValues;
  final String? currentValuesWarning;
  const _TemplatePickerDialog({this.currentValues, this.currentValuesWarning});

  @override
  ConsumerState<_TemplatePickerDialog> createState() =>
      _TemplatePickerDialogState();
}

class _TemplatePickerDialogState extends ConsumerState<_TemplatePickerDialog> {
  bool _saving = false;

  Future<void> _saveCurrent() async {
    final template = widget.currentValues;
    if (template == null || template.name.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(templateNotifierProvider.notifier)
          .saveTemplate(
            name: template.name.trim(),
            molecularWeight: template.molecularWeight,
            mwUnit: template.mwUnit,
            storageConcentration: template.storageConcentration,
            storageUnit: template.storageUnit,
            defaultFinalConc: template.defaultFinalConc,
            defaultFinalUnit: template.defaultFinalUnit,
            defaultReactionRatio: template.defaultReactionRatio,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存模板: ${template.name.trim()}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('模板保存失败，请检查名称是否重复后重试：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTemplate(SubstrateTemplate template) async {
    final id = template.id;
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除底物模板？'),
        content: Text('将永久删除“${template.name}”，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await ref.read(templateNotifierProvider.notifier).deleteTemplate(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('模板删除失败，请重试：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return AlertDialog(
      title: Text(
        '底物模板',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentValuesWarning?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.of(context).warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.currentValuesWarning!,
                  style: TextStyle(color: AppColors.of(context).warningFg),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.currentValues != null) ...[
              Text(
                '将当前卡片的参数保存为模板，模板名称自动取底物名称',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.of(context).muted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '名称: ${widget.currentValues!.name.trim().isEmpty ? '(请先在卡片中填写底物名称)' : widget.currentValues!.name.trim()}',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        _saving || widget.currentValues!.name.trim().isEmpty
                        ? null
                        : _saveCurrent,
                    icon: Icon(Icons.save, size: 14),
                    label: Text('保存', style: TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                Text(
                  '已保存的模板',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  '点击加载',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: templatesAsync.when(
                data: (templates) {
                  if (templates.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无模板，请先填写底物名称后保存',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.of(context).border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [storageText, mwText]
                                          .where((s) => s.isNotEmpty)
                                          .join('  |  '),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.of(context).muted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _deleteTemplate(t),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.of(context).muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text(
                  '加载失败: $e',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).errorFg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('关闭', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
