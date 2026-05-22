import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/chemical_card.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/reaction_settings_card.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/result_data_table.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/result_metrics_row.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/status_banner.dart';

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
            // Header
            _buildHeader(notifier),
            const SizedBox(height: 8),
            // Body: responsive layout
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
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '投料计算工作台',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            Text(
              'Reaction Calculator for ChemAnal',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: notifier.calculate,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('运行计算', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: () {
            final text = notifier.buildCopyText();
            if (text.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: text));
            }
          },
          icon: const Icon(Icons.copy, size: 14),
          label: const Text('复制结果', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: notifier.reset,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('重置', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(CalculatorState state, CalculatorNotifier notifier) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel: input cards
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 6),
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
                const SizedBox(height: 6),
                // Main + secondary cards in 2-column grid
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < state.substrates.length; i++)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width / 2 - 50) / 2,
                        child: ChemicalCard(
                          index: i,
                          input: state.substrates[i],
                          isMain: i == 0,
                          onToggle: i > 0 ? () => notifier.toggleSubstrateEnabled(i) : null,
                          onFieldChanged: (field, value) =>
                              notifier.setSubstrateField(i, field, value),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Right panel: results
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner(
                message: state.statusMessage,
                level: state.statusLevel,
              ),
              const SizedBox(height: 6),
              ResultMetricsRow(metrics: state.metrics),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ResultDataTableWidget(rows: state.rows),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage,
                style: TextStyle(
                  fontSize: 11,
                  color: state.errorMessage == '就绪'
                      ? AppColors.successFg
                      : AppColors.errorFg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(CalculatorState state, CalculatorNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
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
          const SizedBox(height: 6),
          for (var i = 0; i < state.substrates.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChemicalCard(
                index: i,
                input: state.substrates[i],
                isMain: i == 0,
                onToggle: i > 0 ? () => notifier.toggleSubstrateEnabled(i) : null,
                onFieldChanged: (field, value) =>
                    notifier.setSubstrateField(i, field, value),
              ),
            ),
          const SizedBox(height: 8),
          StatusBanner(message: state.statusMessage, level: state.statusLevel),
          const SizedBox(height: 6),
          ResultMetricsRow(metrics: state.metrics),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(8),
              child: ResultDataTableWidget(rows: state.rows),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.errorMessage,
            style: TextStyle(
              fontSize: 11,
              color: state.errorMessage == '就绪'
                  ? AppColors.successFg
                  : AppColors.errorFg,
            ),
          ),
        ],
      ),
    );
  }
}

