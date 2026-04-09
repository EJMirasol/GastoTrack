import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../data/auth_repository.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && context.mounted) {
        context.go('/');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: AppSizes.logoSize,
                height: AppSizes.logoSize,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusXl),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: AppSizes.iconSizeLg,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                AppStrings.appName,
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              FilledButton.icon(
                onPressed: () => ref.read(authProvider.notifier).getStarted(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(AppStrings.getStarted),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
