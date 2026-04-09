import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/transaction.dart';
import '../data/transaction_repository.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../../shared/utils/payment_utils.dart';
import '../../../shared/widgets/widgets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final notifier = ref.read(transactionsProvider.notifier);
    await notifier.loadForUser(user.id);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final currency = ref.watch(currencyProvider);
    final activeCount = _countActiveFilters(filter);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM().format(selectedMonth)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text(activeCount.toString()),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _showMonthPicker(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add'),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: BalanceCard()),
                  if (transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(currency: currency),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = transactions[index];
                          return TransactionListItem(
                            expense: expense,
                            onTap: () => context.go('/edit/${expense.id}'),
                            onLongPress: () => _showDeleteDialog(expense),
                          );
                        },
                        childCount: transactions.length,
                        findChildIndexCallback: (key) {
                          final valueKey = key as ValueKey<String>;
                          final index = transactions.indexWhere(
                            (e) => e.id == valueKey.value,
                          );
                          return index == -1 ? null : index;
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final categories = ref.read(categoriesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final current = ref.read(transactionFilterProvider);

            void updateFilter(TransactionFilter newFilter) {
              ref.read(transactionFilterProvider.notifier).state = newFilter;
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSizes.lg),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.filter,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (current.hasActiveFilters)
                          TextButton(
                            onPressed: () =>
                                updateFilter(const TransactionFilter()),
                            child: const Text(AppStrings.clearAll),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    const _SectionHeader(title: AppStrings.type),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: [
                        _ChoiceChip(
                          label: AppStrings.all,
                          selected: current.type == null,
                          onSelected: (_) =>
                              updateFilter(current.copyWith(clearType: true)),
                        ),
                        _ChoiceChip(
                          label: AppStrings.expense,
                          selected: current.type == TransactionType.expense,
                          onSelected: (_) => updateFilter(
                            current.copyWith(type: TransactionType.expense),
                          ),
                        ),
                        _ChoiceChip(
                          label: AppStrings.income,
                          selected: current.type == TransactionType.income,
                          onSelected: (_) => updateFilter(
                            current.copyWith(type: TransactionType.income),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    const _SectionHeader(title: AppStrings.paymentMethod),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: [
                        _ChoiceChip(
                          label: AppStrings.all,
                          selected: current.paymentMethod == null,
                          onSelected: (_) => updateFilter(
                            current.copyWith(clearPaymentMethod: true),
                          ),
                        ),
                        _ChoiceChip(
                          label: getPaymentMethodLabel(PaymentMethod.cash),
                          selected: current.paymentMethod == PaymentMethod.cash,
                          onSelected: (_) => updateFilter(
                            current.copyWith(paymentMethod: PaymentMethod.cash),
                          ),
                        ),
                        _ChoiceChip(
                          label: getPaymentMethodLabel(PaymentMethod.ewallet),
                          selected:
                              current.paymentMethod == PaymentMethod.ewallet,
                          onSelected: (_) => updateFilter(
                            current.copyWith(
                              paymentMethod: PaymentMethod.ewallet,
                            ),
                          ),
                        ),
                        _ChoiceChip(
                          label: getPaymentMethodLabel(PaymentMethod.bank),
                          selected: current.paymentMethod == PaymentMethod.bank,
                          onSelected: (_) => updateFilter(
                            current.copyWith(paymentMethod: PaymentMethod.bank),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    const _SectionHeader(title: AppStrings.categories),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: categories.map((cat) {
                        final isSelected = current.categoryIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            final newIds = Set<String>.from(
                              current.categoryIds,
                            );
                            if (selected) {
                              newIds.add(cat.id);
                            } else {
                              newIds.remove(cat.id);
                            }
                            updateFilter(current.copyWith(categoryIds: newIds));
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    const _SectionHeader(title: AppStrings.sortBy),
                    const SizedBox(height: AppSizes.sm),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      children: [
                        _ChoiceChip(
                          label: AppStrings.newest,
                          selected: current.sort == SortOption.newestFirst,
                          onSelected: (_) => updateFilter(
                            current.copyWith(sort: SortOption.newestFirst),
                          ),
                        ),
                        _ChoiceChip(
                          label: AppStrings.oldest,
                          selected: current.sort == SortOption.oldestFirst,
                          onSelected: (_) => updateFilter(
                            current.copyWith(sort: SortOption.oldestFirst),
                          ),
                        ),
                        _ChoiceChip(
                          label: AppStrings.highest,
                          selected: current.sort == SortOption.amountHighLow,
                          onSelected: (_) => updateFilter(
                            current.copyWith(sort: SortOption.amountHighLow),
                          ),
                        ),
                        _ChoiceChip(
                          label: AppStrings.lowest,
                          selected: current.sort == SortOption.amountLowHigh,
                          onSelected: (_) => updateFilter(
                            current.copyWith(sort: SortOption.amountLowHigh),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xxl),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  int _countActiveFilters(TransactionFilter filter) {
    int count = 0;
    if (filter.type != null) count++;
    if (filter.categoryIds.isNotEmpty) count += filter.categoryIds.length;
    if (filter.paymentMethod != null) count++;
    if (filter.sort != SortOption.newestFirst) count++;
    return count;
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    final current = ref.read(selectedMonthProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(
        picked.year,
        picked.month,
      );
    }
  }

  Future<void> _showDeleteDialog(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteTransaction),
        content: const Text(AppStrings.deleteTransactionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(transactionsProvider.notifier)
          .removeTransaction(transaction.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: AppSizes.emptyIconSize,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
