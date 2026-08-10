import 'package:flutter/material.dart';

class SelectOption<T> {
  final T value;
  final String label;
  const SelectOption(this.value, this.label);
}

/// Select2-equivalent for small, fixed, already-in-memory option lists
/// (Status, Role, payment method, Brand-in-product-form). For large/dynamic
/// collections (Product, Customer) use RemoteSearchField instead.
class SearchableSelect<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final bool allowCreate;
  final Future<SelectOption<T>?> Function(String query)? onCreate;
  final String? errorText;
  final bool required;

  const SearchableSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Select…',
    this.allowCreate = false,
    this.onCreate,
    this.errorText,
    this.required = false,
  });

  String? get _selectedLabel {
    final match = options.where((o) => o.value == value);
    return match.isEmpty ? null : match.first.label;
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SelectSheet<T>(
        title: label,
        options: options,
        allowCreate: allowCreate,
        onCreate: onCreate,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge,
            children: required ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : null,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(context),
          child: InputDecorator(
            decoration: InputDecoration(errorText: errorText),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedLabel ?? placeholder,
                    style: TextStyle(color: _selectedLabel == null ? scheme.onSurfaceVariant : null),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.unfold_more, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectSheet<T> extends StatefulWidget {
  final String title;
  final List<SelectOption<T>> options;
  final bool allowCreate;
  final Future<SelectOption<T>?> Function(String query)? onCreate;

  const _SelectSheet({required this.title, required this.options, required this.allowCreate, this.onCreate});

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String _query = '';
  bool _creating = false;

  List<SelectOption<T>> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
  }

  bool get _exactMatch =>
      widget.options.any((o) => o.label.toLowerCase() == _query.trim().toLowerCase());

  Future<void> _create() async {
    if (widget.onCreate == null || _query.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final option = await widget.onCreate!(_query.trim());
      if (option != null && mounted) Navigator.of(context).pop(option.value);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCreate = widget.allowCreate && _query.trim().isNotEmpty && !_exactMatch;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search…', prefixIcon: Icon(Icons.search, size: 20)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._filtered.map(
                    (o) => ListTile(
                      title: Text(o.label),
                      onTap: () => Navigator.of(context).pop(o.value),
                    ),
                  ),
                  if (_filtered.isEmpty && !showCreate)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No results found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  if (showCreate)
                    ListTile(
                      leading: _creating
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add),
                      title: Text('Add "${_query.trim()}"'),
                      onTap: _creating ? null : _create,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
