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

    this.substrateSecondary = secondarySubstrates.isNotEmpty
        ? secondarySubstrates[0]
        : null;

    _validateInputs();

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
      result.addAll(substratesSecondary);
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

    if (allSubstrates.toSet().length != allSubstrates.length) {
      throw ArgumentError('同一底物对象不能重复添加。');
    }

    for (final chem in allSubstrates) {
      chem.outputTest();
      final basisConc = chem.getBasisConc(ratioType);
      if (basisConc == null) {
        throw ArgumentError('${chem.name} 缺少用于当前投料比类型的母液浓度，无法计算。');
      }
      if (!basisConc.isFinite || basisConc <= 0) {
        throw ArgumentError('${chem.name} 的母液浓度必须大于 0。');
      }
      if (chem.reactionRatio != null && chem.reactionRatio! <= 0) {
        throw ArgumentError('${chem.name} 的反应投料比必须大于 0。');
      }
      if (chem.storageConcVolume != null && chem.storageConcVolume! < 0) {
        throw ArgumentError('${chem.name} 的母液体积不能为负数。');
      }
      final finalConc = chem.getBasisFinalConc(ratioType);
      if (finalConc == null &&
          (chem.finalConcMass != null || chem.finalConcMolar != null)) {
        throw ArgumentError('${chem.name} 的终浓度单位与投料比类型不同，请提供分子量。');
      }
      if (finalConc != null && finalConc < 0) {
        throw ArgumentError('${chem.name} 的实际反应浓度不能为负数。');
      }
    }

    if (reactionVolume != null &&
        (!reactionVolume!.isFinite || reactionVolume! <= 0)) {
      throw ArgumentError('反应体积必须大于 0。');
    }
  }

  // Relative tolerance preserves the precision of pM/pL inputs as well as
  // ordinary laboratory values. An absolute floor would hide tiny conflicts.
  static bool _safeClose(double a, double b) =>
      a.isFinite &&
      b.isFinite &&
      (a == b || (a - b).abs() <= 1e-9 * math.max(a.abs(), b.abs()));

  void _validateTotalVolume(double total, double volume) {
    if (!total.isFinite || total < 0) {
      throw ArgumentError('计算得到非法母液总体积，请检查输入。');
    }
    if (total > volume && !_safeClose(total, volume)) {
      throw ArgumentError('母液总体积超过目标反应体积，请调整浓度、投料比或反应体积。');
    }
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

    if (!d.isFinite || d <= 0 || !a.isFinite || a < 0 || !b.isFinite || b < 0) {
      throw ArgumentError('计算得到非法数值，请检查输入。');
    }
    final expectedB = s * a / d;
    if ((a == 0) != (b == 0) || !_safeClose(b, expectedB)) {
      throw ArgumentError('当前约束条件无法计算一致的结果。');
    }
    _validateTotalVolume(a, d);

    chem.storageConcVolume = a;
    chem.setBasisFinalConc(ratioType, b);
    chem.reactionRatio ??= 1.0;
    reactionVolume = d;
  }

  void _solveMultiSubstrateSystem() {
    final states = <_SolverState>[];
    for (final chem in allSubstrates) {
      final basisConc = chem.getBasisConc(ratioType)!;
      states.add(
        _SolverState(
          chem: chem,
          s: basisConc,
          a: chem.storageConcVolume,
          b: chem.getBasisFinalConc(ratioType),
          c: chem.reactionRatio,
          x: null,
        ),
      );
    }

    double? d = reactionVolume;
    final main = states[0];

    bool isKnown(double? v) => v != null;

    bool setValue(_SolverState state, String key, double value) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError('计算得到非法数值，请检查输入。');
      }
      if (key == 'a' || key == 'b' || key == 'c' || key == 's' || key == 'x') {
        if (value < 0) {
          throw ArgumentError('计算得到负数，请检查输入。');
        }
      }
      if (key == 'c' && value <= 0) {
        throw ArgumentError('反应投料比必须大于 0，请检查底物体积和浓度。');
      }
      final old = state.get(key);
      if (old == null) {
        state.set(key, value);
        return true;
      }
      if (!_safeClose(old, value)) {
        throw ArgumentError('当前约束条件无法计算一致的结果。');
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
      if (!_safeClose(d!, value)) {
        throw ArgumentError('当前约束条件无法计算一致的结果。');
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

    // A fixed point can still be underdetermined. Validate every output and
    // constraint before changing any Chemical, so partial solutions never escape.
    if (d == null ||
        states.any(
          (state) =>
              state.a == null ||
              state.b == null ||
              state.c == null ||
              state.x == null,
        )) {
      throw ArgumentError('已知数据不足，无法完成计算。');
    }
    for (final state in states) {
      final expectedB = state.s! * state.a! / d!;
      if ((state.a == 0) != (state.x == 0) ||
          (state.b == 0) != (state.x == 0) ||
          (state.x == 0) != (main.x == 0) ||
          !expectedB.isFinite ||
          !_safeClose(state.b!, expectedB) ||
          !_safeClose(state.x!, main.x! * state.c! / main.c!)) {
        throw ArgumentError('当前约束条件无法计算一致的结果。');
      }
    }
    _validateTotalVolume(states.fold(0.0, (sum, state) => sum + state.a!), d!);

    for (final state in states) {
      state.chem.storageConcVolume = state.a;
      state.chem.reactionRatio = state.c;
      state.chem.setBasisFinalConc(ratioType, state.b);
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

  _SolverState({required this.chem, this.s, this.a, this.b, this.c, this.x});

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
