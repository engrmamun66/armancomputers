export function formatCurrency(value) {
    const amount = Number(value ?? 0);
    return '৳' + amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function formatDate(value) {
    if (!value) return '—';
    const date = new Date(value);
    return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function formatDateTime(value) {
    if (!value) return '—';
    const date = new Date(value);
    return date.toLocaleString('en-GB', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

/**
 * Warranty length as a friendly duration (e.g. "20 Days", "3 Months", "1 Year"),
 * computed as warrantyEndDate - startDate (purchase_date / sale_date). Returns
 * null when there's no warranty end date set, so callers can render their own
 * empty-state ("—").
 */
export function formatWarranty(startDate, warrantyEndDate) {
    if (!warrantyEndDate) return null;
    const start = new Date(startDate);
    const end = new Date(warrantyEndDate);
    const diffDays = Math.round((end - start) / (1000 * 60 * 60 * 24));
    if (diffDays <= 0) return 'Expired';
    if (diffDays < 30) return `${diffDays} Day${diffDays === 1 ? '' : 's'}`;
    if (diffDays < 365) {
        const months = Math.round(diffDays / 30);
        return `${months} Month${months === 1 ? '' : 's'}`;
    }
    const years = Math.round(diffDays / 365);
    return `${years} Year${years === 1 ? '' : 's'}`;
}
