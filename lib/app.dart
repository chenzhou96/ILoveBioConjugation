import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjunction/theme/app_theme.dart';
import 'package:ilovebioconjunction/ui/calculator/calculator_screen.dart';
import 'package:ilovebioconjunction/ui/history/history_detail_screen.dart';
import 'package:ilovebioconjunction/ui/history/history_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex(state.uri),
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/');
              case 1:
                context.go('/history');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: '计算器',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: '历史记录',
            ),
          ],
        ),
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CalculatorScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return HistoryDetailScreen(recordId: id);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

int _selectedIndex(Uri uri) {
  if (uri.path.startsWith('/history')) return 1;
  return 0;
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '我爱投反应',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
