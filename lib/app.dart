import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_screen.dart';
import 'package:ilovebioconjugation/ui/history/history_detail_screen.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/settings/settings_screen.dart';
import 'package:ilovebioconjugation/ui/shared/confirm_reset_dialog.dart';
import 'package:ilovebioconjugation/ui/templates/template_library_screen.dart';

const _destinations = ['/', '/history', '/templates', '/settings'];

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(appSettingsProvider);
          final selected = _destinations.indexWhere(
            (path) => path != '/' && state.uri.path.startsWith(path),
          );
          return WorkspaceShell(
            selectedIndex: selected < 0 ? 0 : selected,
            collapsed: settings.sidebarCollapsed,
            onSidebarToggle: () => ref
                .read(appSettingsProvider.notifier)
                .setSidebarCollapsed(!settings.sidebarCollapsed),
            onDestinationSelected: (index) => context.go(_destinations[index]),
            onNewCalculation: () async {
              if (await confirmCalculationReset(context) && context.mounted) {
                ref.read(calculatorProvider.notifier).reset();
                context.go('/');
              }
            },
            child: child,
          );
        },
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CalculatorScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/templates',
          builder: (context, state) => const TemplateLibraryScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => HistoryDetailScreen(
                recordId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

enum _WorkspaceAction {
  newCalculation,
  history,
  templates,
  settings,
  sidebar,
  help,
  about,
}

/// A complete local workspace shell: menus, responsive navigation, and content.
class WorkspaceShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final bool collapsed;
  final VoidCallback? onSidebarToggle;
  final VoidCallback? onNewCalculation;

  const WorkspaceShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.collapsed = false,
    this.onSidebarToggle,
    this.onNewCalculation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(
              LogicalKeyboardKey.comma,
              control: true,
            ): () =>
                onDestinationSelected(3),
            const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
                onDestinationSelected(3),
          },
          child: Scaffold(
            body: SafeArea(
              bottom: wide,
              child: Row(
                children: [
                  if (wide) ...[
                    SizedBox(
                      width: collapsed ? 68 : 196,
                      child: _sidebar(context),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colors.border,
                    ),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        _menuBar(context, wide),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.science_outlined),
                        selectedIcon: Icon(Icons.science),
                        label: '计算器',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.history),
                        label: '历史',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bookmarks_outlined),
                        selectedIcon: Icon(Icons.bookmarks),
                        label: '模板',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: '设置',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _menuBar(BuildContext context, bool wide) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (wide)
            IconButton(
              key: const ValueKey('sidebar-toggle'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: collapsed ? '展开侧边栏' : '收起侧边栏',
              onPressed: onSidebarToggle,
              icon: Icon(
                collapsed ? Icons.menu_open : Icons.view_sidebar_outlined,
                size: 20,
              ),
            ),
          if (!wide) ...[
            const Icon(Icons.science_outlined, size: 19),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '我爱投反应',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<_WorkspaceAction>(
              tooltip: '工作台菜单',
              onSelected: (action) => _act(context, action),
              itemBuilder: (context) => [
                _popup(_WorkspaceAction.newCalculation, '新建计算'),
                _popup(_WorkspaceAction.history, '历史记录'),
                _popup(_WorkspaceAction.templates, '模板库'),
                _popup(_WorkspaceAction.settings, '工作台设置'),
                _popup(_WorkspaceAction.help, '使用说明'),
                _popup(_WorkspaceAction.about, '关于'),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
          ] else ...[
            MenuBar(
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(colors.surface),
                elevation: const WidgetStatePropertyAll(0),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              children: [
                SubmenuButton(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: WidgetStatePropertyAll(Size(48, 36)),
                  ),
                  menuChildren: [
                    _menu(
                      context,
                      _WorkspaceAction.newCalculation,
                      '新建计算',
                      Icons.add,
                    ),
                    _menu(
                      context,
                      _WorkspaceAction.history,
                      '历史记录',
                      Icons.history,
                    ),
                    _menu(
                      context,
                      _WorkspaceAction.templates,
                      '模板库',
                      Icons.bookmarks_outlined,
                    ),
                  ],
                  child: const Text('文件'),
                ),
                SubmenuButton(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: WidgetStatePropertyAll(Size(48, 36)),
                  ),
                  menuChildren: [
                    _menu(
                      context,
                      _WorkspaceAction.sidebar,
                      collapsed ? '展开侧边栏' : '收起侧边栏',
                      Icons.view_sidebar_outlined,
                    ),
                    _menu(
                      context,
                      _WorkspaceAction.settings,
                      '工作台设置',
                      Icons.settings_outlined,
                    ),
                  ],
                  child: const Text('视图'),
                ),
                SubmenuButton(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: WidgetStatePropertyAll(Size(48, 36)),
                  ),
                  menuChildren: [
                    _menu(
                      context,
                      _WorkspaceAction.help,
                      '使用说明',
                      Icons.help_outline,
                    ),
                    _menu(
                      context,
                      _WorkspaceAction.about,
                      '关于我爱投反应',
                      Icons.info_outline,
                    ),
                  ],
                  child: const Text('帮助'),
                ),
              ],
            ),
            const Spacer(),
            Text('本地工作台', style: TextStyle(fontSize: 11, color: colors.muted)),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<_WorkspaceAction> _popup(
    _WorkspaceAction action,
    String label,
  ) => PopupMenuItem(value: action, child: Text(label));

  Widget _menu(
    BuildContext context,
    _WorkspaceAction action,
    String label,
    IconData icon,
  ) => MenuItemButton(
    leadingIcon: Icon(icon, size: 18),
    onPressed: () => _act(context, action),
    child: Text(label),
  );

  void _act(BuildContext context, _WorkspaceAction action) {
    switch (action) {
      case _WorkspaceAction.newCalculation:
        onNewCalculation?.call();
      case _WorkspaceAction.history:
        onDestinationSelected(1);
      case _WorkspaceAction.templates:
        onDestinationSelected(2);
      case _WorkspaceAction.settings:
        onDestinationSelected(3);
      case _WorkspaceAction.sidebar:
        onSidebarToggle?.call();
      case _WorkspaceAction.help:
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('使用说明'),
            content: const SingleChildScrollView(
              child: Text(
                '1. 设置目标体积与投料比类型。\n\n2. 填写母液浓度，以及已知的终浓度、取样体积或投料比。质量与摩尔换算需要分子量。\n\n3. 只启用本次反应需要的底物，然后运行计算。\n\n4. 核对取样量与补液量；可复制结果或从历史记录恢复输入。\n\n快捷键\nCtrl / ⌘ + Enter：运行计算\nCtrl / ⌘ + Shift + C：复制结果\nCtrl / ⌘ + ,：打开设置\n\n数据与偏好保存在本机，不会自动同步到其他设备。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      case _WorkspaceAction.about:
        showAboutDialog(
          context: context,
          applicationName: '我爱投反应',
          applicationVersion: '2.0.0',
          applicationIcon: const Icon(Icons.science_outlined, size: 32),
          children: const [Text('用于生物偶联实验的投料计算工作台。计算结果基于输入条件，请结合实际实验要求核对。')],
        );
    }
  }

  Widget _sidebar(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.sidebar,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          collapsed ? 10 : 16,
          24,
          collapsed ? 10 : 16,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (collapsed)
              const Center(
                child: Tooltip(
                  message: '我爱投反应',
                  child: Icon(Icons.science_outlined, size: 25),
                ),
              )
            else ...[
              const Row(
                children: [
                  Icon(Icons.science_outlined, size: 25),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '我爱投反应',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 35, top: 5),
                child: Text(
                  'BIOCONJUGATION',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            Tooltip(
              message: '新建计算',
              child: OutlinedButton(
                key: const ValueKey('new-calculation'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: onNewCalculation,
                child: collapsed
                    ? const Icon(Icons.add, size: 20)
                    : const Row(
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 10),
                          Text('新建计算'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _navItem(context, 0, Icons.science_outlined, '投料计算'),
            const SizedBox(height: 5),
            _navItem(context, 1, Icons.history, '历史记录'),
            const SizedBox(height: 5),
            _navItem(context, 2, Icons.bookmarks_outlined, '模板库'),
            const Spacer(),
            _navItem(context, 3, Icons.settings_outlined, '工作台设置'),
            const SizedBox(height: 10),
            Divider(color: colors.border),
            const SizedBox(height: 12),
            if (collapsed)
              Center(
                child: Tooltip(
                  message: '计算记录保存在本机',
                  child: Icon(
                    Icons.computer_outlined,
                    size: 19,
                    color: colors.muted,
                  ),
                ),
              )
            else ...[
              const Text(
                '实验室工作台',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '计算记录保存在本机',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = selectedIndex == index;
    final colors = AppColors.of(context);
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: collapsed ? label : '',
        child: Material(
          color: selected ? colors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onDestinationSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected ? colors.text : colors.muted,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: '我爱投反应',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * settings.textScale,
          ),
        ),
        child: child!,
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
