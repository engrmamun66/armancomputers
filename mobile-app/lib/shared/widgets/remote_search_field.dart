import 'dart:async';

import 'package:flutter/material.dart';

/// Async debounced remote-search picker (mirrors ProductSearch.vue /
/// CustomerSearch.vue). Results render inline, below the field, in normal
/// document flow — never as a horizontally-scrolling row.
class RemoteSearchField<T> extends StatefulWidget {
  final String hint;
  final Future<List<T>> Function(String query) search;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final ValueChanged<T> onSelected;
  final Widget? trailing; // e.g. "+ Add new" affordance shown under results
  // Result still shows (dimmed) but can't be tapped — e.g. an inactive product
  // in a Sale's search, which mustn't be sellable even though it's findable.
  final bool Function(T item)? isDisabled;

  const RemoteSearchField({
    super.key,
    required this.hint,
    required this.search,
    required this.itemBuilder,
    required this.onSelected,
    this.trailing,
    this.isDisabled,
  });

  @override
  State<RemoteSearchField<T>> createState() => _RemoteSearchFieldState<T>();
}

class _RemoteSearchFieldState<T> extends State<RemoteSearchField<T>> {
  final _controller = TextEditingController();
  Timer? _timer;
  List<T> _results = [];
  bool _loading = false;
  bool _open = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _open = false;
      });
      return;
    }
    _timer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      final results = await widget.search(value);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _open = true;
      });
    });
  }

  void _select(T item) {
    widget.onSelected(item);
    _controller.clear();
    setState(() {
      _results = [];
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(hintText: widget.hint, prefixIcon: const Icon(Icons.search, size: 20)),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No results found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final disabled = widget.isDisabled?.call(item) ?? false;
                      return InkWell(
                        onTap: disabled ? null : () => _select(item),
                        child: Opacity(
                          opacity: disabled ? 0.5 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: widget.itemBuilder(context, item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
