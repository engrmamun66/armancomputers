import 'package:flutter/material.dart';

class AppSnackbar {
  static void success(BuildContext context, String message) => _show(context, message, isError: false);

  static void error(BuildContext context, String message) => _show(context, message, isError: true);

  static void _show(BuildContext context, String message, {required bool isError}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.error : null,
        ),
      );
  }
}
