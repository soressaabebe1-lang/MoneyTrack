import 'package:flutter/material.dart';

import 'screens/category_breakdown_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MoneyTrackApp());
}

class MoneyTrackApp extends StatefulWidget {
  const MoneyTrackApp({super.key});

  @override
  State<MoneyTrackApp> createState() => _MoneyTrackAppState();
}

class _MoneyTrackAppState extends State<MoneyTrackApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: RootShell(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

/// Hosts the bottom navigation between Dashboard, Breakdown and History,
/// plus a persistent light/dark mode toggle in the app bar.
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        apiService: _apiService,
        onToggleTheme: widget.onToggleTheme,
      ),
      CategoryBreakdownScreen(
        apiService: _apiService,
        onToggleTheme: widget.onToggleTheme,
      ),
      TransactionHistoryScreen(
        apiService: _apiService,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Breakdown',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
