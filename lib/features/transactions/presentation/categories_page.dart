import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/category.dart';
import '../data/transaction_repository.dart';
import '../../../core/constants/constants.dart';
import '../../../shared/utils/category_utils.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categories)),
      body: categories.isEmpty
          ? const Center(child: Text(AppStrings.noCategories))
          : ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(categoriesProvider.notifier)
                    .reorderCategories(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              children: [
                for (final category in categories)
                  _CategoryListTile(
                    key: ValueKey(category.id),
                    category: category,
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/categories/add'),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addCategory),
      ),
    );
  }
}

class _CategoryListTile extends ConsumerWidget {
  final Category category;

  const _CategoryListTile({required this.category, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = parseCategoryColor(category.color);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        ),
        child: Icon(
          getCategoryIconData(category.icon),
          color: color,
          size: AppSizes.iconSize,
        ),
      ),
      title: Text(category.name),
      subtitle: Text(
        _typeLabel(category.categoryType),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!category.isDefault)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: AppSizes.iconSize),
              onPressed: () =>
                  context.push('/settings/categories/edit/${category.id}'),
            ),
          if (!category.isDefault)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: AppSizes.iconSize,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _showDeleteDialog(context, ref, category),
            ),
          if (category.isDefault)
            IconButton(
              icon: const Icon(
                Icons.drive_file_rename_outline,
                size: AppSizes.iconSize,
              ),
              onPressed: () => _showRenameDialog(context, ref, category),
            ),
          Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.outline),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteCategory),
        content: Text(
          AppStrings.deleteCategoryConfirm.replaceAll('{name}', category.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(categoriesProvider.notifier)
                  .deleteCategory(category.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
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

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.renameCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: AppStrings.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final updated = category.copyWith(name: name);
                await ref
                    .read(categoriesProvider.notifier)
                    .updateCategory(updated);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(AppStrings.rename),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'expense' => 'Expense',
      'income' => 'Income',
      'both' => 'Expense & Income',
      _ => type,
    };
  }
}
