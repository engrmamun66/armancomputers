/// Mirrors resources/js/utils/permissions.js exactly. UI-only gating —
/// backend Policies are the real authority; this just drives which controls
/// the app bothers to show. Do not treat this as a security boundary.
const Map<String, List<String>> kCapabilities = {
  'admin': [
    'users',
    'products.manage',
    'brands.manage',
    'customers.manage',
    'stock-in.manage',
    'stock-out.manage',
    'invoices.view',
    'dashboard',
  ],
  'manager': [
    'products.manage',
    'brands.manage',
    'customers.manage',
    'stock-in.manage',
    'stock-out.manage',
    'invoices.view',
    'dashboard',
  ],
  'staff': ['products.view', 'customers.view', 'stock-out.manage', 'invoices.view', 'dashboard'],
};

bool can(String roleSlug, String capability) => (kCapabilities[roleSlug] ?? const []).contains(capability);
