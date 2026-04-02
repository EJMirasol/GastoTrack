import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/transaction.dart';
import '../data/transaction_repository.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../auth/data/auth_repository.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? groupId;

  const AddTransactionPage({this.groupId, super.key});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _groupId != null
              ? 'Add Group Expense'
              : _type == TransactionType.expense
              ? 'Add Expense'
              : 'Add Income',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
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
            _buildDescriptionField(),
            const SizedBox(height: AppSizes.md),
            _buildDateSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('Expense'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('Income'),
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
        labelText: 'Amount',
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
          return 'Please enter an amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown(List categories) {
    final filteredCategories = _type == TransactionType.income
        ? categories
              .where((c) => c.name == 'Salary' || c.name == 'Other')
              .toList()
        : categories.where((c) => c.name != 'Salary').toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(labelText: 'Category'),
      items: filteredCategories.map<DropdownMenuItem<String>>((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _parseColor(category.color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getIconData(category.icon),
                  size: 16,
                  color: _parseColor(category.color),
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
          return 'Please select a category';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        alignLabelWithHint: true,
      ),
      maxLines: 2,
    );
  }

  Widget _buildDateSelector() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: const Text('Date'),
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
      final userId = currentUser?.id ?? 'demo-user';

      final success = await ref
          .read(transactionsProvider.notifier)
          .addTransaction(
            amount: amount,
            categoryId: _selectedCategoryId!,
            userId: userId,
            groupId: _groupId,
            description: _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
            date: _selectedDate,
            type: _type,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (_type == TransactionType.expense
                        ? 'Expense added successfully'
                        : 'Income added successfully')
                  : 'Saved offline — will sync when connected',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    }
  }

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
}
