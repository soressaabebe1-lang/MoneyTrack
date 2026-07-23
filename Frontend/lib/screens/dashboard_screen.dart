import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/net_balance_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiService,
    required this.refreshNotifier,
    this.onToggleTheme,
  });

  final ApiService apiService;
  final ValueNotifier<int> refreshNotifier;
  final VoidCallback? onToggleTheme;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;
  final _searchController = TextEditingController();
  bool _searchLoading = false;
  String? _searchError;
  _SearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier.addListener(_refresh);
    _future = _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.apiService.getTransactions(),
      widget.apiService.getTotalIncome(),
      widget.apiService.getTotalExpenses(),
    ]);
    final transactions = results[0] as List<TransactionModel>;
    transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return _DashboardData(
      transactions: transactions,
      totalIncome: results[1] as double,
      totalExpenses: results[2] as double,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _searchByName() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchError = 'Enter a name or category to search transactions.';
      });
      return;
    }

    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final transactions = await widget.apiService.searchTransactions(query);
      if (!mounted) return;
      final totalIncome = transactions
          .where((tx) => tx.isIncome)
          .fold<double>(0.0, (sum, tx) => sum + tx.income);
      final totalExpenses = transactions
          .where((tx) => !tx.isIncome)
          .fold<double>(0.0, (sum, tx) => sum + tx.expenses);
      final netBalance = totalIncome - totalExpenses;

      setState(() {
        _searchResult = _SearchResult(
          query: query,
          transactions: transactions,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          netBalance: netBalance,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _searchResult = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _openAddSheet({required bool isIncome}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          apiService: widget.apiService,
          isIncome: isIncome,
          refreshNotifier: widget.refreshNotifier,
        ),
      ),
    );
    if (created == true && _searchController.text.trim().isNotEmpty) {
      await _searchByName();
    }
  }

  Future<void> _openEditSheet(TransactionModel transaction) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          apiService: widget.apiService,
          isIncome: transaction.isIncome,
          transaction: transaction,
          refreshNotifier: widget.refreshNotifier,
        ),
      ),
    );
    if (created == true && _searchController.text.trim().isNotEmpty) {
      await _searchByName();
    }
  }

  Widget _buildSearchValueRow({
    required String label,
    required double amount,
    required Color color,
  }) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        Text(
          fmt.format(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyTrack'),
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: AppColors.brandGreen,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brandGreen,
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final data = snapshot.data!;
            final recent = data.transactions.take(8).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                NetBalanceCard(
                  totalIncome: data.totalIncome,
                  totalExpenses: data.totalExpenses,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    QuickActionButton(
                      label: 'Add Income',
                      icon: Icons.add_rounded,
                      isPrimary: true,
                      onTap: () => _openAddSheet(isIncome: true),
                    ),
                    const SizedBox(width: 12),
                    QuickActionButton(
                      label: 'Add Expense',
                      icon: Icons.remove_rounded,
                      isPrimary: false,
                      onTap: () => _openAddSheet(isIncome: false),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Search by name',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Enter a name to search',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded),
                            onPressed: _searchLoading ? null : _searchByName,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!_searchLoading) _searchByName();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _searchLoading ? null : _searchByName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      child: _searchLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _searchError!,
                    style: const TextStyle(color: AppColors.expenseRed),
                  ),
                ],
                if (_searchResult != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Results for "${_searchResult!.query}"',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSearchValueRow(
                            label: 'Income',
                            amount: _searchResult!.totalIncome,
                            color: AppColors.incomeGreen,
                          ),
                          const SizedBox(height: 10),
                          _buildSearchValueRow(
                            label: 'Expenses',
                            amount: _searchResult!.totalExpenses,
                            color: AppColors.expenseRed,
                          ),
                          const SizedBox(height: 10),
                          _buildSearchValueRow(
                            label: 'Net balance',
                            amount: _searchResult!.netBalance,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          ..._searchResult!.transactions.map((tx) => Column(
                                children: [
                                  TransactionTile(
                                    transaction: tx,
                                    onTap: () => _openEditSheet(tx),
                                    onDismissed: tx.id == null
                                        ? null
                                        : () async {
                                            await widget.apiService
                                                .deleteTransaction(tx.id!);
                                            await _searchByName();
                                          },
                                  ),
                                  const Divider(height: 1),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    if (data.transactions.length > recent.length)
                      Text(
                        'See all',
                        style: TextStyle(
                          color: AppColors.brandGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const _EmptyTransactionsState()
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Column(
                        children: [
                          for (int i = 0; i < recent.length; i++) ...[
                            TransactionTile(
                              transaction: recent[i],
                              onTap: () => _openEditSheet(recent[i]),
                              onDismissed: recent[i].id == null
                                  ? null
                                  : () async {
                                      await widget.apiService
                                          .deleteTransaction(recent[i].id!);
                                      _refresh();
                                    },
                            ),
                            if (i != recent.length - 1) const Divider(height: 1),
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
}

class _DashboardData {
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpenses;

  _DashboardData({
    required this.transactions,
    required this.totalIncome,
    required this.totalExpenses,
  });
}

class _SearchResult {
  _SearchResult({
    required this.query,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
  });

  final String query;
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpenses;
  final double netBalance;
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.mutedExpense),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t reach MoneyTrack API\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedExpense),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}