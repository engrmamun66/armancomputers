import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? clearLabel;
  final VoidCallback? onClear;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.clearLabel,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(message!, style: TextStyle(color: muted), textAlign: TextAlign.center),
            ],
            if (onClear != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onClear, child: Text(clearLabel ?? 'Clear filters')),
            ],
          ],
        ),
      ),
    );
  }
}
