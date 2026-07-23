import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    required this.apiService,
    this.onToggleTheme,
  });

  final ApiService apiService;
  final VoidCallback? onToggleTheme;

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<TransactionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _openEditSheet(TransactionModel transaction) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          apiService: widget.apiService,
          isIncome: transaction.isIncome,
          transaction: transaction,
        ),
      ),
    );
    if (created == true) _refresh();
  }

  Future<List<TransactionModel>> _load() async {
    final transactions = await widget.apiService.getTransactions();
    transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return transactions;
  }

  Map<String, List<TransactionModel>> _groupByDay(List<TransactionModel> transactions) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(tx.occurredAt.toLocal());
      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups;
  }

  String _dayHeader(String dayKey) {
    final date = DateTime.parse(dayKey);
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayKey = DateFormat('yyyy-MM-dd')
        .format(now.subtract(const Duration(days: 1)));

    if (dayKey == todayKey) return 'Today';
    if (dayKey == yesterdayKey) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
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
                        'Couldn\'t load transactions\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.mutedExpense),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final transactions = snapshot.data!;
            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 40,
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

            final grouped = _groupByDay(transactions);
            final groupKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: groupKeys.length,
              itemBuilder: (context, sectionIndex) {
                final dayKey = groupKeys[sectionIndex];
                final dayTransactions = grouped[dayKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _dayHeader(dayKey),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          for (int i = 0; i < dayTransactions.length; i++) ...[
                            TransactionTile(
                              transaction: dayTransactions[i],
                              onTap: () => _openEditSheet(dayTransactions[i]),
                              onDismissed: dayTransactions[i].id == null
                                  ? null
                                  : () async {
                                      await widget.apiService.deleteTransaction(
                                          dayTransactions[i].id!);
                                      _refresh();
                                    },
                            ),
                            if (i != dayTransactions.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
