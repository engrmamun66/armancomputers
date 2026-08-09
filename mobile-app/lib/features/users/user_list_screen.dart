import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../models/lookup.dart';
import '../../models/paginated.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/lookups_service.dart';
import '../../services/users_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/pagination_controls.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/searchable_select.dart';
import '../../shared/widgets/status_badge.dart';

/// Sentinel used for the "All Roles" / "All Statuses" filter options.
/// SearchableSelect._open() only forwards a selection when it is non-null
/// (it can't otherwise tell "user picked nothing" apart from "user picked
/// the null option"), so real ids (which start at 1) are paired with 0
/// meaning "no filter" instead of using null as the sentinel.
const int _kAllFilterValue = 0;

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  String _search = '';
  int? _roleId;
  int? _statusId;
  int _page = 1;
  int _searchFieldSalt = 0;

  bool _loading = true;
  String? _error;
  List<UserModel> _users = [];
  PageMeta? _meta;

  bool _lookupsLoading = true;
  List<RoleModel> _roles = [];
  List<StatusModel> _statuses = [];

  @override
  void initState() {
    super.initState();
    final role = ref.read(authProvider).roleSlug;
    if (can(role, 'users')) {
      _loadLookups();
      _loadUsers();
    }
  }

  Future<void> _loadLookups() async {
    setState(() => _lookupsLoading = true);
    try {
      final roles = await ref.read(lookupsServiceProvider).roles();
      final statuses = await ref.read(lookupsServiceProvider).statuses('general');
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _statuses = statuses;
        _lookupsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookupsLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{'page': _page};
      if (_search.trim().isNotEmpty) params['search'] = _search.trim();
      if (_roleId != null) params['role_id'] = _roleId;
      if (_statusId != null) params['status_id'] = _statusId;

      final result = await ref.read(usersServiceProvider).list(params);
      if (!mounted) return;
      setState(() {
        _users = result.data;
        _meta = result.meta;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Something went wrong. Please try again.';
      setState(() {
        _error = message;
        _loading = false;
      });
      AppSnackbar.error(context, message);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadUsers(),
      if (_roles.isEmpty || _statuses.isEmpty) _loadLookups(),
    ]);
  }

  bool get _hasActiveFilters => _search.isNotEmpty || _roleId != null || _statusId != null;

  void _resetFilters() {
    setState(() {
      _search = '';
      _roleId = null;
      _statusId = null;
      _page = 1;
      _searchFieldSalt++;
    });
    _loadUsers();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _loadUsers();
  }

  Future<void> _openUserForm({UserModel? user}) async {
    if (_lookupsLoading || _roles.isEmpty || _statuses.isEmpty) {
      AppSnackbar.error(context, 'Role and status options are not ready yet. Please try again in a moment.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UserFormSheet(user: user, roles: _roles, statuses: _statuses),
    );
    if (saved == true && mounted) {
      AppSnackbar.success(context, user == null ? 'User created successfully.' : 'User updated successfully.');
      if (user == null) _page = 1;
      _loadUsers();
    }
  }

  Future<void> _openResetPassword(UserModel user) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResetPasswordDialog(user: user),
    );
    if (done == true && mounted) {
      AppSnackbar.success(context, 'Password reset successfully.');
    }
  }

  Future<void> _toggleStatus(UserModel user) async {
    final isActive = user.status?.slug == 'active';
    final targetSlug = isActive ? 'inactive' : 'active';
    final matches = _statuses.where((s) => s.slug == targetSlug);
    if (matches.isEmpty) {
      AppSnackbar.error(context, 'Could not find the "$targetSlug" status.');
      return;
    }
    final targetId = matches.first.id;

    final confirmed = await showAppConfirmDialog(
      context,
      title: isActive ? 'Deactivate user?' : 'Activate user?',
      message: isActive
          ? '"${user.name}" will no longer be able to sign in.'
          : '"${user.name}" will be able to sign in again.',
      confirmText: isActive ? 'Deactivate' : 'Activate',
      danger: isActive,
    );
    if (!confirmed) return;

    try {
      await ref.read(usersServiceProvider).update(user.id, {
        'name': user.name,
        'email': user.email,
        'role_id': user.role?.id,
        'status_id': targetId,
      });
      if (!mounted) return;
      AppSnackbar.success(context, isActive ? 'User deactivated.' : 'User activated.');
      _loadUsers();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete user?',
      message: 'This will permanently delete "${user.name}". This action cannot be undone.',
      confirmText: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(usersServiceProvider).remove(user.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'User deleted successfully.');
      if (_users.length == 1 && _page > 1) _page -= 1;
      _loadUsers();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final role = auth.roleSlug;

    if (!can(role, 'users')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: const AppEmptyState(
          title: 'Access restricted',
          message: "You don't have permission to view this page.",
          icon: Icons.lock_outline,
        ),
      );
    }

    final currentUserId = auth.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            tooltip: 'Add user',
            icon: const Icon(Icons.add),
            onPressed: () => _openUserForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(child: _buildContent(currentUserId)),
          if (_meta != null) PaginationControls(meta: _meta!, onPageChange: _changePage),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final roleOptions = <SelectOption<int>>[
      const SelectOption(_kAllFilterValue, 'All Roles'),
      ..._roles.map((r) => SelectOption(r.id, r.name)),
    ];
    final statusOptions = <SelectOption<int>>[
      const SelectOption(_kAllFilterValue, 'All Statuses'),
      ..._statuses.map((s) => SelectOption(s.id, s.name)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            key: ValueKey(_searchFieldSalt),
            initialValue: _search,
            hint: 'Search by name or email',
            onChanged: (value) {
              setState(() {
                _search = value;
                _page = 1;
              });
              _loadUsers();
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 340;
              final itemWidth = twoColumn ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: SearchableSelect<int>(
                      label: 'Role',
                      value: _roleId ?? _kAllFilterValue,
                      options: roleOptions,
                      onChanged: (value) {
                        setState(() {
                          _roleId = value == _kAllFilterValue ? null : value;
                          _page = 1;
                        });
                        _loadUsers();
                      },
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: SearchableSelect<int>(
                      label: 'Status',
                      value: _statusId ?? _kAllFilterValue,
                      options: statusOptions,
                      onChanged: (value) {
                        setState(() {
                          _statusId = value == _kAllFilterValue ? null : value;
                          _page = 1;
                        });
                        _loadUsers();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Reset filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(int? currentUserId) {
    if (_loading) {
      return const AppLoading();
    }

    if (_error != null && _users.isEmpty) {
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return AppEmptyState(
        title: 'No users found',
        message: _hasActiveFilters
            ? 'Try adjusting your search or filters.'
            : 'Get started by adding your first user.',
        icon: Icons.people_outline,
        clearLabel: _hasActiveFilters ? 'Reset filters' : null,
        onClear: _hasActiveFilters ? _resetFilters : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = _users[index];
          final isSelf = currentUserId != null && user.id == currentUserId;
          return _UserCard(
            user: user,
            isSelf: isSelf,
            onEdit: () => _openUserForm(user: user),
            onResetPassword: () => _openResetPassword(user),
            onToggleStatus: isSelf ? null : () => _toggleStatus(user),
            onDelete: isSelf ? null : () => _deleteUser(user),
          );
        },
      ),
    );
  }
}

enum _UserAction { edit, resetPassword, toggleStatus, delete }

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onDelete;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.onEdit,
    required this.onResetPassword,
    this.onToggleStatus,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isActive = user.status?.slug == 'active';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(color: muted, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_UserAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _UserAction.edit:
                        onEdit();
                        break;
                      case _UserAction.resetPassword:
                        onResetPassword();
                        break;
                      case _UserAction.toggleStatus:
                        onToggleStatus?.call();
                        break;
                      case _UserAction.delete:
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: _UserAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _UserAction.resetPassword,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.key_outlined),
                        title: Text('Reset password'),
                      ),
                    ),
                    if (onToggleStatus != null)
                      PopupMenuItem(
                        value: _UserAction.toggleStatus,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline),
                          title: Text(isActive ? 'Deactivate' : 'Activate'),
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _UserAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(user.role?.name ?? '—'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                StatusBadge(status: user.status?.slug ?? 'inactive'),
              ],
            ),
            const SizedBox(height: 12),
            _MetaLine(
              icon: Icons.login,
              label: 'Last login',
              value: user.lastLoginAt == null ? 'Never' : formatDateTime(user.lastLoginAt),
            ),
            const SizedBox(height: 4),
            _MetaLine(icon: Icons.event_outlined, label: 'Created', value: formatDateTime(user.createdAt)),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label: ', style: TextStyle(color: muted, fontSize: 12)),
                TextSpan(text: value, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _ResetPasswordDialog({required this.user});

  @override
  ConsumerState<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(usersServiceProvider).resetPassword(widget.user.id, _controller.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset password for ${widget.user.name}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const ButtonSpinner() : const Text('Reset'),
        ),
      ],
    );
  }
}

