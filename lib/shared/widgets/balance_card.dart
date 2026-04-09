import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/transactions/data/transaction_repository.dart';
import '../../core/constants/constants.dart';
import '../../core/services/currency_service.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalExpenses = ref.watch(totalExpensesForMonthProvider);
    final totalIncome = ref.watch(totalIncomeForMonthProvider);
    final cashBalance = ref.watch(cashBalanceProvider);
    final ewalletBalance = ref.watch(ewalletBalanceProvider);
    final bankBalance = ref.watch(bankBalanceProvider);
    final currency = ref.watch(currencyProvider);
    final balance = totalIncome - totalExpenses;

    return Card(
      margin: const EdgeInsets.all(AppSizes.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.totalBalance,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              formatCurrency(balance, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    label: 'Cash',
                    amount: cashBalance,
                    color: AppColors.success,
                    icon: Icons.payments_outlined,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    label: 'E-Wallet',
                    amount: ewalletBalance,
                    color: AppColors.primary,
                    icon: Icons.phone_android_outlined,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    label: 'Bank',
                    amount: bankBalance,
                    color: AppColors.income,
                    icon: Icons.account_balance_outlined,
                    currency: currency,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required Currency currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSizeSm, color: color),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xxs),
          Text(
            formatCurrency(amount, currency),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: amount < 0 ? AppColors.expense : null,
            ),
          ),
        ],
      ),
    );
  }
}
