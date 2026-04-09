import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../../shared/utils/payment_utils.dart';
import '../../../shared/utils/category_utils.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../auth/data/auth_repository.dart';

class WalletsPage extends ConsumerStatefulWidget {
  const WalletsPage({super.key});

  @override
  ConsumerState<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends ConsumerState<WalletsPage> {
  bool _isTransferring = false;

  List<Transaction> _getTransactionsForMethod(
    List<Transaction> all,
    PaymentMethod method,
  ) {
    return all.where((e) => e.paymentMethod == method).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    final cashBalance = ref.watch(allTimeCashBalanceProvider);
    final ewalletBalance = ref.watch(allTimeEwalletBalanceProvider);
    final bankBalance = ref.watch(allTimeBankBalanceProvider);
    final totalBalance = cashBalance + ewalletBalance + bankBalance;
    final currency = ref.watch(currencyProvider);
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.wallets),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer',
            onPressed: _isTransferring ? null : _showTransferDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(currentUserProvider);
          if (user == null) return;
          final notifier = ref.read(transactionsProvider.notifier);
          await notifier.loadForUser(user.id);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            _SummaryCard(
              totalBalance: totalBalance,
              cashBalance: cashBalance,
              ewalletBalance: ewalletBalance,
              bankBalance: bankBalance,
              currency: currency,
            ),
            const SizedBox(height: AppSizes.md),
            _WalletSection(
              method: PaymentMethod.cash,
              balance: cashBalance,
              currency: currency,
              transactions: _getTransactionsForMethod(
                transactions,
                PaymentMethod.cash,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            _WalletSection(
              method: PaymentMethod.ewallet,
              balance: ewalletBalance,
              currency: currency,
              transactions: _getTransactionsForMethod(
                transactions,
                PaymentMethod.ewallet,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            _WalletSection(
              method: PaymentMethod.bank,
              balance: bankBalance,
              currency: currency,
              transactions: _getTransactionsForMethod(
                transactions,
                PaymentMethod.bank,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferDialog() async {
    final amountController = TextEditingController();
    final feeController = TextEditingController(text: '0');
    PaymentMethod? fromMethod;
    PaymentMethod? toMethod;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amount = double.tryParse(amountController.text) ?? 0;
            final fee = double.tryParse(feeController.text) ?? 0;
            final total = amount + fee;
            final isFormValid =
                fromMethod != null &&
                toMethod != null &&
                fromMethod != toMethod &&
                amount > 0;

            final sourceBalance = fromMethod != null
                ? _getWalletBalance(ref, fromMethod!)
                : 0.0;

            return AlertDialog(
              title: const Text(AppStrings.transferMoney),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: fromMethod,
                      decoration: const InputDecoration(
                        labelText: AppStrings.from,
                        prefixIcon: Icon(Icons.arrow_upward),
                      ),
                      items: PaymentMethod.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: IntrinsicWidth(
                            child: Row(
                              children: [
                                Icon(getPaymentMethodIcon(m), size: 20),
                                const SizedBox(width: 8),
                                Text(getPaymentMethodLabel(m)),
                                const SizedBox(width: 16),
                                Text(
                                  formatCurrency(
                                    _getWalletBalance(ref, m),
                                    ref.watch(currencyProvider),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => fromMethod = v),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: toMethod,
                      decoration: const InputDecoration(
                        labelText: AppStrings.to,
                        prefixIcon: Icon(Icons.arrow_downward),
                      ),
                      items: PaymentMethod.values
                          .where((m) => m != fromMethod)
                          .map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Row(
                                children: [
                                  Icon(getPaymentMethodIcon(m), size: 20),
                                  const SizedBox(width: 8),
                                  Text(getPaymentMethodLabel(m)),
                                ],
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (v) => setDialogState(() => toMethod = v),
                    ),
                    const SizedBox(height: AppSizes.md),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: AppStrings.amount,
                        prefixText: '${ref.watch(currencyProvider).symbol} ',
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    TextFormField(
                      controller: feeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: AppStrings.transferFee,
                        prefixText: '${ref.watch(currencyProvider).symbol} ',
                        helperText: AppStrings.transferFeeHelper,
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    if (isFormValid) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadiusSm,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryRow(
                              label: AppStrings.amount,
                              value: formatCurrency(
                                amount,
                                ref.watch(currencyProvider),
                              ),
                            ),
                            if (fee > 0)
                              _SummaryRow(
                                label: 'Fee',
                                value: formatCurrency(
                                  fee,
                                  ref.watch(currencyProvider),
                                ),
                              ),
                            const Divider(height: AppSizes.md),
                            _SummaryRow(
                              label:
                                  'Total from ${getPaymentMethodLabel(fromMethod!)}',
                              value: formatCurrency(
                                total,
                                ref.watch(currencyProvider),
                              ),
                              bold: true,
                            ),
                            const SizedBox(height: AppSizes.xs),
                            if (total > sourceBalance)
                              Text(
                                '${AppStrings.insufficientBalance} in ${getPaymentMethodLabel(fromMethod!)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.error),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: (isFormValid && total <= sourceBalance)
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text(AppStrings.transfer),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;
    if (fromMethod == null || toMethod == null) return;

    final source = fromMethod!;
    final destination = toMethod!;
    final amount = double.tryParse(amountController.text) ?? 0;
    final fee = double.tryParse(feeController.text) ?? 0;
    final userId = ref.read(currentUserProvider)?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isTransferring = true);

    try {
      final notifier = ref.read(transactionsProvider.notifier);
      final now = DateTime.now();
      final createdIds = <String>[];

      try {
        await notifier.savePendingTransferIds([]);

        final debitId = await notifier.addTransaction(
          amount: amount,
          categoryId: transferCategoryId,
          userId: userId,
          description: 'Transfer to ${getPaymentMethodLabel(destination)}',
          date: now,
          type: TransactionType.expense,
          paymentMethod: source,
          isTransfer: true,
        );
        createdIds.add(debitId);
        await notifier.savePendingTransferIds(createdIds);

        final creditId = await notifier.addTransaction(
          amount: amount,
          categoryId: transferCategoryId,
          userId: userId,
          description: 'Transfer from ${getPaymentMethodLabel(source)}',
          date: now,
          type: TransactionType.income,
          paymentMethod: destination,
          isTransfer: true,
        );
        createdIds.add(creditId);
        await notifier.savePendingTransferIds(createdIds);

        if (fee > 0) {
          final feeId = await notifier.addTransaction(
            amount: fee,
            categoryId: transferFeeCategoryId,
            userId: userId,
            description:
                'Transfer fee (${getPaymentMethodLabel(source)} → ${getPaymentMethodLabel(destination)})',
            date: now,
            type: TransactionType.expense,
            paymentMethod: source,
            isTransfer: false,
          );
          createdIds.add(feeId);
          await notifier.savePendingTransferIds(createdIds);
        }

        await notifier.clearPendingTransferIds();
      } catch (_) {
        for (final id in createdIds) {
          try {
            await notifier.removeTransaction(id);
          } catch (_) {}
        }
        try {
          await notifier.clearPendingTransferIds();
        } catch (_) {}
        if (mounted) {
          setState(() => _isTransferring = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.transferFailedRolledBack),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _isTransferring = false);
        final feeText = fee > 0
            ? ' (fee: ${formatCurrency(fee, ref.read(currencyProvider))})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transferred ${formatCurrency(amount, ref.read(currencyProvider))}$feeText',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double _getWalletBalance(WidgetRef ref, PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => ref.watch(allTimeCashBalanceProvider),
      PaymentMethod.ewallet => ref.watch(allTimeEwalletBalanceProvider),
      PaymentMethod.bank => ref.watch(allTimeBankBalanceProvider),
    };
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalBalance;
  final double cashBalance;
  final double ewalletBalance;
  final double bankBalance;
  final Currency currency;

  const _SummaryCard({
    required this.totalBalance,
    required this.cashBalance,
    required this.ewalletBalance,
    required this.bankBalance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
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
              formatCurrency(totalBalance, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: totalBalance < 0 ? AppColors.error : null,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                _Chip(
                  icon: Icons.payments_outlined,
                  label: getPaymentMethodLabel(PaymentMethod.cash),
                  amount: cashBalance,
                  currency: currency,
                ),
                const SizedBox(width: AppSizes.sm),
                _Chip(
                  icon: Icons.phone_android_outlined,
                  label: getPaymentMethodLabel(PaymentMethod.ewallet),
                  amount: ewalletBalance,
                  currency: currency,
                ),
                const SizedBox(width: AppSizes.sm),
                _Chip(
                  icon: Icons.account_balance_outlined,
                  label: getPaymentMethodLabel(PaymentMethod.bank),
                  amount: bankBalance,
                  currency: currency,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Currency currency;

  const _Chip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: AppSizes.iconSizeSm,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSizes.xs),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(
              formatCurrency(amount, currency),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSection extends StatelessWidget {
  final PaymentMethod method;
  final double balance;
  final Currency currency;
  final List<Transaction> transactions;

  const _WalletSection({
    required this.method,
    required this.balance,
    required this.currency,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (method) {
      PaymentMethod.cash => AppColors.success,
      PaymentMethod.ewallet => AppColors.primary,
      PaymentMethod.bank => AppColors.income,
    };
    final recent = transactions.take(5).toList();

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getPaymentMethodIcon(method),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  getPaymentMethodLabel(method),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  formatCurrency(balance, currency),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: balance < 0 ? AppColors.expense : null,
                  ),
                ),
              ],
            ),
          ),
          if (recent.isNotEmpty) ...[
            const Divider(height: 1),
            ...recent.map(
              (t) => _TransactionTile(transaction: t, currency: currency),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Currency currency;

  const _TransactionTile({required this.transaction, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';
    final dateStr = DateFormat('MMM d').format(transaction.date);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: InkWell(
        onTap: () => context.push('/edit/${transaction.id}'),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ??
                        (transaction.isTransfer ? 'Transfer' : 'Transaction'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign${formatCurrency(transaction.amount, currency)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
