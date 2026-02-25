import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/expenses/domain/expense.dart';
import '../../features/expenses/domain/category.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../core/constants/constants.dart';

class ExpenseListItem extends ConsumerWidget {
  const ExpenseListItem({
    required this.expense,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final category = categories.firstWhere(
      (c) => c.id == expense.categoryId,
      orElse: () => const Category(
        id: 'unknown',
        name: 'Unknown',
        icon: 'help',
        color: '#9E9E9E',
      ),
    );

    final isExpense = expense.type == ExpenseType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_getIconData(category.icon), color: color),
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: expense.description != null
          ? Text(
              expense.description!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        '${isExpense ? "-" : "+"}\$${expense.amount.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    return switch (iconName) {
      'restaurant' => Icons.restaurant,
      'directions_car' => Icons.directions_car,
      'shopping_bag' => Icons.shopping_bag,
      'movie' => Icons.movie,
      'receipt' => Icons.receipt,
      'local_hospital' => Icons.local_hospital,
      'school' => Icons.school,
      'home' => Icons.home,
      'account_balance_wallet' => Icons.account_balance_wallet,
      _ => Icons.more_horiz,
    };
  }
}
