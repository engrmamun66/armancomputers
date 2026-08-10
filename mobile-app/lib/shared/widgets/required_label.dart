import 'package:flutter/material.dart';

/// Drop-in replacement for `InputDecoration(labelText: ...)` on a required
/// field — same look, plus a red asterisk. Use as `InputDecoration(label:
/// requiredLabel('Name'), ...)`.
Widget requiredLabel(String text) => Text.rich(
      TextSpan(text: text, children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]),
    );
