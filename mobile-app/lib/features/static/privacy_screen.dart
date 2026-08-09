import 'package:flutter/material.dart';

import '../../core/company.dart';
import '../../shared/widgets/section_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <MapEntry<String, String>>[
    MapEntry(
      'Information We Collect',
      'We collect information you provide directly to us, such as your name, email address, and phone number '
          'when you create an account or are added as a user, customer, or supplier record. We also collect '
          'operational data generated through your use of the system, including product, stock, and transaction '
          'records.',
    ),
    MapEntry(
      'How We Use Information',
      'Information is used to operate and maintain the stock management system, process stock in/out '
          'transactions and invoices, manage user accounts and permissions, and provide customer support. We do '
          'not sell or rent personal information to third parties.',
    ),
    MapEntry(
      'Data Security',
      'We apply reasonable administrative and technical safeguards to protect data stored in this system, '
          'including password hashing, authenticated API access, and role-based access controls. No method of '
          'electronic storage is 100% secure, and we cannot guarantee absolute security.',
    ),
    MapEntry(
      'Cookies',
      'This application may use local browser storage to keep you signed in and remember basic preferences. We '
          'do not use cookies for third-party advertising or cross-site tracking.',
    ),
    MapEntry(
      'Third-Party Services',
      'This application does not share your data with third-party services except where required to operate '
          'core functionality (e.g., hosting infrastructure). Any such providers are expected to maintain '
          'appropriate confidentiality and security standards.',
    ),
    MapEntry(
      'User Rights',
      'You may request access to, correction of, or deletion of your personal information held within this '
          'system, subject to legitimate business and record-keeping requirements (such as retaining historical '
          'transaction records). Contact your system administrator to make such a request.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your privacy matters to us. This policy explains what information we collect and how it '
                      'is used within the ${Company.name} system.',
                      style: textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _sections.length; i++) ...[
              SectionCard(
                title: '${i + 1}. ${_sections[i].key}',
                child: Text(
                  _sections[i].value,
                  style: textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
              if (i != _sections.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
