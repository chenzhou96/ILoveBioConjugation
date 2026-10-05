import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/status_banner.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/shared/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final error = ref.watch(settingsSaveErrorProvider);
    final colors = AppColors.of(context);
    final scales = {0.9, 1.0, 1.15, 1.3, 1.5, settings.textScale}.toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('工作台设置'), toolbarHeight: 52),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '偏好保存在本机，默认单位仅用于新计算。',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
                const SizedBox(height: 18),
                if (error != null && error.isNotEmpty) ...[
                  StatusBanner(message: error, level: StatusLevel.warning),
                  const SizedBox(height: 14),
                ],
                SectionCard(
                  title: '外观',
                  padding: const EdgeInsets.all(12),
                  children: [
                    _pair(context, [
                      _setting(
                        context,
                        '主题',
                        DropdownButton<ThemeMode>(
                          key: const ValueKey('theme-mode-setting'),
                          value: settings.themeMode,
                          isExpanded: true,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('跟随系统'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('浅色'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text('深色'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) notifier.setThemeMode(value);
                          },
                        ),
                      ),
                      _setting(
                        context,
                        '文字大小',
                        DropdownButton<double>(
                          key: const ValueKey('text-scale-setting'),
                          value: settings.textScale,
                          isExpanded: true,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          isDense: true,
                          items: scales
                              .map(
                                (scale) => DropdownMenuItem(
                                  value: scale,
                                  child: Text(
                                    scale == 1
                                        ? '标准（100%）'
                                        : '${(scale * 100).round()}%',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) notifier.setTextScale(value);
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          '收起桌面侧边栏',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.sidebarCollapsed,
                        onChanged: notifier.setSidebarCollapsed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '新计算的默认单位',
                  padding: const EdgeInsets.all(12),
                  children: [
                    _pair(context, [
                      _setting(
                        context,
                        '体积单位',
                        DropdownButton<String>(
                          key: const ValueKey('default-volume-setting'),
                          value: settings.defaultVolumeUnit,
                          isExpanded: true,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          isDense: true,
                          items: AppSettings.volumeUnits
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(_unit(unit)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              notifier.setDefaultVolumeUnit(value);
                            }
                          },
                        ),
                      ),
                      _setting(
                        context,
                        '浓度单位',
                        DropdownButton<String>(
                          key: const ValueKey('default-concentration-setting'),
                          value: settings.defaultConcentrationUnit,
                          isExpanded: true,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          isDense: true,
                          items: AppSettings.concentrationUnits
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(_unit(unit)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              notifier.setDefaultConcentrationUnit(value);
                            }
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),
                const _PipettingSetting(),
                const SizedBox(height: 16),
                SectionCard(
                  title: '本地数据',
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      '历史记录、模板与偏好仅保存在当前设备。恢复默认设置会保留计算、历史和模板。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('恢复默认设置'),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('恢复默认设置？'),
                            content: const Text(
                              '主题、文字大小、侧边栏、默认单位和移液阈值将恢复初始设置。当前计算、历史记录和模板将保留。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('恢复默认'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) await notifier.resetDefaults();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pair(BuildContext context, List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth >= 540 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.2
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 20),
              Expanded(child: children[1]),
            ],
          )
        : Column(
            children: [children[0], const SizedBox(height: 14), children[1]],
          ),
  );

  Widget _setting(BuildContext context, String label, Widget dropdown) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.of(context).muted),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.of(context).border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 12),
              child: DropdownButtonHideUnderline(child: dropdown),
            ),
          ),
        ],
      );
}

String _unit(String value) => value.replaceFirst(RegExp(r'^u'), 'µ');

class _PipettingSetting extends ConsumerStatefulWidget {
  const _PipettingSetting();
  @override
  ConsumerState<_PipettingSetting> createState() => _PipettingSettingState();
}

class _PipettingSettingState extends ConsumerState<_PipettingSetting> {
  late final TextEditingController _controller;
  String? _error;
  double? _lastSetting;
  @override
  void initState() {
    super.initState();
    _lastSetting = ref.read(appSettingsProvider).minimumPipettingVolumeUl;
    _controller = TextEditingController(text: _lastSetting!.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || !value.isFinite || value < 0) {
      setState(() => _error = '请输入大于或等于 0 的有限数字');
      return;
    }
    setState(() => _error = null);
    ref.read(appSettingsProvider.notifier).setMinimumPipettingVolumeUl(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(appSettingsProvider).minimumPipettingVolumeUl;
    if (_lastSetting != value) {
      _lastSetting = value;
      _controller.text = value.toString();
    }
    final description = Text(
      '1 µL 为初始示例，请按实验室移液器设置。低于阈值时提示配制工作液；0 关闭提醒。',
      style: TextStyle(
        fontSize: 12,
        height: 1.6,
        color: AppColors.of(context).muted,
      ),
    );
    final controls = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 210,
          child: TextField(
            key: const ValueKey('minimum-pipetting-setting'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '最小可移液体积',
              suffixText: 'µL',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        OutlinedButton(onPressed: _save, child: const Text('保存阈值')),
      ],
    );
    return SectionCard(
      title: '移液可操作性',
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth > 620 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2
              ? Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 20),
                    SizedBox(width: 320, child: controls),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [description, const SizedBox(height: 12), controls],
                ),
        ),
      ],
    );
  }
}