class _UserFormSheet extends ConsumerStatefulWidget {
  final UserModel? user;
  final List<RoleModel> roles;
  final List<StatusModel> statuses;

  const _UserFormSheet({this.user, required this.roles, required this.statuses});

  @override
  ConsumerState<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  int? _roleId;
  int? _statusId;
  String? _roleError;
  String? _statusError;
  String? _emailServerError;
  bool _obscurePassword = true;
  bool _submitting = false;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _roleId = widget.user?.role?.id;
    _statusId = widget.user?.status?.id ?? _defaultStatusId();
  }

  int? _defaultStatusId() {
    if (widget.statuses.isEmpty) return null;
    final active = widget.statuses.where((s) => s.slug == 'active');
    return active.isNotEmpty ? active.first.id : widget.statuses.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _roleError = _roleId == null ? 'Role is required' : null;
      _statusError = _statusId == null ? 'Status is required' : null;
    });
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _roleId == null || _statusId == null) return;

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role_id': _roleId,
        'status_id': _statusId,
      };
      if (!_isEdit) {
        payload['password'] = _passwordController.text;
      }

      if (_isEdit) {
        await ref.read(usersServiceProvider).update(widget.user!.id, payload);
      } else {
        await ref.read(usersServiceProvider).create(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _emailServerError = e.firstErrorFor('email');
        _submitting = false;
      });
      _formKey.currentState?.validate();
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleOptions = widget.roles.map((r) => SelectOption<int>(r.id, r.name)).toList();
    final statusOptions = widget.statuses.map((s) => SelectOption<int>(s.id, s.name)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? 'Edit User' : 'Add User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  onChanged: (_) {
                    if (_emailServerError != null) setState(() => _emailServerError = null);
                  },
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Email is required';
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
                    if (_emailServerError != null) return _emailServerError;
                    return null;
                  },
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password is required';
                      if (value.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                SearchableSelect<int>(
                  label: 'Role',
                  value: _roleId,
                  options: roleOptions,
                  placeholder: 'Select a role',
                  errorText: _roleError,
                  onChanged: (value) => setState(() {
                    _roleId = value;
                    _roleError = null;
                  }),
                ),
                const SizedBox(height: 16),
                SearchableSelect<int>(
                  label: 'Status',
                  value: _statusId,
                  options: statusOptions,
                  placeholder: 'Select a status',
                  errorText: _statusError,
                  onChanged: (value) => setState(() {
                    _statusId = value;
                    _statusError = null;
                  }),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _submitting ? const ButtonSpinner() : Text(_isEdit ? 'Save Changes' : 'Create User'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
