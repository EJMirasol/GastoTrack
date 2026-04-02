import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/constants.dart';
import '../../auth/data/auth_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditing = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.error != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(onPressed: _cancelEditing, child: const Text('Cancel')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user?.imageProvider != null
                        ? user!.imageProvider
                        : null,
                    child: user?.imageProvider == null
                        ? Text(
                            user?.name?.isNotEmpty ?? false
                                ? user!.name![0].toUpperCase()
                                : (user?.email[0].toUpperCase() ?? '?'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: _isUploadingImage
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    enabled: _isEditing,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: _isEditing,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),
                  if (_isEditing)
                    FilledButton(
                      onPressed: authState.isLoading ? null : _saveProfile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.sm,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  const SizedBox(height: AppSizes.xl),
                  const Divider(),
                  const SizedBox(height: AppSizes.md),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out'),
                    textColor: Colors.red,
                    onTap: () => _showSignOutDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelEditing() {
    final user = ref.read(currentUserProvider);
    setState(() {
      _isEditing = false;
      _nameController.text = user?.name ?? '';
      _emailController.text = user?.email ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
        );

    if (success && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploadingImage = true);

      final base64Image = 'data:image/jpeg;base64,${base64Encode(file.bytes!)}';

      final success = await ref
          .read(authProvider.notifier)
          .updateProfile(image: base64Image);

      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    _currentPasswordController.clear();
    _newPasswordController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final authState = ref.watch(authProvider);

            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureCurrentPassword,
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureNewPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a new password';
                      }
                      if (value.length < 8) {
                        return 'Must be at least 8 characters';
                      }
                      final hasSpecial = RegExp(
                        r'[^a-zA-Z0-9]',
                      ).hasMatch(value);
                      if (!hasSpecial) {
                        return 'Must include 1 special character';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: authState.isLoading
                      ? null
                      : () => _submitPasswordChange(dialogContext),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitPasswordChange(BuildContext dialogContext) async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      Navigator.pop(dialogContext);
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;
    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Password updated' : 'Failed to update password',
        ),
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(authProvider.notifier).signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
