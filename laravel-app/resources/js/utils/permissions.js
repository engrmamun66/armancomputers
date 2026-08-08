// Central role → capability map. Backend policies are authoritative; this only
// drives which controls the UI bothers to show.
const CAPABILITIES = {
    admin: ['users', 'products.manage', 'brands.manage', 'customers.manage', 'stock-in.manage', 'stock-out.manage', 'invoices.view', 'dashboard'],
    manager: ['products.manage', 'brands.manage', 'customers.manage', 'stock-in.manage', 'stock-out.manage', 'invoices.view', 'dashboard'],
    staff: ['products.view', 'customers.view', 'stock-out.manage', 'invoices.view', 'dashboard'],
};

export function can(roleSlug, capability) {
    return CAPABILITIES[roleSlug]?.includes(capability) ?? false;
}
