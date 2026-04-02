import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/currency_service.dart';
import '../../auth/data/auth_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user?.imageProvider,
              child: user?.imageProvider == null
                  ? Text(
                      user?.name?.isNotEmpty ?? false
                          ? user!.name![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            title: Text(user?.name ?? 'Unknown User'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text('${currency.symbol} ${currency.code}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context, ref, currency),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Upgrade to Pro'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    Currency current,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Currency',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency = availableCurrencies[index];
                      final isSelected = currency.code == current.code;

                      return ListTile(
                        leading: Text(
                          currency.symbol,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        title: Text(currency.name),
                        subtitle: Text(currency.code),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          ref
                              .read(currencyProvider.notifier)
                              .setCurrency(currency);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
