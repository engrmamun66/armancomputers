import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/profile_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/status_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Edit profile
  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _profileSaving = false;
  String? _nameError;
  String? _emailError;
  bool _prefilled = false;

  // Change password
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _passwordSaving = false;
  String? _currentPasswordError;

  // Avatar
  bool _avatarUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _pickAvatar() async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not open the gallery.');
      return;
    }
    if (file == null) return;

    setState(() => _avatarUploading = true);
    try {
      final updated = await ref.read(profileServiceProvider).updateAvatar(file.path);
      ref.read(authProvider.notifier).updateUser(updated);
      if (mounted) AppSnackbar.success(context, 'Profile photo updated.');
    } catch (e) {
      final apiEx = ApiClient.toApiException(e);
      if (mounted) AppSnackbar.error(context, apiEx.message);
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() {
      _profileSaving = true;
      _nameError = null;
      _emailError = null;
    });
    try {
      final updated = await ref.read(profileServiceProvider).update(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
          );
      ref.read(authProvider.notifier).updateUser(updated);
      if (mounted) AppSnackbar.success(context, 'Profile updated successfully.');
    } catch (e) {
      final apiEx = ApiClient.toApiException(e);
      setState(() {
        _nameError = apiEx.firstErrorFor('name');
        _emailError = apiEx.firstErrorFor('email');
      });
      if (mounted) AppSnackbar.error(context, apiEx.message);
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _passwordSaving = true;
      _currentPasswordError = null;
    });
    try {
      await ref.read(profileServiceProvider).updatePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _passwordFormKey.currentState?.reset();
      if (mounted) AppSnackbar.success(context, 'Password changed successfully.');
    } catch (e) {
      final apiEx = ApiClient.toApiException(e);
      setState(() => _currentPasswordError = apiEx.firstErrorFor('current_password'));
      if (mounted) AppSnackbar.error(context, apiEx.message);
    } finally {
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: AppLoading());
    }

    if (!_prefilled) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _prefilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(child: _buildOverview(context, user)),
            const SizedBox(height: 16),
            SectionCard(title: 'Edit Profile', child: _buildEditProfileForm(context)),
            const SizedBox(height: 16),
            SectionCard(title: 'Change Password', child: _buildPasswordForm(context)),
            const SizedBox(height: 16),
            SectionCard(title: 'Appearance', child: _buildThemeToggle(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, UserModel user) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 44.0;
    final url = user.avatarUrl;

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: radius,
                backgroundColor: scheme.primaryContainer,
                child: ClipOval(
                  child: url == null
                      ? SizedBox(
                          width: radius * 2,
                          height: radius * 2,
                          child: Center(
                            child: Text(
                              _initials(user.name),
                              style: TextStyle(
                                fontSize: radius * 0.55,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          width: radius * 2,
                          height: radius * 2,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => const Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, _, error) => SizedBox(
                            width: radius * 2,
                            height: radius * 2,
                            child: Icon(Icons.person, size: radius, color: scheme.onPrimaryContainer),
                          ),
                        ),
                ),
              ),
              if (_avatarUploading)
                Positioned.fill(
                  child: ClipOval(
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _avatarUploading ? null : _pickAvatar,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.camera_alt, size: 16, color: scheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (user.role != null)
              Chip(
                avatar: const Icon(Icons.badge_outlined, size: 18),
                label: Text(user.role!.name),
              ),
            if (user.status != null) StatusBadge(status: user.status!.name),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        _infoRow(context, Icons.calendar_today_outlined, 'Member since', formatDate(user.createdAt)),
        const SizedBox(height: 10),
        _infoRow(
          context,
          Icons.login_outlined,
          'Last login',
          user.lastLoginAt == null ? 'Never' : formatDateTime(user.lastLoginAt),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: scheme.onSurfaceVariant)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileForm(BuildContext context) {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: const Icon(Icons.person_outline),
              errorText: _nameError,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              errorText: _emailError,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _profileSaving ? null : _saveProfile,
              child: _profileSaving ? const ButtonSpinner() : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm(BuildContext context) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: 'Current Password',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _currentPasswordError,
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
            onChanged: (_) {
              if (_currentPasswordError != null) setState(() => _currentPasswordError = null);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'New password is required';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_person_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your new password';
              if (v != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _passwordSaving ? null : _savePassword,
              child: _passwordSaving ? const ButtonSpinner() : const Text('Update Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget segment(ThemeMode value, IconData icon, String label) {
      final selected = mode == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            onPressed: () => ref.read(themeModeProvider.notifier).setMode(value),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? scheme.primaryContainer : null,
              foregroundColor: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: selected ? Colors.transparent : scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        segment(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
        segment(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
        segment(ThemeMode.system, Icons.settings_suggest_outlined, 'System'),
      ],
    );
  }
}
