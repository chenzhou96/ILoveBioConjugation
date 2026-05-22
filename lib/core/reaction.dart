import 'dart:math' as math;

import 'chemical.dart';

/// Represents a chemical reaction with 1 main + up to 3 secondary substrates.
///
/// Port of chemical_config.Reaction — the fixed-point iteration solver.
class Reaction {
  static const int maxSecondaries = 3;

  final bool ratioType;
  final Chemical substrateMain;
  final List<Chemical> secondarySubstrates;
  final List<Chemical> allSubstrates;
  Chemical? substrateSecondary;
  double? reactionVolume;

  Reaction({
    required this.ratioType,
    required this.substrateMain,
    Chemical? substrateSecondary,
    List<Chemical>? substratesSecondary,
    this.reactionVolume,
  }) : secondarySubstrates = _buildSecondaryList(
         substrateSecondary,
         substratesSecondary,
       ),
       allSubstrates = [
         substrateMain,
         ..._buildSecondaryList(substrateSecondary, substratesSecondary),
       ] {
    if (secondarySubstrates.length > maxSecondaries) {
      throw ArgumentError('最多只支持 $maxSecondaries 个副底物。');
    }

    this.substrateSecondary =
        secondarySubstrates.isNotEmpty ? secondarySubstrates[0] : null;

    _validateInputs();
    _normalizeRatios();

    if (allSubstrates.length == 1) {
      _solveSingleSubstrateSystem();
    } else {
      _solveMultiSubstrateSystem();
    }

    for (final chem in allSubstrates) {
      chem.outputTest();
    }
  }

  static List<Chemical> _buildSecondaryList(
    Chemical? substrateSecondary,
    List<Chemical>? substratesSecondary,
  ) {
    final result = <Chemical>[];
    if (substratesSecondary != null) {
      result.addAll(substratesSecondary.where((c) => true));
    }
    if (substrateSecondary != null) {
      result.add(substrateSecondary);
    }
    return result;
  }

  void _validateInputs() {
    if (allSubstrates.isEmpty) {
      throw ArgumentError('至少需要一个主底物。');
    }

    for (final chem in allSubstrates) {
      final basisConc = chem.getBasisConc(ratioType);
      if (basisConc == null) {
        throw ArgumentError(
          '${chem.name} 缺少用于当前投料比类型的母液浓度，无法计算。',
        );
      }
      if (basisConc <= 0) {
        throw ArgumentError('${chem.name} 的母液浓度必须大于 0。');
      }
      if (chem.reactionRatio != null && chem.reactionRatio! <= 0) {
        throw ArgumentError('${chem.name} 的反应投料比必须大于 0。');
      }
      if (chem.storageConcVolume != null && chem.storageConcVolume! < 0) {
        throw ArgumentError('${chem.name} 的母液体积不能为负数。');
      }
      final finalConc = chem.getBasisFinalConc(ratioType);
      if (finalConc != null && finalConc < 0) {
        throw ArgumentError('${chem.name} 的实际反应浓度不能为负数。');
      }
    }

    if (reactionVolume != null && reactionVolume! <= 0) {
      throw ArgumentError('反应体积必须大于 0。');
    }
  }

  void _normalizeRatios() {
    substrateMain.reactionRatio ??= 1.0;
  }

  void _solveSingleSubstrateSystem() {
    final chem = substrateMain;
    final s = chem.getBasisConc(ratioType)!;
    double? a = chem.storageConcVolume;
    double? b = chem.getBasisFinalConc(ratioType);
    double? d = reactionVolume;

    var changed = true;
    while (changed) {
      changed = false;
      if (d == null && a != null && b != null && b != 0) {
        d = s * a / b;
        changed = true;
      }
      if (a == null && d != null && b != null) {
        a = d * b / s;
        changed = true;
      }
      if (b == null && d != null && a != null) {
        b = s * a / d;
        changed = true;
      }
    }

    if (d == null || a == null || b == null) {
      throw ArgumentError('已知数据不足，无法完成计算。');
    }

    chem.storageConcVolume = a;
    chem.setBasisFinalConc(ratioType, b);
    chem.reactionRatio ??= 1.0;
    reactionVolume = d;
  }

