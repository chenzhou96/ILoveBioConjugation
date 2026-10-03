import 'package:ilovebioconjugation/core/display_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/templates/template_notifier.dart';

/// Saved stocks remain useful across calculations; loading always names a slot.
class TemplateLibraryScreen extends ConsumerStatefulWidget {
  const TemplateLibraryScreen({super.key});

  @override
  ConsumerState<TemplateLibraryScreen> createState() =>
      _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends ConsumerState<TemplateLibraryScreen> {
  String _query = '';
  int _targetSlot = 0;
  final _deleting = <int>{};

  String _slotName(int slot) => slot == 0 ? '主底物' : '副底物$slot';

  void _load(SubstrateTemplate template) {
    final notifier = ref.read(calculatorProvider.notifier);
    if (_targetSlot > 0 &&
        !ref.read(calculatorProvider).substrates[_targetSlot].enabled) {
      notifier.toggleSubstrateEnabled(_targetSlot);
    }
    notifier.applyTemplate(_targetSlot, template);
    context.go('/');
  }

  Future<void> _delete(SubstrateTemplate template) async {
    final id = template.id;
    if (id == null || _deleting.contains(id)) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除底物模板？'),
        content: Text('将永久删除“${template.name}”，无法撤销。已保存的计算历史不受影响。'),
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
    setState(() => _deleting.add(id));
    try {
      await ref.read(templateNotifierProvider.notifier).deleteTemplate(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('模板删除失败，请重试：$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  String _value(double? value, String unit) =>
      value == null ? '未指定' : displayInputValue(value.toString(), unit);

  Widget _templateCard(SubstrateTemplate template) {
    final theme = Theme.of(context);
    final deleting = _deleting.contains(template.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text(
                  '分子量：${_value(template.molecularWeight, template.mwUnit)}',
                ),
                Text(
                  '母液浓度：${_value(template.storageConcentration, template.storageUnit)}',
                ),
                Text(
                  '目标终浓度：${_value(template.defaultFinalConc, template.defaultFinalUnit)}',
                ),
                Text(
                  '投料比：${template.defaultReactionRatio == null ? '未指定' : displayNumber(template.defaultReactionRatio!)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: deleting ? null : () => _load(template),
                  icon: const Icon(Icons.input, size: 18),
                  label: Text('加载到${_slotName(_targetSlot)}'),
                ),
                TextButton.icon(
                  onPressed: deleting || template.id == null
                      ? null
                      : () => _delete(template),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(deleting ? '删除中…' : '删除模板'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 550;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('复用已保存的母液参数', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '在计算器的底物卡片中保存模板。加载会替换所选底物参数，并清除旧的取样体积。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '搜索模板',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                SizedBox(
                  width: compact ? constraints.maxWidth : 210,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('template-target-slot'),
                    initialValue: _targetSlot,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '加载位置'),
                    items: [
                      for (
                        var i = 0;
                        i <= CalculatorNotifier.maxSecondaries;
                        i++
                      )
                        DropdownMenuItem(value: i, child: Text(_slotName(i))),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _targetSlot = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _emptyMessage(String message) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('底物模板')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            sliver: SliverToBoxAdapter(child: _header()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: templatesAsync.when(
              data: (templates) {
                final filtered = templates
                    .where(
                      (template) =>
                          template.name.toLowerCase().contains(_query),
                    )
                    .toList();
                if (templates.isEmpty) {
                  return _emptyMessage('暂无模板。在计算器中填写底物名称和参数后，点击“模板”保存。');
                }
                if (filtered.isEmpty) {
                  return _emptyMessage('没有匹配的模板，请尝试其他名称。');
                }
                return SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _templateCard(filtered[index]),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text('模板加载失败：$error'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(templateListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
