import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

/// Best-effort icon + color mapping derived from the transaction's
/// free-text `reason` field, since the backend doesn't yet have a
/// dedicated `category` column.
class CategoryStyle {
  final IconData icon;
  final Color color;
  const CategoryStyle(this.icon, this.color);
}

CategoryStyle categoryStyleFor(String reason) {
  final r = reason.toLowerCase();

  const map = <String, CategoryStyle>{
    'food': CategoryStyle(Icons.restaurant_rounded, Color(0xFFF59E0B)),
    'lunch': CategoryStyle(Icons.restaurant_rounded, Color(0xFFF59E0B)),
    'dinner': CategoryStyle(Icons.restaurant_rounded, Color(0xFFF59E0B)),
    'grocery': CategoryStyle(Icons.shopping_basket_rounded, Color(0xFF22C55E)),
    'groceries': CategoryStyle(Icons.shopping_basket_rounded, Color(0xFF22C55E)),
    'transport': CategoryStyle(Icons.directions_bus_rounded, Color(0xFF3B82F6)),
    'taxi': CategoryStyle(Icons.local_taxi_rounded, Color(0xFF3B82F6)),
    'rent': CategoryStyle(Icons.home_rounded, Color(0xFF8B5CF6)),
    'salary': CategoryStyle(Icons.payments_rounded, AppColors.incomeGreen),
    'freelance': CategoryStyle(Icons.laptop_mac_rounded, AppColors.incomeGreen),
    'gift': CategoryStyle(Icons.card_giftcard_rounded, Color(0xFFEC4899)),
    'shopping': CategoryStyle(Icons.shopping_bag_rounded, Color(0xFFEC4899)),
    'bills': CategoryStyle(Icons.receipt_long_rounded, Color(0xFFEF4444)),
    'utility': CategoryStyle(Icons.bolt_rounded, Color(0xFFEF4444)),
    'health': CategoryStyle(Icons.local_hospital_rounded, Color(0xFFF43F5E)),
    'entertainment': CategoryStyle(Icons.movie_rounded, Color(0xFF6366F1)),
    'education': CategoryStyle(Icons.school_rounded, Color(0xFF0EA5E9)),
    'subscription': CategoryStyle(Icons.subscriptions_rounded, Color(0xFF6366F1)),
  };

  for (final entry in map.entries) {
    if (r.contains(entry.key)) return entry.value;
  }
  return const CategoryStyle(Icons.receipt_rounded, AppColors.mutedExpense);
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDismissed,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = categoryStyleFor(transaction.reason);
    final isIncome = transaction.isIncome;
    final amount = isIncome ? transaction.income : transaction.expenses;
    final fmt = NumberFormat.currency(symbol: '\$');
    final dateFmt = DateFormat('MMM d');

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.color.withOpacity(isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, color: style.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${fmt.format(amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isIncome
                      ? AppColors.incomeGreen
                      : AppColors.expenseRed,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateFmt.format(transaction.occurredAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: tile,
    );

    if (onDismissed == null || transaction.id == null) return content;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.expenseRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.expenseRed),
      ),
      child: content,
    );
  }
}