  void _solveMultiSubstrateSystem() {
    final states = <_SolverState>[];
    for (final chem in allSubstrates) {
      final basisConc = chem.getBasisConc(ratioType)!;
      states.add(_SolverState(
        chem: chem,
        s: basisConc,
        a: chem.storageConcVolume,
        b: chem.getBasisFinalConc(ratioType),
        c: chem.reactionRatio,
        x: null,
      ));
    }

    double? d = reactionVolume;
    final main = states[0];

    bool isKnown(double? v) => v != null;

    bool safeClose(double a, double b) {
      return (a - b).abs() <= 1e-9 * math.max(a.abs(), b.abs()) + 1e-12;
    }

    bool setValue(_SolverState state, String key, double value) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('计算得到非法数值，请检查输入。');
      }
      if (key == 'a' || key == 'b' || key == 'c' || key == 's' || key == 'x') {
        if (value < 0) {
          throw ArgumentError('计算得到负数，请检查输入。');
        }
      }
      final old = state.get(key);
      if (old == null) {
        state.set(key, value);
        return true;
      }
      if (!safeClose(old, value)) {
        throw ArgumentError('当前约束条件无法计算一致的结果!!!');
      }
      return false;
    }

    bool setGlobalD(double value) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('计算得到非法反应体积，请检查输入。');
      }
      if (value <= 0) {
        throw ArgumentError('计算得到反应体积小于等于 0，请检查输入。');
      }
      if (d == null) {
        d = value;
        return true;
      }
      if (!safeClose(d!, value)) {
        throw ArgumentError('当前约束条件无法计算一致的结果!!!');
      }
      return false;
    }

    main.c ??= 1.0;

    for (final state in states) {
      if (isKnown(state.a)) {
        setValue(state, 'x', state.s! * state.a!);
      }
      if (isKnown(state.b) && isKnown(d)) {
        setValue(state, 'x', state.b! * d!);
      }
    }

    const maxIter = 200;
    for (var iter = 0; iter < maxIter; iter++) {
      var changed = false;

      for (final state in states) {
        if (isKnown(state.a)) {
          changed |= setValue(state, 'x', state.s! * state.a!);
        }
        if (isKnown(state.x)) {
          changed |= setValue(state, 'a', state.x! / state.s!);
        }
        if (isKnown(state.b) && isKnown(d)) {
          changed |= setValue(state, 'x', state.b! * d!);
        }
        if (isKnown(state.x) && isKnown(d)) {
          changed |= setValue(state, 'b', state.x! / d!);
        }
        if (isKnown(state.b) && isKnown(d)) {
          changed |= setValue(state, 'a', d! * state.b! / state.s!);
        }
      }

      for (final state in states) {
        if (isKnown(state.x) && isKnown(state.b) && state.b! > 0) {
          changed |= setGlobalD(state.x! / state.b!);
        }
      }

      if (d == null && states.every((s) => isKnown(s.a))) {
        changed |= setGlobalD(states.fold(0.0, (sum, s) => sum + s.a!));
      }

      final cMain = main.c;
      final xMain = main.x;
      final bMain = main.b;
      final aMain = main.a;
      final sMain = main.s;

      if (isKnown(cMain)) {
        for (final state in states.skip(1)) {
          final cI = state.c;
          final sI = state.s;

          if (!isKnown(cI)) {
            if (isKnown(xMain) && isKnown(state.x) && xMain! > 0) {
              changed |= setValue(state, 'c', cMain! * state.x! / xMain);
            } else if (isKnown(bMain) && isKnown(state.b) && bMain! > 0) {
              changed |= setValue(state, 'c', cMain! * state.b! / bMain);
            } else if (isKnown(aMain) && isKnown(state.a) && aMain! > 0) {
              changed |= setValue(
                state,
                'c',
                cMain! * (sI! * state.a!) / (sMain! * aMain),
              );
            }
            continue;
          }

          final knownCI = cI!;

          if (isKnown(xMain)) {
            changed |= setValue(state, 'x', xMain! * knownCI / cMain!);
          }
          if (isKnown(bMain)) {
            changed |= setValue(state, 'b', bMain! * knownCI / cMain!);
          }
          if (isKnown(aMain)) {
            changed |= setValue(
              state,
              'a',
              aMain! * (knownCI / cMain!) * (sMain! / sI!),
            );
          }

          if (!isKnown(main.x) && isKnown(state.x) && knownCI > 0) {
            changed |= setValue(main, 'x', state.x! * cMain! / knownCI);
          }
          if (!isKnown(main.b) && isKnown(state.b) && knownCI > 0) {
            changed |= setValue(main, 'b', state.b! * cMain! / knownCI);
          }
          if (!isKnown(main.a) && isKnown(state.a) && knownCI > 0) {
            changed |= setValue(
              main,
              'a',
              state.a! * (cMain! / knownCI) * (sI! / sMain!),
            );
          }
        }
      }

      if (!changed) break;

      if (iter == maxIter - 1) {
        throw ArgumentError('计算未收敛，请检查输入条件是否充分或互相矛盾。');
      }
    }

    final mainX = main.x;
    final mainB = main.b;
    final mainA = main.a;
    final mainC = main.c ?? 1.0;
    main.c = mainC;

    for (final state in states) {
      final chem = state.chem;
      if (state.a != null && state.b != null && d != null) {
        final expectedB = state.s! * state.a! / d!;
        if (!safeClose(state.b!, expectedB)) {
          throw ArgumentError('当前约束条件无法计算一致的结果!!!');
        }
      }

      if (state != main && state.c == null) {
        if (isKnown(mainX) && isKnown(state.x) && mainX! > 0) {
          state.c = mainC * state.x! / mainX;
        } else if (isKnown(mainB) && isKnown(state.b) && mainB! > 0) {
          state.c = mainC * state.b! / mainB;
        } else if (isKnown(mainA) && isKnown(state.a) && mainA! > 0) {
          state.c =
              mainC * (state.s! * state.a!) / (main.s! * mainA);
        }
      }

      chem.storageConcVolume = state.a;
      chem.reactionRatio = state.c;
      chem.setBasisFinalConc(ratioType, state.b);
    }

    reactionVolume = d;
  }

  double get totalStockVolume {
    return allSubstrates.fold(
      0.0,
      (sum, chem) => sum + (chem.storageConcVolume ?? 0.0),
    );
  }
}

class _SolverState {
  final Chemical chem;
  final double? s;
  double? a;
  double? b;
  double? c;
  double? x;

  _SolverState({
    required this.chem,
    this.s,
    this.a,
    this.b,
    this.c,
    this.x,
  });

  double? get(String key) {
    switch (key) {
      case 's':
        return s;
      case 'a':
        return a;
      case 'b':
        return b;
      case 'c':
        return c;
      case 'x':
        return x;
      default:
        throw ArgumentError('Unknown key: $key');
    }
  }

  void set(String key, double value) {
    switch (key) {
      case 's':
        throw StateError('Cannot set s');
      case 'a':
        a = value;
        break;
      case 'b':
        b = value;
        break;
      case 'c':
        c = value;
        break;
      case 'x':
        x = value;
        break;
    }
  }
}
