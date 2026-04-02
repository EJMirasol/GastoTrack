import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(monthlyTransactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final byCategory = ref.watch(transactionsByCategoryProvider);
    final totalExpenses = ref.watch(totalExpensesForMonthProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: expenses.isEmpty
          ? const _EmptyAnalytics()
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _SummaryCard(
                  totalExpenses: totalExpenses,
                  totalIncome: ref.watch(totalIncomeForMonthProvider),
                  month: selectedMonth,
                  currency: ref.watch(currencyProvider),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'Spending by Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _PieChartCard(
                  byCategory: byCategory,
                  categories: categories,
                  totalExpenses: totalExpenses,
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'Daily Spending',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _BarChartCard(
                  expenses: expenses,
                  selectedMonth: selectedMonth,
                  currency: ref.watch(currencyProvider),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'Category Breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _CategoryBreakdown(
                  byCategory: byCategory,
                  categories: categories,
                  totalExpenses: totalExpenses,
                  currency: ref.watch(currencyProvider),
                ),
              ],
            ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'No data to analyze',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Add some expenses to see analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalExpenses,
    required this.totalIncome,
    required this.month,
    required this.currency,
  });

  final double totalExpenses;
  final double totalIncome;
  final DateTime month;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(month),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  context,
                  label: 'Spent',
                  value: totalExpenses,
                  color: AppColors.expense,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _buildStat(
                  context,
                  label: 'Income',
                  value: totalIncome,
                  color: AppColors.income,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          formatCurrency(value, currency),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({
    required this.byCategory,
    required this.categories,
    required this.totalExpenses,
  });

  final Map<String, double> byCategory;
  final List<Category> categories;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    if (byCategory.isEmpty || totalExpenses == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Center(
            child: Text(
              'No expense data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _buildSections(),
            ),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return byCategory.entries.map((entry) {
      final category = categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => const Category(
          id: 'unknown',
          name: 'Other',
          icon: 'more_horiz',
          color: '#9E9E9E',
        ),
      );

      final percentage = (entry.value / totalExpenses) * 100;
      final color = _parseColor(category.color);

      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.expenses,
    required this.selectedMonth,
    required this.currency,
  });

  final List<Transaction> expenses;
  final DateTime selectedMonth;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final dailyTotals = _calculateDailyTotals();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxValue(dailyTotals),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value % 5 != 0) return const SizedBox();
                      return Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${currency.symbol}${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getMaxValue(dailyTotals) / 4,
              ),
              barGroups: dailyTotals.entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      color: AppColors.primary,
                      width: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Map<int, double> _calculateDailyTotals() {
    final dailyTotals = <int, double>{};
    for (final expense in expenses) {
      if (expense.type.name == 'expense') {
        final day = expense.date.day;
        dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
      }
    }
    return dailyTotals;
  }

  double _getMaxValue(Map<int, double> dailyTotals) {
    if (dailyTotals.isEmpty) return 100;
    final max = dailyTotals.values.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.byCategory,
    required this.categories,
    required this.totalExpenses,
    required this.currency,
  });

  final Map<String, double> byCategory;
  final List<Category> categories;
  final double totalExpenses;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        child: Column(
          children: sortedCategories.map((entry) {
            final category = categories.firstWhere(
              (c) => c.id == entry.key,
              orElse: () => const Category(
                id: 'unknown',
                name: 'Other',
                icon: 'more_horiz',
                color: '#9E9E9E',
              ),
            );

            final percentage = totalExpenses > 0
                ? (entry.value / totalExpenses) * 100
                : 0.0;

            return _CategoryItem(
              category: category,
              amount: entry.value,
              percentage: percentage,
              currency: currency,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.currency,
  });

  final Category category;
  final double amount;
  final double percentage;
  final Currency currency;

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
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

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.color);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_getIconData(category.icon), color: color, size: 20),
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(amount, currency),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
