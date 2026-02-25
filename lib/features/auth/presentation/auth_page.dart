import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../data/auth_repository.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _isSignUp = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated) {
        context.go('/');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSizes.xxl),
                _buildHeader(),
                const SizedBox(height: AppSizes.xxl),
                if (_isSignUp) _buildNameField(),
                SizedBox(height: _isSignUp ? AppSizes.md : 0),
                _buildEmailField(),
                const SizedBox(height: AppSizes.md),
                _buildPasswordField(),
                const SizedBox(height: AppSizes.lg),
                _buildSubmitButton(authState.isLoading),
                const SizedBox(height: AppSizes.md),
                _buildToggleLink(),
                const SizedBox(height: AppSizes.lg),
                _buildDemoButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          'GastoTrack',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          _isSignUp ? 'Create your account' : 'Sign in to continue',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name',
        prefixIcon: Icon(Icons.person_outline),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (_isSignUp && (value == null || value.isEmpty)) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      obscureText: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return FilledButton(
      onPressed: isLoading ? null : _submit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
      ),
    );
  }

  Widget _buildToggleLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : "Don't have an account?",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _isSignUp = !_isSignUp;
            });
          },
          child: Text(_isSignUp ? 'Sign In' : 'Sign Up'),
        ),
      ],
    );
  }

  Widget _buildDemoButton() {
    return OutlinedButton(
      onPressed: _signInAsDemo,
      child: const Text('Continue as Demo User'),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authProvider.notifier);

    if (_isSignUp) {
      await authNotifier.signUp(
        email: _emailController.text,
        name: _nameController.text,
        password: _passwordController.text,
      );
    } else {
      await authNotifier.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  void _signInAsDemo() async {
    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.signUp(
      email: 'demo@gastotrack.app',
      name: 'Demo User',
      password: 'Demo@123',
    );
  }
}
