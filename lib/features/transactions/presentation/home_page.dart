import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/transaction_repository.dart';
import '../data/budget_service.dart';
import '../../../core/constants/constants.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/presentation/groups_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(monthlyTransactionsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null) {
        final userId = next.user!.id;
        ref.read(transactionsProvider.notifier).loadForUser(userId);
        ref.read(groupsProvider.notifier).loadForUser(userId);
        ref.read(budgetsProvider.notifier).loadForUser(userId);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('GastoTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _showMonthPicker(context, ref, selectedMonth),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(currentUserProvider);
          if (user != null) {
            await Future.wait([
              ref.read(transactionsProvider.notifier).loadForUser(user.id),
              ref.read(groupsProvider.notifier).loadForUser(user.id),
              ref.read(budgetsProvider.notifier).loadForUser(user.id),
            ]);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const BalanceCard(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(selectedMonth),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text('Filter'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (expenses.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final expense = expenses[index];
                  return TransactionListItem(
                    expense: expense,
                    onTap: () {},
                    onLongPress: () =>
                        _showDeleteDialog(context, ref, expense.id),
                  );
                }, childCount: expenses.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showMonthPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime current,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = picked;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String expenseId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(transactionsProvider.notifier)
                  .removeTransaction(expenseId);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            AppStrings.noTransactions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            AppStrings.noTransactionsDesc,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
