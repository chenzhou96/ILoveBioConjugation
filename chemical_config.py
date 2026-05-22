import math
from typing import List, Optional


class UnitConverter:
    """用于转换单位"""

    MASS_UNITS = {
        'g': 3,
        'kg': 6,
        'mg': 0,
        'ug': -3,
        'ng': -9,
        'pg': -12,
    }

    VOLUME_UNITS = {
        'L': 3,
        'mL': 0,
        'uL': -3,
        'nL': -6,
        'pL': -9,
    }

    MOLAR_UNITS = {
        'mol': 6,
        'mmol': 3,
        'umol': 0,
        'nmol': -3,
        'pmol': -6,
    }

    MOLECULAR_UNITS = {
        'Da': 0,
        'kDa': 3,
    }

    MOLAR_CONC_UNITS = {
        'M': 3,
        'mM': 0,
        'uM': -3,
        'nM': -6,
        'pM': -9,
    }

    MASS_CONC_UNITS = {
        'g/mL': 3,
        'mg/mL': 0,
        'ug/mL': -3,
        'ng/mL': -6,
        'pg/mL': -9,
    }


class Chemical:
    """表示单个化学物质"""

    def __init__(
        self,
        unit_coefficient: int,
        storage_conc_molar: float = None,
        storage_conc_mass: float = None,
        name: str = 'Untitled',
        molecular_weight: float = None,
        storage_conc_volume: float = None,
        final_conc_molar: float = None,
        final_conc_mass: float = None,
        reaction_ratio: float = None,
    ):
        if storage_conc_molar is not None and storage_conc_mass is not None:
            raise ValueError("只能提供母液浓度(摩尔浓度或质量浓度)中的一个。")
        if storage_conc_molar is None and storage_conc_mass is None:
            raise ValueError("必须提供母液浓度(摩尔浓度或质量浓度)中的一个。")
        if final_conc_molar is not None and final_conc_mass is not None:
            raise ValueError("只能提供实际反应浓度(摩尔浓度或质量浓度)中的一个。")

        self.unit_coefficient = unit_coefficient
        self.storage_conc_molar = storage_conc_molar
        self.storage_conc_mass = storage_conc_mass
        self.name = name
        self.molecular_weight = molecular_weight
        self.storage_conc_volume = storage_conc_volume
        self.final_conc_molar = final_conc_molar
        self.final_conc_mass = final_conc_mass
        self.reaction_ratio = reaction_ratio

        if molecular_weight is not None:
            if self.storage_conc_molar is None and self.storage_conc_mass is not None:
                self.storage_conc_molar = self.conc_mass2molar(self.storage_conc_mass)
            elif self.storage_conc_mass is None and self.storage_conc_molar is not None:
                self.storage_conc_mass = self.conc_molar2mass(self.storage_conc_molar)

            if self.final_conc_molar is None and self.final_conc_mass is not None:
                self.final_conc_molar = self.conc_mass2molar(self.final_conc_mass)
            elif self.final_conc_mass is None and self.final_conc_molar is not None:
                self.final_conc_mass = self.conc_molar2mass(self.final_conc_molar)

    def conc_mass2molar(self, conc: float) -> float:
        return (conc / self.molecular_weight) * 1000

    def conc_molar2mass(self, conc: float) -> float:
        return (conc * self.molecular_weight) / 1000

    def output_test(self):
        if self.molecular_weight is not None:
            if self.final_conc_mass is not None and self.final_conc_molar is None:
                self.final_conc_molar = self.conc_mass2molar(self.final_conc_mass)
            if self.final_conc_molar is not None and self.final_conc_mass is None:
                self.final_conc_mass = self.conc_molar2mass(self.final_conc_molar)
            if self.storage_conc_mass is not None and self.storage_conc_molar is None:
                self.storage_conc_molar = self.conc_mass2molar(self.storage_conc_mass)
            if self.storage_conc_molar is not None and self.storage_conc_mass is None:
                self.storage_conc_mass = self.conc_molar2mass(self.storage_conc_molar)

    def get_basis_conc(self, ration_type: bool) -> Optional[float]:
        return self.storage_conc_molar if ration_type else self.storage_conc_mass

    def get_basis_final_conc(self, ration_type: bool) -> Optional[float]:
        return self.final_conc_molar if ration_type else self.final_conc_mass

    def set_basis_final_conc(self, ration_type: bool, value: Optional[float]):
        if ration_type:
            self.final_conc_molar = value
        else:
            self.final_conc_mass = value


