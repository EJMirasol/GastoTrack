import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/domain/category.dart';
import '../../features/transactions/data/transaction_repository.dart';
import '../../core/constants/constants.dart';
import '../../core/services/currency_service.dart';
import '../utils/category_utils.dart';
import '../utils/payment_utils.dart';

class TransactionListItem extends ConsumerWidget {
  const TransactionListItem({
    required this.expense,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Transaction expense;
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

    final isExpense = expense.type == TransactionType.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final currency = ref.watch(currencyProvider);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: Icon(getCategoryIconData(category.icon), color: color),
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expense.description != null)
            Text(
              expense.description!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppSizes.xxs),
          Row(
            children: [
              Icon(
                getPaymentMethodIcon(expense.paymentMethod),
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                getPaymentMethodLabel(expense.paymentMethod),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Text(
        '${isExpense ? "-" : "+"}${formatCurrency(expense.amount, currency)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
