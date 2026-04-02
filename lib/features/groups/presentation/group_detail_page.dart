import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/group.dart';
import '../presentation/groups_page.dart';

class Settlement {
  final String fromUserId;
  final String toUserId;
  final double amount;

  Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailPage({required this.groupId, super.key});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
    final currentUser = ref.watch(currentUserProvider);
    final expenses = ref.watch(transactionsProvider);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Not Found')),
        body: const Center(child: Text('This group no longer exists.')),
      );
    }

    final groupExpenses = expenses.where((e) => e.groupId == group.id).toList();
    final settlements = _calculateSettlements(group, groupExpenses);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showInviteDialog(context, group),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Leave Group'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'leave' && currentUser != null) {
                ref
                    .read(groupsProvider.notifier)
                    .leaveGroup(widget.groupId, currentUser.id);
                context.pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MembersCard(group: group),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Text(
                'Group Expenses',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (groupExpenses.isEmpty)
              const _EmptyTransactionsState()
            else
              ...groupExpenses.map(
                (expense) => _GroupTransactionTile(
                  expense: expense,
                  currency: ref.watch(currencyProvider),
                ),
              ),
            if (settlements.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Text(
                  'Settlements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...settlements.map(
                (s) => _SettlementTile(
                  settlement: s,
                  group: group,
                  currentUserId: currentUser?.id ?? '',
                  currency: ref.watch(currencyProvider),
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add?groupId=${group.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  List<Settlement> _calculateSettlements(
    Group group,
    List<Transaction> expenses,
  ) {
    final balances = <String, double>{};

    for (final member in group.members) {
      balances[member] = 0;
    }

    for (final expense in expenses) {
      final payer = expense.userId;
      final amount = expense.amount;
      final memberCount = group.members.length;
      final sharePerMember = amount / memberCount;

      balances[payer] = (balances[payer] ?? 0) + amount;

      for (final member in group.members) {
        balances[member] = (balances[member] ?? 0) - sharePerMember;
      }
    }

    final debtors = <String, double>{};
    final creditors = <String, double>{};

    balances.forEach((user, balance) {
      if (balance < -0.01) {
        debtors[user] = -balance;
      } else if (balance > 0.01) {
        creditors[user] = balance;
      }
    });

    final settlements = <Settlement>[];

    final sortedDebtors = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedCreditors = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final remainingCreditors = Map<String, double>.from(creditors);

    for (final debtor in sortedDebtors) {
      var remainingDebt = debtor.value;

      for (final creditor in sortedCreditors) {
        if (remainingDebt <= 0.01) break;
        final creditorRemaining = remainingCreditors[creditor.key] ?? 0;
        if (creditorRemaining <= 0.01) continue;

        final settleAmount = remainingDebt < creditorRemaining
            ? remainingDebt
            : creditorRemaining;

        if (settleAmount > 0.01) {
          settlements.add(
            Settlement(
              fromUserId: debtor.key,
              toUserId: creditor.key,
              amount: settleAmount,
            ),
          );

          remainingDebt -= settleAmount;
          remainingCreditors[creditor.key] = creditorRemaining - settleAmount;
        }
      }
    }

    return settlements;
  }

  void _showInviteDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this invite code with others:'),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    group.inviteCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: group.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(AppSizes.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Members',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: group.members.map((member) {
                return Chip(
                  label: Text(
                    member == group.createdBy ? 'You (Admin)' : 'Member',
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, size: 16),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'No group expenses yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Add expenses to start splitting bills',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTransactionTile extends StatelessWidget {
  const _GroupTransactionTile({required this.expense, required this.currency});

  final Transaction expense;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.receipt, color: AppColors.expense),
      ),
      title: Text(expense.description ?? 'Expense'),
      subtitle: Text(DateFormat('MMM d, y').format(expense.date)),
      trailing: Text(
        formatCurrency(expense.amount, currency),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.expense,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.settlement,
    required this.group,
    required this.currentUserId,
    required this.currency,
  });

  final Settlement settlement;
  final Group group;
  final String currentUserId;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final isOwed = settlement.toUserId == currentUserId;
    final isOwing = settlement.fromUserId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs,
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOwed
                ? AppColors.income.withValues(alpha: 0.1)
                : AppColors.expense.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOwed ? Icons.arrow_downward : Icons.arrow_upward,
            color: isOwed ? AppColors.income : AppColors.expense,
          ),
        ),
        title: Text(
          isOwed
              ? 'owes you'
              : isOwing
              ? 'You owe'
              : 'Settlement',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Text(
          formatCurrency(settlement.amount, currency),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isOwed ? AppColors.income : AppColors.expense,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isOwed || isOwing
            ? TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as settled')),
                  );
                },
                child: Text(isOwed ? 'Mark as received' : 'Mark as paid'),
              )
            : null,
      ),
    );
  }
}
