import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/constants.dart';
import '../domain/category.dart';
import '../data/transaction_repository.dart';
import '../../../shared/utils/category_utils.dart';

const _presetIcons = categoryIconNames;

const _presetColors = categoryPresetColors;

class CategoryFormPage extends ConsumerStatefulWidget {
  final String? categoryId;

  const CategoryFormPage({this.categoryId, super.key});

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _selectedIcon;
  late String _selectedColor;
  late String _selectedType;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _selectedIcon = _presetIcons[0];
    _selectedColor = _presetColors[0];
    _selectedType = 'expense';

    if (widget.categoryId != null) {
      _isEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categories = ref.read(categoriesProvider);
        final existing = categories
            .where((c) => c.id == widget.categoryId)
            .firstOrNull;
        if (existing != null && mounted) {
          setState(() {
            _nameController.text = existing.name;
            _selectedIcon = existing.icon;
            _selectedColor = existing.color;
            _selectedType = existing.categoryType;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? AppStrings.editCategory : AppStrings.addCategory;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(_isEdit ? AppStrings.update : 'Add'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.name,
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.validationNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(AppStrings.type),
            const SizedBox(height: AppSizes.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text(AppStrings.expenseType),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text(AppStrings.incomeType),
                ),
                ButtonSegment(value: 'both', label: Text(AppStrings.bothType)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (types) {
                setState(() => _selectedType = types.first);
              },
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(AppStrings.icon),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: _presetIcons.map((icon) {
                final isSelected = icon == _selectedIcon;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  child: Container(
                    width: AppSizes.iconSizeMd * 2,
                    height: AppSizes.iconSizeMd * 2,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadius,
                      ),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                    ),
                    child: Icon(
                      getCategoryIconData(icon),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(AppStrings.color),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: _presetColors.map((color) {
                final isSelected = color == _selectedColor;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusXl),
                  child: Container(
                    width: AppSizes.iconSizeMd * 2,
                    height: AppSizes.iconSizeMd * 2,
                    decoration: BoxDecoration(
                      color: parseCategoryColor(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: parseCategoryColor(
                            color,
                          ).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSizes.xxl),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(categoriesProvider.notifier);
    final categories = ref.read(categoriesProvider);
    final maxOrder = categories.isEmpty
        ? 0
        : categories.map((c) => c.order).reduce((a, b) => a > b ? a : b);

    if (_isEdit) {
      final existing = categories
          .where((c) => c.id == widget.categoryId)
          .firstOrNull;
      if (existing == null) return;

      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        categoryType: _selectedType,
      );
      await notifier.updateCategory(updated);
    } else {
      final category = Category(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
        isDefault: false,
        order: maxOrder + 1,
        categoryType: _selectedType,
      );
      await notifier.addCategory(category);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? AppStrings.categoryUpdated : AppStrings.categoryAdded,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }
}