class Reaction:
    """表示一个化学反应，兼容 1 个主底物 + 最多 3 个副底物"""

    MAX_SECONDARIES = 3

    def __init__(
        self,
        ration_type: bool,
        substrate_main: Chemical,
        substrate_secondary: Chemical = None,
        substrates_secondary: List[Chemical] = None,
        reaction_volume: float = None,
    ):
        self.ration_type = ration_type
        self.substrate_main = substrate_main
        self.reaction_volume = reaction_volume
        self.status = None

        secondary_list: List[Chemical] = []
        if substrates_secondary:
            secondary_list.extend([chem for chem in substrates_secondary if chem is not None])
        if substrate_secondary is not None:
            secondary_list.append(substrate_secondary)

        if len(secondary_list) > self.MAX_SECONDARIES:
            raise ValueError(f"最多只支持 {self.MAX_SECONDARIES} 个副底物。")

        self.secondary_substrates = secondary_list
        self.substrate_secondary = self.secondary_substrates[0] if self.secondary_substrates else None
        self.all_substrates = [self.substrate_main] + self.secondary_substrates

        self._validate_inputs()
        self._normalize_ratios()
        if len(self.all_substrates) == 1:
            self._solve_single_substrate_system()
        else:
            self._solve_multi_substrate_system()

        for chem in self.all_substrates:
            chem.output_test()

    def _validate_inputs(self):
        if not self.all_substrates:
            raise ValueError("至少需要一个主底物。")

        for chem in self.all_substrates:
            basis_conc = chem.get_basis_conc(self.ration_type)
            if basis_conc is None:
                raise ValueError(f"{chem.name} 缺少用于当前投料比类型的母液浓度，无法计算。")
            if basis_conc <= 0:
                raise ValueError(f"{chem.name} 的母液浓度必须大于 0。")
            if chem.reaction_ratio is not None and chem.reaction_ratio <= 0:
                raise ValueError(f"{chem.name} 的反应投料比必须大于 0。")
            if chem.storage_conc_volume is not None and chem.storage_conc_volume < 0:
                raise ValueError(f"{chem.name} 的母液体积不能为负数。")
            final_conc = chem.get_basis_final_conc(self.ration_type)
            if final_conc is not None and final_conc < 0:
                raise ValueError(f"{chem.name} 的实际反应浓度不能为负数。")

        if self.reaction_volume is not None and self.reaction_volume <= 0:
            raise ValueError("反应体积必须大于 0。")

    def _normalize_ratios(self):
        if self.substrate_main.reaction_ratio is None:
            self.substrate_main.reaction_ratio = 1.0

    def _solve_single_substrate_system(self):
        chem = self.substrate_main
        s = chem.get_basis_conc(self.ration_type)
        a = chem.storage_conc_volume
        b = chem.get_basis_final_conc(self.ration_type)
        d = self.reaction_volume

        changed = True
        while changed:
            changed = False
            if d is None and a is not None and b not in (None, 0):
                d = s * a / b
                changed = True
            if a is None and d is not None and b is not None:
                a = d * b / s
                changed = True
            if b is None and d is not None and a is not None:
                b = s * a / d
                changed = True

        if d is None or a is None or b is None:
            raise ValueError("已知数据不足，无法完成计算。")

        chem.storage_conc_volume = a
        chem.set_basis_final_conc(self.ration_type, b)
        chem.reaction_ratio = chem.reaction_ratio or 1.0
        self.reaction_volume = d

    def _solve_multi_substrate_system(self):
        states = []
        for chem in self.all_substrates:
            basis_conc = chem.get_basis_conc(self.ration_type)
            state = {
                'chem': chem,
                's': basis_conc,
                'a': chem.storage_conc_volume,
                'b': chem.get_basis_final_conc(self.ration_type),
                'c': chem.reaction_ratio,
                'x': None,
            }
            states.append(state)

        d = self.reaction_volume
        main = states[0]

        def is_known(value):
            return value is not None

        def safe_close(left, right, rel_tol=1e-9, abs_tol=1e-12):
            return math.isclose(left, right, rel_tol=rel_tol, abs_tol=abs_tol)

        def set_value(state, key, value):
            if value is None:
                return False
            if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
                raise ValueError("计算得到非法数值，请检查输入。")
            if key in ('a', 'b', 'c', 's', 'x') and value < 0:
                raise ValueError("计算得到负数，请检查输入。")
            old = state.get(key)
            if old is None:
                state[key] = float(value)
                return True
            if not safe_close(old, value):
                raise ValueError("当前约束条件无法计算一致的结果!!!")
            return False

        def set_global_d(value):
            nonlocal d
            if value is None:
                return False
            if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
                raise ValueError("计算得到非法反应体积，请检查输入。")
            if value <= 0:
                raise ValueError("计算得到反应体积小于等于 0，请检查输入。")
            if d is None:
                d = float(value)
                return True
            if not safe_close(d, value):
                raise ValueError("当前约束条件无法计算一致的结果!!!")
            return False

        if main['c'] is None:
            main['c'] = 1.0

        for state in states:
            if is_known(state['a']):
                set_value(state, 'x', state['s'] * state['a'])
            if is_known(state['b']) and is_known(d):
                set_value(state, 'x', state['b'] * d)

        max_iterations = 200
        for _ in range(max_iterations):
            changed = False

            for state in states:
                if is_known(state['a']):
                    changed |= set_value(state, 'x', state['s'] * state['a'])
                if is_known(state['x']):
                    changed |= set_value(state, 'a', state['x'] / state['s'])
                if is_known(state['b']) and is_known(d):
                    changed |= set_value(state, 'x', state['b'] * d)
                if is_known(state['x']) and is_known(d):
                    changed |= set_value(state, 'b', state['x'] / d)
                if is_known(state['b']) and is_known(d):
                    changed |= set_value(state, 'a', d * state['b'] / state['s'])

            for state in states:
                if is_known(state['x']) and is_known(state['b']) and state['b'] > 0:
                    changed |= set_global_d(state['x'] / state['b'])

            if d is None and all(is_known(state['a']) for state in states):
                changed |= set_global_d(sum(state['a'] for state in states))

            c_main = main['c']
            x_main = main['x']
            b_main = main['b']
            a_main = main['a']
            s_main = main['s']

            if is_known(c_main):
                for state in states[1:]:
                    c_i = state['c']
                    s_i = state['s']
                    if not is_known(c_i):
                        if is_known(x_main) and is_known(state['x']) and x_main > 0:
                            changed |= set_value(state, 'c', c_main * state['x'] / x_main)
                        elif is_known(b_main) and is_known(state['b']) and b_main > 0:
                            changed |= set_value(state, 'c', c_main * state['b'] / b_main)
                        elif is_known(a_main) and is_known(state['a']) and a_main > 0:
                            changed |= set_value(state, 'c', c_main * (state['s'] * state['a']) / (s_main * a_main))
                        continue

                    if is_known(x_main):
                        changed |= set_value(state, 'x', x_main * c_i / c_main)
                    if is_known(b_main):
                        changed |= set_value(state, 'b', b_main * c_i / c_main)
                    if is_known(a_main):
                        changed |= set_value(state, 'a', a_main * (c_i / c_main) * (s_main / s_i))

                    if not is_known(main['x']) and is_known(state['x']) and c_i > 0:
                        changed |= set_value(main, 'x', state['x'] * c_main / c_i)
                    if not is_known(main['b']) and is_known(state['b']) and c_i > 0:
                        changed |= set_value(main, 'b', state['b'] * c_main / c_i)
                    if not is_known(main['a']) and is_known(state['a']) and c_i > 0:
                        changed |= set_value(main, 'a', state['a'] * (c_main / c_i) * (s_i / s_main))

            if not changed:
                break
        else:
            raise ValueError("计算未收敛，请检查输入条件是否充分或互相矛盾。")

        # 收尾阶段：若 ratio 仍未显式写回，则根据 amount / final / volume 自动补推
        main_x = main['x']
        main_b = main['b']
        main_a = main['a']
        main_c = main['c'] if main['c'] is not None else 1.0
        main['c'] = main_c

        for state in states:
            chem = state['chem']
            if state['a'] is not None and state['b'] is not None and d is not None:
                expected_b = state['s'] * state['a'] / d
                if not safe_close(state['b'], expected_b):
                    raise ValueError("当前约束条件无法计算一致的结果!!!")

            if state is not main and state['c'] is None:
                if is_known(main_x) and is_known(state['x']) and main_x > 0:
                    state['c'] = main_c * state['x'] / main_x
                elif is_known(main_b) and is_known(state['b']) and main_b > 0:
                    state['c'] = main_c * state['b'] / main_b
                elif is_known(main_a) and is_known(state['a']) and main_a > 0:
                    state['c'] = main_c * (state['s'] * state['a']) / (main['s'] * main_a)

            chem.storage_conc_volume = state['a']
            chem.reaction_ratio = state['c']
            chem.set_basis_final_conc(self.ration_type, state['b'])

        self.reaction_volume = d

    def get_total_stock_volume(self) -> float:
        return sum(chem.storage_conc_volume or 0.0 for chem in self.all_substrates)
