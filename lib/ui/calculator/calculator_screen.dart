import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_card.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/reaction_settings_card.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_data_table.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_metrics_row.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/status_banner.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter): () => notifier.calculate(),
        SingleActivator(LogicalKeyboardKey.keyC, control: !Platform.isMacOS, meta: Platform.isMacOS): () {
          final text = notifier.buildCopyText();
          if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
        },
        SingleActivator(LogicalKeyboardKey.keyR, control: !Platform.isMacOS, meta: Platform.isMacOS): () => notifier.reset(),
        SingleActivator(LogicalKeyboardKey.keyH, control: !Platform.isMacOS, meta: Platform.isMacOS): () => context.go('/history'),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            _buildHeader(notifier),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return isWide
                      ? _buildWideLayout(state, notifier)
                      : _buildNarrowLayout(state, notifier);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CalculatorNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '投料计算工作台',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
              SizedBox(height: 2),
              Text(
                'Reaction Calculator for BioConjugation',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: notifier.calculate,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('运行计算', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              final text = notifier.buildCopyText();
              if (text.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重置', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(CalculatorState state, CalculatorNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 660,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  ReactionSettingsCard(
                    volume: state.reactionVolume,
                    volumeUnit: state.reactionVolumeUnit,
                    ratioType: state.ratioType,
                    onVolumeChanged: notifier.setReactionVolume,
                    onVolumeUnitChanged: notifier.setReactionVolumeUnit,
                    onRatioTypeChanged: (v) => notifier.setRatioType(v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(state.substrates.length, (i) => SizedBox(
                      width: 322,
                      child: ChemicalCard(
                        index: i,
                        input: state.substrates[i],
                        isMain: i == 0,
                        onToggle: i > 0 ? () => notifier.toggleSubstrateEnabled(i) : null,
                        onFieldChanged: (field, value) => notifier.setSubstrateField(i, field, value),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusBanner(message: state.statusMessage, level: state.statusLevel),
                  const SizedBox(height: 8),
                  ResultMetricsRow(metrics: state.metrics),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ResultDataTableWidget(rows: state.rows),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(CalculatorState state, CalculatorNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReactionSettingsCard(
            volume: state.reactionVolume,
            volumeUnit: state.reactionVolumeUnit,
            ratioType: state.ratioType,
            onVolumeChanged: notifier.setReactionVolume,
            onVolumeUnitChanged: notifier.setReactionVolumeUnit,
            onRatioTypeChanged: (v) => notifier.setRatioType(v),
          ),
          const SizedBox(height: 8),
          ...List.generate(state.substrates.length, (i) => Padding(
            padding: EdgeInsets.only(bottom: i < state.substrates.length - 1 ? 8 : 0),
            child: ChemicalCard(
              index: i,
              input: state.substrates[i],
              isMain: i == 0,
              onToggle: i > 0 ? () => notifier.toggleSubstrateEnabled(i) : null,
              onFieldChanged: (field, value) => notifier.setSubstrateField(i, field, value),
            ),
          )),
          const SizedBox(height: 12),
          StatusBanner(message: state.statusMessage, level: state.statusLevel),
          const SizedBox(height: 8),
          ResultMetricsRow(metrics: state.metrics),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: ResultDataTableWidget(rows: state.rows),
          ),
        ],
      ),
    );
  }
}
