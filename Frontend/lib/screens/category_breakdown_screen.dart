import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';

enum BreakdownMeasure { income, expense, transactions }
enum BreakdownGroupBy { reason, name, day }

String breakdownMeasureLabel(BreakdownMeasure measure) {
  switch (measure) {
    case BreakdownMeasure.income:
      return 'Income';
    case BreakdownMeasure.expense:
      return 'Expense';
    case BreakdownMeasure.transactions:
      return 'Transactions';
  }
}

String breakdownGroupByLabel(BreakdownGroupBy groupBy) {
  switch (groupBy) {
    case BreakdownGroupBy.reason:
      return 'Reason';
    case BreakdownGroupBy.name:
      return 'Name';
    case BreakdownGroupBy.day:
      return 'Day';
  }
}

const _breakdownColorPalette = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF6366F1),
];

/// Groups transactions by selected dimension and shows a simple donut chart
/// plus ranked list. The user can switch between income, expenses, and
/// transaction counts, and group results by reason, name, or day.
class CategoryBreakdownScreen extends StatefulWidget {
  const CategoryBreakdownScreen({
    super.key,
    required this.apiService,
    this.onToggleTheme,
  });

  final ApiService apiService;
  final VoidCallback? onToggleTheme;

  @override
  State<CategoryBreakdownScreen> createState() =>
      _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState extends State<CategoryBreakdownScreen> {
  late Future<List<TransactionModel>> _future;
  int _touchedIndex = -1;
  BreakdownMeasure _selectedMeasure = BreakdownMeasure.expense;
  BreakdownGroupBy _selectedGroupBy = BreakdownGroupBy.reason;

  @override
  void initState() {
    super.initState();
    _future = widget.apiService.getTransactions();
  }

  Future<void> _refresh() async {
    final next = widget.apiService.getTransactions();
    setState(() => _future = next);
    await next;
  }

  List<_CategoryTotal> _buildTotals(List<TransactionModel> transactions) {
    final Map<String, double> totals = {};
    for (final tx in transactions) {
      final value = switch (_selectedMeasure) {
        BreakdownMeasure.income => tx.income,
        BreakdownMeasure.expense => tx.expenses,
        BreakdownMeasure.transactions => 1.0,
      };

      if (_selectedMeasure == BreakdownMeasure.income && value <= 0) continue;
      if (_selectedMeasure == BreakdownMeasure.expense && value <= 0) continue;

      final label = switch (_selectedGroupBy) {
        BreakdownGroupBy.reason => tx.reason,
        BreakdownGroupBy.name => tx.name,
        BreakdownGroupBy.day =>
          DateFormat('yyyy-MM-dd').format(tx.occurredAt.toLocal()),
      };

      totals.update(label, (v) => v + value, ifAbsent: () => value);
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => _CategoryTotal(reason: e.key, amount: e.value))
        .toList();
  }

  Color _colorForLabel(String label) {
    if (label.isEmpty) return AppColors.mutedExpense;
    final hash = label.toLowerCase().runes.fold<int>(0, (hash, char) {
      hash = ((hash << 5) - hash) + char;
      return hash & 0x7fffffff;
    });
    return _breakdownColorPalette[hash % _breakdownColorPalette.length];
  }

  IconData _iconForLabel(String label) {
    switch (_selectedGroupBy) {
      case BreakdownGroupBy.reason:
        return categoryStyleFor(label).icon;
      case BreakdownGroupBy.name:
        return Icons.person_rounded;
      case BreakdownGroupBy.day:
        return Icons.calendar_today_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Breakdown'),
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: AppColors.brandGreen,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brandGreen,
        onRefresh: _refresh,
        child: FutureBuilder<List<TransactionModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.cloud_off_rounded,
                      size: 40, color: AppColors.mutedExpense),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Couldn\'t load categories\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.mutedExpense),
                    ),
                  ),
                ],
              );
            }

            final totals = _buildTotals(snapshot.data!);
            final totalValue =
                totals.fold<double>(0, (sum, t) => sum + t.amount);

            if (totals.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No expenses recorded yet',
                      style: TextStyle(color: AppColors.mutedExpense),
                    ),
                  ),
                ],
              );
            }

            final fmt = NumberFormat.currency(symbol: '\$');

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Measure',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BreakdownMeasure>(
                            value: _selectedMeasure,
                            isExpanded: true,
                            items: BreakdownMeasure.values
                                .map(
                                  (measure) => DropdownMenuItem(
                                    value: measure,
                                    child: Text(breakdownMeasureLabel(measure)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedMeasure = value;
                                _touchedIndex = -1;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Group by',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BreakdownGroupBy>(
                            value: _selectedGroupBy,
                            isExpanded: true,
                            items: BreakdownGroupBy.values
                                .map(
                                  (groupBy) => DropdownMenuItem(
                                    value: groupBy,
                                    child: Text(breakdownGroupByLabel(groupBy)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedGroupBy = value;
                                _touchedIndex = -1;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AspectRatio(
                  aspectRatio: 1.3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 60,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = response
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: [
                            for (int i = 0; i < totals.length; i++)
                              _buildSection(
                                totals[i],
                                totalValue,
                                isTouched: i == _touchedIndex,
                                color: _colorForLabel(totals[i].reason),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedMeasure == BreakdownMeasure.transactions
                                ? 'Transactions'
                                : 'Total ${breakdownMeasureLabel(_selectedMeasure)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedMeasure == BreakdownMeasure.transactions
                                ? totalValue.toStringAsFixed(0)
                                : fmt.format(totalValue),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'By ${breakdownGroupByLabel(_selectedGroupBy)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (int i = 0; i < totals.length; i++) ...[
                          _CategoryRow(
                            total: totals[i],
                            share: totalValue == 0
                                ? 0
                                : totals[i].amount / totalValue,
                          ),
                          if (i != totals.length - 1)
                            const Divider(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PieChartSectionData _buildSection(
    _CategoryTotal total,
    double totalSpend, {
    required bool isTouched,
    required Color color,
  }) {
    final percentage =
        totalSpend == 0 ? 0.0 : (total.amount / totalSpend) * 100;
    final radius = isTouched ? 64.0 : 56.0;

    return PieChartSectionData(
      color: color,
      value: total.amount,
      title: '${percentage.toStringAsFixed(0)}%',
      radius: radius,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _CategoryTotal {
  final String reason;
  final double amount;
  _CategoryTotal({required this.reason, required this.amount});
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.total, required this.share});

  final _CategoryTotal total;
  final double share;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = _CategoryRow._colorForLabel(total.reason);
    final fmt = NumberFormat.currency(symbol: '\$');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tileColor.withOpacity(isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_CategoryRow._iconForLabel(total.reason),
                color: tileColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total.reason,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0, 1).toDouble(),
                    minHeight: 5,
                    backgroundColor:
                        isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation(tileColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmt.format(total.amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorForLabel(String label) {
    if (label.isEmpty) return AppColors.mutedExpense;
    final hash = label.toLowerCase().runes.fold<int>(0, (hash, char) {
      hash = ((hash << 5) - hash) + char;
      return hash & 0x7fffffff;
    });
    return _breakdownColorPalette[hash % _breakdownColorPalette.length];
  }

  static IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('food') || lower.contains('lunch') || lower.contains('dinner')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('grocery') || lower.contains('groceries') || lower.contains('shopping')) {
      return Icons.shopping_basket_rounded;
    }
    if (lower.contains('transport') || lower.contains('taxi')) {
      return Icons.directions_bus_rounded;
    }
    if (lower.contains('rent') || lower.contains('home')) {
      return Icons.home_rounded;
    }
    if (lower.contains('salary') || lower.contains('freelance')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('gift')) {
      return Icons.card_giftcard_rounded;
    }
    if (lower.contains('bills') || lower.contains('utility')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('health')) {
      return Icons.local_hospital_rounded;
    }
    if (lower.contains('entertainment') || lower.contains('subscription')) {
      return Icons.movie_rounded;
    }
    if (lower.contains('education')) {
      return Icons.school_rounded;
    }
    return Icons.receipt_rounded;
  }
}