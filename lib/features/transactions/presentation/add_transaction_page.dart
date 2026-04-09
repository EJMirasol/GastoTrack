import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/transaction.dart';
import '../data/transaction_repository.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../../shared/utils/category_utils.dart';
import '../../../shared/utils/payment_utils.dart';
import '../../auth/data/auth_repository.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddTransactionPage({this.transactionId, super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  late String? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isEdit = false;
  Transaction? _existingTransaction;

  @override
  void initState() {
    super.initState();
    _type = TransactionType.expense;
    _paymentMethod = PaymentMethod.cash;
    _selectedCategoryId = null;
    _selectedDate = DateTime.now();

    if (widget.transactionId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final transactions = ref.read(transactionsProvider);
        final existing = transactions
            .where((t) => t.id == widget.transactionId)
            .firstOrNull;
        if (existing != null && mounted) {
          setState(() {
            _existingTransaction = existing;
            _type = existing.type;
            _paymentMethod = existing.paymentMethod;
            _selectedCategoryId = existing.categoryId;
            _selectedDate = existing.date;
            _amountController.text = existing.amount.toStringAsFixed(2);
            _descriptionController.text = existing.description ?? '';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isTransfer =>
      _existingTransaction != null && _existingTransaction!.isTransfer;

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existingTransaction == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isTransfer) {
      return _buildTransferDetailView(context);
    }

    final categories = ref.watch(categoriesProvider);
    final title = _isEdit
        ? (_type == TransactionType.expense
              ? AppStrings.editExpense
              : AppStrings.editIncome)
        : (_type == TransactionType.expense
              ? AppStrings.addExpense
              : AppStrings.addIncome);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isEdit ? _update : _save,
            child: Text(_isEdit ? AppStrings.update : AppStrings.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            _buildTypeSelector(),
            const SizedBox(height: AppSizes.lg),
            _buildAmountField(),
            const SizedBox(height: AppSizes.md),
            _buildCategoryDropdown(categories),
            const SizedBox(height: AppSizes.md),
            _buildPaymentMethodSelector(),
            const SizedBox(height: AppSizes.md),
            _buildDescriptionField(),
            const SizedBox(height: AppSizes.md),
            _buildDateSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferDetailView(BuildContext context) {
    final t = _existingTransaction!;
    final currency = ref.watch(currencyProvider);
    final isIncome = t.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.transferDetails),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppStrings.delete,
            onPressed: () => _showDeleteDialog(context, ref, t.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
            ),
            child: Column(
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${formatCurrency(t.amount, currency)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusSm,
                    ),
                  ),
                  child: Text(
                    isIncome ? AppStrings.moneyReceived : AppStrings.moneySent,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _DetailRow(
            icon: Icons.description_outlined,
            label: AppStrings.description,
            value: t.description ?? AppStrings.transfer,
          ),
          const Divider(height: AppSizes.lg),
          _DetailRow(
            icon: getPaymentMethodIcon(t.paymentMethod),
            label: AppStrings.wallet,
            value: getPaymentMethodLabel(t.paymentMethod),
          ),
          const Divider(height: AppSizes.lg),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: AppStrings.date,
            value: DateFormat('EEEE, MMMM d, y').format(t.date),
          ),
          const Divider(height: AppSizes.lg),
          _DetailRow(
            icon: Icons.swap_horiz,
            label: AppStrings.type,
            value: AppStrings.transfer,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteTransfer),
        content: const Text(AppStrings.deleteTransferConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(transactionsProvider.notifier)
                  .removeTransaction(id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) context.pop();
            },
            child: Text(
              AppStrings.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text(AppStrings.expense),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text(AppStrings.income),
          icon: Icon(Icons.arrow_downward),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (types) {
        setState(() {
          _type = types.first;
          _selectedCategoryId = null;
        });
      },
    );
  }

  Widget _buildAmountField() {
    final currency = ref.watch(currencyProvider);
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: AppStrings.amount,
        prefixText: '${currency.symbol} ',
        suffixIcon: IconButton(
          icon: const Icon(Icons.calculate_outlined),
          onPressed: () {},
        ),
      ),
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppStrings.validationAmountRequired;
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return AppStrings.validationAmountInvalid;
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown(List categories) {
    final filteredCategories = _type == TransactionType.income
        ? categories
              .where(
                (c) => c.categoryType == 'income' || c.categoryType == 'both',
              )
              .toList()
        : categories
              .where(
                (c) => c.categoryType == 'expense' || c.categoryType == 'both',
              )
              .toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(labelText: AppStrings.category),
      items: filteredCategories.map<DropdownMenuItem<String>>((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: parseCategoryColor(
                    category.color,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  getCategoryIconData(category.icon),
                  size: 16,
                  color: parseCategoryColor(category.color),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(category.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return AppStrings.validationCategoryRequired;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: AppStrings.descriptionOptional,
        alignLabelWithHint: true,
      ),
      maxLines: 2,
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.paymentMethodLabel),
        const SizedBox(height: AppSizes.xs),
        SegmentedButton<PaymentMethod>(
          segments: [
            ButtonSegment(
              value: PaymentMethod.cash,
              label: Text(getPaymentMethodLabel(PaymentMethod.cash)),
              icon: const Icon(Icons.payments_outlined, size: 18),
            ),
            ButtonSegment(
              value: PaymentMethod.ewallet,
              label: Text(getPaymentMethodLabel(PaymentMethod.ewallet)),
              icon: const Icon(Icons.phone_android_outlined, size: 18),
            ),
            ButtonSegment(
              value: PaymentMethod.bank,
              label: Text(getPaymentMethodLabel(PaymentMethod.bank)),
              icon: const Icon(Icons.account_balance_outlined, size: 18),
            ),
          ],
          selected: {_paymentMethod},
          onSelectionChanged: (methods) {
            setState(() {
              _paymentMethod = methods.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: const Text(AppStrings.date),
      subtitle: Text(DateFormat('EEEE, MMMM d, y').format(_selectedDate)),
      trailing: const Icon(Icons.chevron_right),
      onTap: _pickDate,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);

      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;
      final userId = currentUser.id;

      await ref
          .read(transactionsProvider.notifier)
          .addTransaction(
            amount: amount,
            categoryId: _selectedCategoryId!,
            userId: userId,
            description: _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
            date: _selectedDate,
            type: _type,
            paymentMethod: _paymentMethod,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == TransactionType.expense
                  ? AppStrings.expenseAdded
                  : AppStrings.incomeAdded,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingTransaction == null) return;

    final amount = double.parse(_amountController.text);
    final updated = _existingTransaction!.copyWith(
      amount: amount,
      categoryId: _selectedCategoryId ?? _existingTransaction!.categoryId,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      date: _selectedDate,
      type: _type,
      paymentMethod: _paymentMethod,
    );

    await ref.read(transactionsProvider.notifier).updateTransaction(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.transactionUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSizes.xxs),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
